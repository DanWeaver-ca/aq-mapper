# AQ Mapper — Lab-Day Support Context

**Instructions to Claude:** You are supporting Dan Weaver (UTSC professor,
atmospheric physics) live during a high-school air-quality lab. He has NO
access to the project repo or his development machine — everything you need
to know is in this document; treat it as ground truth. Be concise and
stepwise: one fix at a time, most-likely first. For any phone problem,
FIRST establish which surface the student is on — **Safari tab / iOS
home-screen app / Android Chrome / inside WeChat** — because permissions
and storage are separate per surface. Match the user's reported error text
against the verbatim strings below to identify the code path. Respect the
"never suggest" list at the end.

## 1. Situation

- Up to 25 groups of visiting high-school students (many from China —
  WeChat common, some have no email or Google accounts), personal phones,
  mixed iOS + Android. Each group carries a Temtop M2000+ handheld sensor
  (measures PM2.5, PM10, particles, CO2, HCHO, temperature, humidity; has
  no GPS — the phone app supplies coordinates).
- Students walk UTSC campus (centre 43.7841, -79.1873), measure indoor +
  outdoor locations, type readings into the web app, and submit.
- Dan has: his iPhone, the lab's Windows laptop (dashboard tools
  installed), the project Google account (in a browser), and his GitHub
  login (works from any browser).
- App version 2.0.0; repo state tagged `v3.0-lab3`. Everything below was
  rehearsed on 2026-08-07 **except sending from inside real WeChat** —
  that is untested; today is its first field test.

## 2. URLs

| What | URL |
|---|---|
| Student app (QR target) | https://danweaver-ca.github.io/aq-mapper/ |
| Upload endpoint health check | https://script.google.com/macros/s/AKfycbwg2giVl54vNWl3S4nFItsDrJueX4y4DzaZ3PA8HKxX6cnJh3DFhhN8_1sZnFg8FWQbxg/exec |
| Repo (public) | https://github.com/DanWeaver-ca/aq-mapper |

Opening the health-check URL in ANY browser (no sign-in needed) returns
`{"ok":true,"service":"aq-mapper-upload","rows":N}` — N = rows the class
sheet holds. If a signed-in browser shows a Drive error page instead,
that's Google session routing noise, NOT an outage: retest in a private/
incognito window before concluding anything.

## 3. How data flows

1. Student enters a reading (value ± variability per sensor variable,
   indoor/outdoor, notes); the app auto-captures GPS. Data persists on the
   phone (offline-first; only map tiles need internet).
