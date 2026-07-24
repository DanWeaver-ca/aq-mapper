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
 * - Idempotent: rows whose UID is already in the sheet are skipped, so the
 *   app can safely re-send everything every time. Home Base dedups by UID
 *   as well, so even a race that slips a duplicate through is harmless.
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
    var existing = existingUids(sheet);
    var receivedAt = new Date().toISOString();
    var fresh = [];
    for (var j = 0; j < rows.length; j++) {
      var uid = String(rows[j][UID_COL]);
      if (uid && !existing[uid]) {
        existing[uid] = true;
        // Force every cell to plain text so Sheets can't reinterpret dates
        // or strip trailing zeros — the CSV download must round-trip.
        fresh.push(rows[j].map(String).concat([receivedAt]));
      }
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

function existingUids(sheet) {
  var seen = {};
  var last = sheet.getLastRow();
  if (last > 1) {
    var uids = sheet.getRange(2, UID_COL + 1, last - 1, 1).getValues();
    for (var i = 0; i < uids.length; i++) {
      seen[String(uids[i][0])] = true;
    }
  }
  return seen;
}

function jsonOut(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
      .setMimeType(ContentService.MimeType.JSON);
}
