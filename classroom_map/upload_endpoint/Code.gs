/**
 * AQ Mapper — "Send to class" upload receiver (Google Apps Script).
 *
 * Students' phones POST their readings here; rows land in a Google Sheet
 * whose columns are byte-identical to the app's CSV export, so
 * File → Download → CSV drops straight into Home Base's csvs/ folder.
 *
 * Setup: see SETUP_UPLOAD.md in this folder (≈5 minutes, free).
 *
 * Design notes:
 * - The app sends Content-Type: text/plain so the browser skips the CORS
 *   preflight (Apps Script web apps can't answer OPTIONS). The JSON body
 *   arrives unchanged in e.postData.contents.
 * - Idempotent, last write wins: a re-sent row whose values are unchanged
 *   is skipped; one whose UID exists but whose values differ overwrites the
 *   old copy in place. The app keeps a reading's UID when it is edited, so
 *   this is how corrections propagate to the class sheet. Home Base dedups
 *   by UID as well, so even a race that slips a duplicate through is
 *   harmless.
 * - LockService serialises concurrent uploads (25 groups tapping at once).
 */

var SHEET_NAME = 'readings';

// Byte-identical to the app's CSV export (Measurement.csvHeaders) — the
// app ↔ hub ↔ Temtop file-format contract. Do not rename.
var HEADERS = [
  'DATE', 'PM2.5(ug/m3)', 'PM10(ug/m3)', 'PARTICLES(per/L)', 'CO2(ppm)',
  'HCHO(mg/m3)', 'TEMPERATURE', 'HUMIDITY(%)', 'TEMPUNIT', 'LATITUDE',
  'LONGITUDE', 'GROUP', 'DEVICE', 'LOCATION_TYPE', 'PM2.5_VAR(ug/m3)',
  'PM10_VAR(ug/m3)', 'CO2_VAR(ppm)', 'HCHO_VAR(mg/m3)', 'TEMPERATURE_VAR',
  'HUMIDITY_VAR(%)', 'UID', 'NOTES',
];
var UID_COL = HEADERS.indexOf('UID');           // 0-based, for dedup
var RECEIVED_AT_COL = HEADERS.length;           // extra column we append

function doPost(e) {
  var lock = LockService.getScriptLock();
  lock.waitLock(30 * 1000);
  try {
    var body = JSON.parse(e.postData.contents);
    var rows = body.rows;
    if (!Array.isArray(rows)) {
      return jsonOut({ ok: false, error: 'no rows array' });
    }
    for (var i = 0; i < rows.length; i++) {
      if (!Array.isArray(rows[i]) || rows[i].length !== HEADERS.length) {
        return jsonOut({ ok: false, error: 'row ' + i + ' malformed' });
      }
    }

    var sheet = getSheet();
    var existing = existingRows(sheet);
    var receivedAt = new Date().toISOString();
    var fresh = [];    // UIDs the sheet has never seen — appended in a batch
    var updates = [];  // edited readings re-sent — overwritten in place
    for (var j = 0; j < rows.length; j++) {
      // Force every cell to plain text so Sheets can't reinterpret dates
      // or strip trailing zeros — the CSV download must round-trip.
      var values = rows[j].map(String);
      var uid = values[UID_COL];
      if (!uid) continue;
      var seen = existing[uid];
      if (!seen) {
        fresh.push(values.concat([receivedAt]));
        existing[uid] = { row: 0, values: values };  // 0 = new this request
      } else if (seen.row > 0 && !sameValues(seen.values, values)) {
        // Same UID, different values: the student edited a reading and
        // re-sent. Last write wins, so the correction reaches the sheet
        // (RECEIVED_AT then means "last received"). Unchanged rows fall
        // through untouched, keeping re-sends cheap under the lock.
        updates.push({ row: seen.row, values: values.concat([receivedAt]) });
        seen.values = values;
      }
    }
    for (var u = 0; u < updates.length; u++) {
      var target = sheet.getRange(updates[u].row, 1, 1, HEADERS.length + 1);
      target.setNumberFormat('@');
      target.setValues([updates[u].values]);
    }
    if (fresh.length > 0) {
      var start = sheet.getLastRow() + 1;
      var range = sheet.getRange(start, 1, fresh.length, HEADERS.length + 1);
      range.setNumberFormat('@');
      range.setValues(fresh);
    }
    return jsonOut({
      ok: true,
      received: rows.length,
      added: fresh.length,
      updated: updates.length,
      total: sheet.getLastRow() - 1,
      group: body.group || null,
    });
  } catch (err) {
    return jsonOut({ ok: false, error: String(err) });
  } finally {
    lock.releaseLock();
  }
}

/** Health check — open the /exec URL in a browser to verify the deploy. */
function doGet() {
  var sheet = getSheet();
  return jsonOut({
    ok: true,
    service: 'aq-mapper-upload',
    rows: Math.max(0, sheet.getLastRow() - 1),
  });
}

function getSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
  }
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(HEADERS.concat(['RECEIVED_AT']));
    sheet.setFrozenRows(1);
  }
  return sheet;
}

/**
 * Map of UID -> { row: 1-based sheet row, values: [HEADERS.length strings] }
 * for every data row, read in one call. doPost diffs incoming rows against
 * it so a re-send of unchanged data writes nothing at all.
 */
function existingRows(sheet) {
  var seen = {};
  var last = sheet.getLastRow();
  if (last > 1) {
    var values = sheet.getRange(2, 1, last - 1, HEADERS.length).getValues();
    for (var i = 0; i < values.length; i++) {
      var uid = String(values[i][UID_COL]);
      if (uid) {
        seen[uid] = { row: i + 2, values: values[i].map(String) };
      }
    }
  }
  return seen;
}

function sameValues(a, b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

function jsonOut(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
      .setMimeType(ContentService.MimeType.JSON);
}