2. **Primary — "Send to class":** POSTs ALL the phone's readings to the
   endpoint → Google Sheet, tab `readings`. Re-sending is always safe:
   unchanged rows are skipped, an **edited reading overwrites its old row**
   (same row, refreshed RECEIVED_AT). No email/Google account needed;
   works inside WeChat (it's a plain web request).
3. **Backup — "Send to instructor":** share sheet → email/AirDrop a CSV
   file (`aq_<device>_<datetime>.csv`) to dan.weaver@utoronto.ca.
4. **Debrief:** on the sheet: File → Download → .csv → drop into the
   laptop's `classroom_map\csvs\` folder alongside any emailed CSVs →
   double-click `run_windows.bat` → projected dashboard. Duplicates
   auto-resolve by UID (emailed copy beats uploaded copy where both exist).

## 4. The app's screens (labels are verbatim)

- **Session setup** (forced on first launch): group name (convention
  "Group 1".."Group 25"), device ID dropdown UTSC-AQMS-01…25 + "Other…",
  °C/°F. Editable later via the session chip on the home screen.
- **Add measurement**: mean ± variability fields; PARTICLES has no ±
  field. Validation: impossible values are blocked ("hard"), unusual ones
  warn with a "save anyway?" dialog ("soft"). GPS captures automatically;
  a refresh icon re-captures.
- **History**: tap a reading to edit it (keeps its identity — edits
  propagate on next send); swipe to delete.
- **Map**: colour-coded by selected variable, legend, heatmap toggle,
  group filter; imported rows get dark marker borders.
- **Data** (top to bottom): **"Send to class"** (primary, shows
  "Uploading..." while busy) → **"Send to instructor"** ("Opening share
  sheet...") with the instructor email + "Copy" button beneath → web-only
  **"Save CSV to my phone"** ("Saving...") → import/merge CSVs → "Clear
  Imported" → "Delete All". A data-safety reminder banner shows whenever
  local readings exist.

## 5. Verbatim messages → what they mean

**Upload path** (Send to class):
- `Class map received N readings (M new). Re-send any time — duplicates
  are filtered.` — success. After an edit-and-resend it says `(already
  all there)` — that is CORRECT: it counts new rows only; the correction
  did land (check the sheet cell).
- `The upload timed out — check your connection and try again.` /
  `Could not reach the class endpoint — check your connection.` —
  connectivity. See triage #3 (wifi/roaming-SIM).
- `Server error (HTTP N).` / `Unexpected reply from the endpoint.` /
  `Upload rejected…` — endpoint-side; check the health URL; fall back to
  Send to instructor. Data is never lost — it stays on the phone.
- All failures append: `Your data is still on this phone — try again, or
  use "Send to instructor".` (true statement — reassure the student).

**Share/save path:** `Share sheet completed.` · `Share cancelled — your
data was not sent.` (student dismissed the share sheet — retry) ·
`CSV saved — check your Downloads or Files app.`

**Location:** `Location permissions are permanently denied. Please enable
them in Settings.` (permission denied at browser level — triage #1) ·
`GPS location not available. Please wait or retry.` (no fix yet — wait,
step outdoors/near a window, tap refresh; saving is blocked until a fix
arrives, by design).

**Import:** `Imported N …` · `N file(s) skipped` (usually a raw Temtop
device file — has no GPS columns; only app exports import).

**WeChat overlay** (full-screen, bilingual, appears inside WeChat/QQ):
"Please open this page in your browser / 请在浏览器中打开本页面" with steps
"1. Tap the ⋯ menu (top-right corner) 2. Choose 'Open in Browser'", note
"If you stay in WeChat, use the app's 'Send to class' button — it works
here. Saving files does not.", dismiss link "Continue in WeChat anyway /
仍在微信中继续".

## 6. Triage ladders (most common first)

**#1 "Location permissions are permanently denied"**
- iPhone, Safari or home-screen app: Settings → Privacy & Security →
  Location Services (ON) → **Safari Websites → While Using the App +
  Precise Location ON** (this exact case hit Dan's own phone in
  rehearsal — the toggle was off). Then per-site if needed: in Safari on
  the app page, tap **ᴀA** in the address bar → Website Settings →
  Location → Ask. Reload / fully close and reopen the home-screen app.
- Inside WeChat: the webview only gets location if WeChat itself has it:
  Settings → WeChat → Location → While Using the App.
- Android Chrome: phone Location ON; site permission: tap the padlock/
  tune icon by the address bar → Permissions → Location → Allow; also
  Settings → Location → App permissions → Chrome → "Use precise location".

**#2 Points appear far off campus (~km-scale)** — coarse cell-tower fix
(seen in 2026-06 testing, ~1.4 km off). Enable Precise Location (ladders
above), re-capture GPS on the entry screen, re-save. Off points can also
be filtered at the debrief by group.

**#3 "Send to class" can't reach the server** — most likely the student is
on a **roaming Chinese SIM**: roaming data tunnels through the home
carrier, where Google is blocked, even in Toronto. Fix: join campus wifi,
retry. If wifi is unavailable → "Send to instructor" (email/AirDrop works
regardless of Google). If EVERYONE fails: open the health URL yourself
(private window) — no JSON = endpoint problem → announce email backup for
all; the lab proceeds unharmed.

**#4 Student stayed inside WeChat** — expected for some. Send to class
works there (untested claim — today confirms it). Share/save do NOT work
there. CRITICAL: WeChat's browser has a **separate storage sandbox** —
readings entered inside WeChat are invisible if they later open the app
in Safari (and vice versa). They are not lost — reopen in the SAME
surface they were entered in, then Send to class from there.

**#5 "already all there" after an edit** — not a bug; see §5. Verify in
the sheet if the student is worried.

**#6 Junk/prank rows in the sheet** — the URL is public-but-unguessable;
anyone with it can append. Junk is visible (odd GROUP names) — right-click
→ delete those rows in the sheet. Harmless otherwise; sheet gets deleted
after the debrief anyway.

**#7 Home Base: a group missing from the checklist (grey chip)** — their
data hasn't arrived (chase them: sheet row count per group, or ask) OR
name mismatch: matching is case-insensitive but spelling-sensitive
("Group 07" ≠ "Group 7") — check the green chips for the name they
actually typed; `--roster`/`--expect 25` set expectations.

**#8 Home Base: "file skipped" warning in the header** — that file is a
raw Temtop download (no GPS) or unreadable; ask the group to re-send from
the app's Data screen. One bad file never kills the build.

**#9 Phantom groups / stale data in the dashboard** — old files in
`csvs\`. Only CSVs directly in `csvs\` are read (subfolders ignored) —
move strays into `csvs\archive\`.

**#10 Dashboard map background is blank grey** — laptop offline. Points,
stats, checklist all still work; connect wifi and reload for the basemap.

**#11 Windows: "python is not recognized" / Microsoft Store opens** — use
the double-click `run_windows.bat` (finds Anaconda itself), or full path:
`C:\ProgramData\anaconda3\python.exe home_base.py csvs`.

**#12 Plotly errors on `Scattermap`** — old library:
`pip install -U "plotly>=5.24,<7"` (in Anaconda Prompt).

**#13 Home Base tool itself misbehaving** — fallback beside it:
`home_base_v2.py`, run identically (the exact tool that ran lab 2; only
difference: no duplicate-precedence logic, keeps first copy seen).

**#14 iPhone user "lost" their readings** — Safari-tab storage and
home-screen-app storage are separate sandboxes (like WeChat's, #4). Have
them open the app the same way they entered data. iOS can also evict web
storage under pressure — hence the standing rule: **send before you
leave**. If truly evicted, data on the class sheet from their earlier
sends survives.

**#15 Empty sheet at debrief but students sent** — check the health URL
rows count; make sure you're looking at the `readings` tab of the right
spreadsheet in the PROJECT Google account (not a personal account).

## 7. Instructor remote controls (any browser, no dev machine)

- **Watch arrivals:** open the sheet; rows append live; `RECEIVED_AT` =
  last arrival time per row.
- **Row count without the sheet:** the health URL.
- **Disable the upload button entirely:** github.com → repo →
  `deploy.config.json` → pencil icon → set `"UPLOAD_URL": ""` → commit to
  main → site rebuilds in ~3 min (watch the Actions tab). Restore by
  putting the URL back. This is the pre-agreed rollback to lab-2
  behaviour.
- **Kill the endpoint instantly:** sheet → Extensions → Apps Script →
  Deploy → Manage deployments → Archive. (Re-deploying later via "New
  deployment" issues a NEW URL that must go into deploy.config.json.)
- **Update endpoint code** (unlikely on lab day): edit in Apps Script,
  then Deploy → Manage deployments → ✏️ → **New version** → Deploy. A
  plain save does NOT change the live behaviour; "New version" keeps the
  same URL.

## 8. Reference data

**Sheet/CSV columns (order matters, never rename):** DATE, PM2.5(ug/m3),
PM10(ug/m3), PARTICLES(per/L), CO2(ppm), HCHO(mg/m3), TEMPERATURE,
HUMIDITY(%), TEMPUNIT, LATITUDE, LONGITUDE, GROUP, DEVICE, LOCATION_TYPE,
PM2.5_VAR(ug/m3), PM10_VAR(ug/m3), CO2_VAR(ppm), HCHO_VAR(mg/m3),
TEMPERATURE_VAR, HUMIDITY_VAR(%), UID, NOTES — sheet adds RECEIVED_AT.

**Colour bands (app + dashboard agree):**

| Variable | Green up to | Orange | Deep orange | Red above |
|---|---|---|---|---|
| PM2.5 (µg/m³) | 12 | 12–35 | 35–55 | 55 |
| PM10 (µg/m³) | 25 | 25–50 | 50–100 | 100 |
| CO₂ (ppm) | 800 | 800–1000 | 1000–1500 | 1500 |
| HCHO (mg/m³) | 0.04 | 0.04–0.08 | 0.08–0.1 | 0.1 |

(Temp and RH use blue/green/orange/red comfort bands: 15/24/30 °C and
30/60/80 %.) Plausibility: UTSC outdoor PM2.5 is usually green (<12);
indoor CO₂ 600–1500+ ppm is normal and IS the debrief story (indoor vs
outdoor); HCHO usually <0.03. A CO₂ of 420 ppm outdoors is healthy
baseline air, not an error.

**Sanity facts:** dashboard is one self-contained HTML (~5 MB) — email it
to students afterwards; only its basemap tiles need internet. The app map
works offline on campus (tiles bundled). Group checklist chips: green =
data in (with point count), grey = missing.

## 9. Never suggest

1. **Deleting/re-adding the home-screen app or clearing website data** to
   fix permissions — it wipes the phone's stored readings.
2. **"Delete All"** on the Data screen as a troubleshooting step.
3. Changing the upload's `text/plain` content type, the CSV column names,
   or sheet column order — they are load-bearing contracts.
4. "New deployment" in Apps Script when "New version" is meant (URL churn).
5. Editing app code or pushing anything beyond the documented
   `UPLOAD_URL` rollback — the code is frozen for the lab.
6. Clearing sheet rows mid-lab (it's the live class dataset). After the
   debrief: download the CSV, then delete rows/sheet — transit, not
   storage.

## 10. End-of-day runbook

1. Last call: every group taps Send to class once more (or emails).
2. Sheet → File → Download → .csv → `classroom_map\csvs\` (any filename).
3. Add any emailed CSVs to the same folder.
4. Double-click `run_windows.bat` → project the dashboard (F11).
5. Afterwards: email `classroom_dashboard.html` to the class if desired;
   delete the sheet's rows (or the spreadsheet) and clear `csvs\` per the
   privacy practice. Phones keep their own copies regardless.
