# AQ Mapper - Air Quality Mobile Mapping App

## Project Overview
A Flutter mobile app (iOS + Android) for UTSC air quality lab activities. Up to 25 visiting-student groups carry Temtop M2000+ sensors (device IDs UTSC-AQMS-01…25) around campus and enter readings into the app, which auto-captures GPS coordinates. Data is visualized on a color-coded map (any variable, with legend and heatmap), exported as CSV, and merged across groups by importing each other's CSVs — fully offline, no server.

## Tech Stack
- **Framework**: Flutter (Dart)
- **Maps**: OpenStreetMap via `flutter_map` + `latlong2` (no API key needed)
- **Heatmap**: `flutter_map_heatmap` (pins `flutter_map` to 7.x; isolated behind `widgets/heatmap_layer.dart` so it can be swapped for a self-rendered fallback)
- **GPS**: `geolocator` package
- **Storage**: SQLite via `sqflite` (schema v2, migration in `database_service.dart`)
- **Session settings**: `shared_preferences` (group name, device ID, temp unit)
- **Export/Import**: CSV via `csv` + `share_plus` + `file_picker`
- **State**: Simple StatefulWidgets (no Provider/Bloc needed at current scale)
- **Tests**: `flutter_test` + `sqflite_common_ffi` (in-memory DB for migration/dedup tests)

## Project Structure
```
AQ_mobile_app/                         # repo root — two products + supporting material:
  aq_mapping_app/                      # (1) the Flutter app — ONE codebase, builds iOS + Android + web
  classroom_map/                       # (2) Python/Plotly debrief tool (instructor's laptop)
  student_handout/                     # student QR code + printable handout
  lab_documents/   docs/               # lab sheets / Temtop reference ; project briefs
  deploy.config.json                   # ONE-FILE institution config (names, campus, email,
                                       #   device IDs) — consumed by app build + python tools
  deploy.config.demo.json              # generic demo deployment → served at /demo/
  SETUP.md                             # adopter walkthrough: fork → edit config → Pages

aq_mapping_app/                        # —— the Flutter app, in detail ——
  lib/
    main.dart                          # App entry point, Material 3 theme
    app_config.dart                    # Branding + campus defaults. Since v1.2 every value is
                                       #   overridable via /deploy.config.json (dart-defines;
                                       #   UTSC defaults baked in for plain `flutter run`)
    models/
      measurement.dart                 # Data model: sensor values + ± variability, particles,
                                       #   tempUnit, group/device, indoor/outdoor, source, uid;
                                       #   CSV row serialization (toCsvRow / fromCsvRow)
      field_specs.dart                 # Validation bounds (hard = block, soft = warn) per field
      map_variable.dart                # Map color thresholds + legend bands per variable
    screens/
      home_screen.dart                 # Navigation hub (4 buttons) + session chip
      session_setup_screen.dart        # Group name + device ID + °C/°F (forced on first launch)
      entry_screen.dart                # Reading form (value ± variability, indoor/outdoor) + GPS;
                                       #   also edit mode via EntryScreen(existing: m)
      history_screen.dart              # List of measurements; tap = edit, swipe = delete
      map_screen.dart                  # OSM map: variable chips, legend, heatmap toggle
      data_screen.dart                 # Send to instructor / save CSV, import/merge,
                                       #   clear imported, delete all
    services/
      database_service.dart            # SQLite CRUD, v1→v2 migration, insertIfNew dedup
      session_service.dart             # shared_preferences wrapper for session settings
      location_service.dart            # GPS wrapper with permission handling
      csv_export_service.dart          # CSV build + send/save via the platform seam
                                       #   (csv_export_platform_{io,web}.dart; SendOutcome)
      csv_import_service.dart          # CSV parsing/validation + merge (source='imported')
      upload_service.dart              # v3 "Send to class": POST all rows to UPLOAD_URL
                                       #   (text/plain JSON, no preflight; UID-dedup makes
                                       #   re-sending safe; hidden when URL empty)
      poi_service.dart                 # v3 campus POIs: fetch/parse /campus_pois.geojson
                                       #   (points+boundary), prefs-cached for offline
    widgets/
      heatmap_layer.dart               # flutter_map_heatmap wrapper (only file touching it)
  test/                                # 48 tests: model, CSV round-trip, migration (ffi),
                                       #   dedup, thresholds, bounds, widget validation,
                                       #   data-screen send/save button states
```

## Key Design Decisions
- **OpenStreetMap** over Google Maps: no API key, no Google services dependency (important for visiting Chinese students)
- **Offline-first**: SQLite + GPS work without internet; only map tiles need connectivity
- **Class aggregation via CSV import/merge** (no server): groups AirDrop CSVs to the instructor, who imports them on one device for a combined map. Dedup by per-row `uid` (unique index); imported rows tagged `source='imported'`, shown with dark marker borders, clearable separately
- **CSV format**: Temtop M2000+ native column names first (DATE, PM2.5(ug/m3), …, TEMPUNIT) for cross-comparison with the device's own export, then app columns (LATITUDE, LONGITUDE, GROUP, DEVICE, LOCATION_TYPE, *_VAR columns, UID, NOTES). Import parses by header name, rejects raw Temtop files (no coordinates)
- **Mean ± variability** fields per the lab observation sheet ("425 ± 15 ppm"); particles has no ± field
- **Validation**: hard bounds block (impossible/out-of-sensor-range), soft bounds warn with a "save anyway?" dialog
- **DB schema v2**: any future schema change needs version bump + onUpgrade migration + ffi migration test (field devices carry real student data)
- **Location-agnostic**: works anywhere, not just UTSC. Empty map centers on the device's own location (last-known fix, then live GPS); the UTSC coordinate in `app_config.dart` is only the last-resort default. Branding text lives in `app_config.dart`; the device-ID dropdown has an "Other…" free-text option for non-UTSC sensors

## Build & Run
```bash
# Flutter must be on PATH
export XDG_CONFIG_HOME=$HOME/Projects/.config  # workaround for ~/.config ownership issue

flutter pub get
flutter analyze
flutter test             # 41 tests, all green expected
flutter run              # run on connected device/simulator
flutter build ios        # iOS build
flutter build apk        # Android build
```

## Platform Config
- **iOS**: Location permissions in `ios/Runner/Info.plist` (NSLocationWhenInUseUsageDescription)
- **Android**: Location + internet permissions in `android/app/src/main/AndroidManifest.xml`
- **Android release signing**: still debug-keyed; see "Release signing" in `aq_mapping_app/README.md` before distributing (keystore + key.properties are gitignored)

## Sensor Reference
The Temtop M2000+ measures: PM2.5, PM10, particle count, CO2, HCHO, temperature, humidity.
CSV output columns from device: DATE, PM2.5(ug/m3), PM10(ug/m3), PARTICLES(per/L), CO2(ppm), HCHO(mg/m3), TEMPERATURE, HUMIDITY(%), TEMPUNIT
Sample device export: `lab_documents/Temtop sensor/Temtop_test_20250711.csv`

## Lab Context
- UTSC campus coordinates: 43.7841, -79.1873
- Students explore indoor (classrooms, food court) and outdoor (forest, roads) locations
- Lab documents are in `lab_documents/` directory

## Classroom Aggregation (end goal) — the hub is a separate Python tool
The debrief outcome is a projected map showing one group's points ("here's group 24") and all groups combined. **Decision (pivoted 2026-06-13): the classroom hub is a standalone Python/Plotly script, NOT a Flutter desktop build.** It lives in `classroom_map/` (repo root) and reads the phone app's CSV exports. Rationale: runs identically on the instructor's Windows work laptop and Mac with just `pip install` (no Visual Studio/Xcode/Flutter desktop toolchain), is ~a few hundred lines the instructor can maintain, and outputs self-contained HTML to project and share with students. The Flutter codebase stays **phone-app-only**.
- The hub lives at repo root in **`classroom_map/`** (moved out of the Flutter app 2026-06-17). Since 2026-07-17 the primary tool is **`home_base.py`** → one self-contained `classroom_dashboard.html` (tabs: Map · Interpolated · Heatmap · Stats; header with class totals + **group checklist** via `--expect N` / `--roster FILE`; per-file error tolerance, utf-8-sig). It uses the MapLibre trace family (`Scattermap`, Plotly ≥5.24). `build_map.py` is the frozen v1 reference (same four views as separate HTML files, old `*mapbox` traces, optional kaleido PNG export). Band colours/thresholds mirror `aq_mapping_app/lib/models/map_variable.dart` (the `VARS` list — keep in sync). `make_sample_data.py` makes synthetic UTSC data. Double-click `run_windows.bat` / `run_mac.command` (they build + open the dashboard). First-time instructions: `classroom_map/GETTING_STARTED.md` + its printable twin `Home_Base_Guide.docx` (generated by `make_guide.py` — edit script, re-run; replaced the stale `Classroom_Map_Guide.docx` 2026-07-17). Short reference: `classroom_map/README.md`.
- Constraints unchanged: student devices are **mixed iOS + Android**; tiles need wifi but Plotly JS is inlined. Transport today = **"Send to class"** uploads into the instructor's Google Sheet (primary once `UPLOAD_URL` is set; its CSV download drops into `csvs/`) with emailed/AirDropped CSVs as the backup — Home Base resolves overlapping copies (emailed export wins).
- **Phase 2 (future)** = the laptop hosts a local-LAN endpoint (e.g. a small Flask server — easy now that the hub is Python) so phones push readings over the instructor's hotspot and the map fills as groups return; campus-wide live while roaming is out of scope.
- The Flutter app keeps a **map group filter** (`map_screen.dart`) and **multi-file CSV import** (`csv_import_service.dart`) — useful on-device, retained after the pivot. The earlier macOS-desktop hub experiment was rolled back.

## App Icon
Launcher icons are generated by `flutter_launcher_icons` from `assets/icon/app_icon.png` (full-bleed, iOS+legacy Android) and `app_icon_foreground.png` (adaptive Android). Source art is produced by `tool/icon/make_icon.py`, which renders the same teal `filter_drama` cloud + particle dots as the in-app `_CloudParticlesIcon` (dots nudged left to clear the inner arc). Regenerate: edit the script → `python3 tool/icon/make_icon.py` → `dart run flutter_launcher_icons`. iOS caches launcher icons — delete the app from the device before reinstalling to see changes.

## Student Distribution — Web/PWA (decided 2026-06-13)
Students use **personal phones, mixed iOS + Android**, with **no institutional Apple/MDM support**. To avoid app-store friction every cohort, the data-entry app is distributed as a **web app / PWA**: students open a URL (Add to Home Screen) — no store, no Apple ID, no APK. **Same codebase still builds native iOS/Android.**
- **Web SQLite:** `sqflite` doesn't run on web, so a conditional-import factory (`lib/services/db_factory_{stub,io,web}.dart`, called from `main.dart`) swaps in `sqflite_common_ffi_web` (WASM + IndexedDB) on web. Uses the **no-web-worker** backend on purpose (the shared-worker one needs COOP/COEP headers GitHub Pages can't set). `web/sqlite3.wasm` is committed; regenerate via `dart run sqflite_common_ffi_web:setup`.
- **CSV delivery:** split behind a conditional import (`csv_export_platform_{io,web}.dart`) so `dart:io` stays out of the web build. Two actions since v1.1: **Send to instructor** (share sheet — native on mobile; Web Share API via share_plus's web implementation on web, needs HTTPS/localhost) and, web-only, **Save CSV** (browser download; on mobile the share sheet's "Save to Files" covers it — `kHasSeparateSave`). `SendOutcome` (shared/cancelled/savedInstead) drives honest feedback: share_plus's silent download fallback is disabled on web and replaced with an explained save. Import is bytes-only (no `dart:io`).
- **Hosting:** GitHub Pages via `.github/workflows/deploy-web.yml` (builds web, sets `--base-href` to the repo name, deploys on push to main). Needs a **public** repo (Pages is free only on public repos) and Settings → Pages → Source = "GitHub Actions".
- **Institution config (v1.2):** the workflow validates `/deploy.config.json` (`tool/check_config.py` — fails fast with readable errors), stamps `web/index.html`+`manifest.json` from it (`tool/patch_web_shell.py`; the web shell can't read dart-defines), and builds with `--dart-define-from-file=../deploy.config.json`. Python tools (`make_handout.py`, `home_base.py` title, `make_sample_data.py` centre/devices, `download_campus_tiles.py` bbox) read the same file; `AQ_CONFIG` env var overrides the path (used for testing). **CSV column names are deliberately NOT configurable** — they're the app↔hub↔Temtop file-format contract. Editing `deploy.config.json` on GitHub triggers a redeploy (it's in the workflow's `paths`).
- **Two deployments per push:** the workflow builds twice into one Pages artifact — UTSC config at the site root (live student URL unchanged) and `deploy.config.demo.json` at **`/demo/`** (generic "Example University" branding, shareable). ⚠ All project pages of one GitHub account share a **browser origin**, so same-domain deployments MUST differ in `STORAGE_KEY` (optional config key; namespaces the SQLite file name + shared_preferences keys). Empty/absent key = original names — required for the UTSC deployment so existing installs keep their data; the demo uses `"demo"`. Isolation verified locally: session saved in /demo/ is invisible at the root (distinct `flutter.demo_session_*` localStorage keys).
- **iOS Safari caveats (the real risk):** Add-to-Home-Screen is manual; IndexedDB can be evicted under storage pressure / ITP, so rule = **export your CSV before closing**; Safari-tab vs home-screen-icon storage are separate sandboxes. Map tiles still need wifi.
- Build/test: `flutter build web --release`; locally serve `build/web` over http to test.

## Current Status (as of 2026-07-17)
- ✅ Complete revision: session setup, entry form (± variability, indoor/outdoor, hard/soft validation, edit mode), history, map (variable selector + legend + heatmap + imported borders), Temtop-aligned CSV, import/merge with uid dedup, DB schema v2 + migration
- ✅ App improvements retained: map **group filter** (All / per-group, auto-fits camera), **multi-file CSV import** (pick many at once; web/desktop-safe via in-memory bytes; per-file failure reporting)
- ✅ **Classroom hub pivoted to Python/Plotly** (`classroom_map/` at repo root): merges CSVs, group + indoor/outdoor + variable filters, app-matched band colours, density heatmap, double-click launchers, README. Verified against synthetic data (all-groups + isolated-group renders). Flutter macOS-desktop hub experiment rolled back.
- ✅ AQ-themed launcher icon wired for iOS + Android (see App Icon above)
- ✅ **Web/PWA target — DEPLOYED LIVE** at `https://danweaver-ca.github.io/aq-mapper/` (repo `DanWeaver-ca/aq-mapper`, public, GitHub Actions → Pages). Conditional DB factory + CSV export, branded PWA.
- ✅ **Polish round (2026-06-14):**
  - **Offline campus tiles** — 128 OSM tiles for UTSC pre-bundled as `assets/tiles/<z>_<x>_<y>.png` (zooms 14–17, ~2MB) via `tool/download_campus_tiles.py`; served by `widgets/offline_first_tile_provider.dart` (asset-first, network fallback) so the map works offline in the field.
  - **Hub summary-stats panel** (`classroom_stats.html`) + one-click map image export (toolbar camera + PNG/PDF via kaleido).
  - **Hub map-viz upgrades (2026-06-16):** cleaner `carto-positron` basemap (drops OSM POI clutter); per-variable **"health bands" vs "spread"** colour modes (spread stretches to the robust 5–95th-pctile range, fixing the wash-out when readings cluster in one band); **`classroom_interpolated.html`** — a Gaussian-weighted estimated field (viridis, faded by distance to nearest sample) with points overlaid, framed as the sparse-data lesson (cf. NASA GISTEMP smoothing radius — see [[gistemp-smoothing-radius]] memory). One combined **Field · radius** dropdown selects both the variable (6 species) and a smoothing radius (tight/wide); widening fills more area = more coverage, more guesswork. Generous bbox padding avoids a hard image-edge boundary. Verified on Dan's real 2-phone/11-point export.
  - **Data-safety reminder** banner on the Data screen + **version label** (`appVersion` in `app_config.dart`) on the home screen.
  - **Root `README.md` + MIT `LICENSE`**; **student QR + handout** (`student_handout/`).
- ✅ **First full class run (2026-07-16):** lab delivered to visiting students; app, email collection, and hub debrief all worked. Field lesson: only ~half the groups' CSV exports arrived by email → v1.1 below. Improvement planning in `docs/v2_improvement_plan.md`; article draft in `docs/article_draft.md`.
- ✅ **v1.1 send/save split (2026-07-17):** Data screen now has **Send to instructor** (share sheet — native on mobile, Web Share API on web via share_plus's web implementation; HTTPS/localhost required) plus a web-only **Save CSV to my phone** download (`kHasSeparateSave`). `SendOutcome` (shared / cancelled / savedInstead) drives honest feedback: share_plus's silent download fallback is disabled on web and replaced by an explained save. `instructorEmail` in `app_config.dart` (blank = hint hidden) with a copy button. App version 1.1.1 (pubspec 1.1.1+3; 1.1.1 enlarged the instructor-email hint into a teal callout with copy instructions). Widget tests for the Data screen must use `databaseFactoryFfiNoIsolate` (the worker-isolate ffi factory deadlocks under `testWidgets`' fake async).
- ✅ **Home Base dashboard (2026-07-17):** `classroom_map/home_base.py` replaces the four-window debrief with one tabbed `classroom_dashboard.html` (~5 MB vs ~14 MB; Plotly.js inlined once) — header totals, group checklist (green received / grey missing chips, case-insensitive matching), skipped-file warnings, argparse (`csv_dir`, `-o`, `--expect`, `--roster`, `--title`). Migrated to MapLibre traces (`go.Scattermap`/`px.density_map`, requirements now `plotly>=5.24,<7`) — no deprecation warnings on Plotly 6. `build_map.py` kept untouched as the v1 reference; launchers now build+open the dashboard. Verified on sample data (tabs, tiles, checklist, stats) and the real June 2-phone export.
- ✅ **v1.2 one-file institution setup (2026-07-17):** `/deploy.config.json` (12 flat keys: titles, institution, email, campus lat/lon, device prefix+count, sensor name, app URL, tiles bbox) drives everything — app via `--dart-define-from-file` (no `double.fromEnvironment` exists, so coords parse from strings into a `final LatLng`), web shell via a workflow stamp step, python tools via `json.load` with `AQ_CONFIG` override. `SETUP.md` = adopter walkthrough. Verified end-to-end with a fictional school config (Northview/Ottawa/AirBeam/NV-AQ-×6): every value landed in the built app (incl. map centred on Ottawa, checked via requested tile coordinates) and in all four python outputs. Sample-data generator now offsets routes from the configured centre (UTSC output coordinates unchanged; pm-falloff lon-metres now computed from latitude). App 1.2.0 (pubspec 1.2.0+4).
- ✅ **Two deployments + demo (2026-07-17):** generic demo at `/demo/` built from `deploy.config.demo.json` every push; new optional `STORAGE_KEY` config namespaces DB file + prefs keys for same-origin deployments (empty = legacy names, guarding existing installs — regression-tested). Same-origin storage isolation verified locally with both builds served from one origin.
- ✅ `flutter analyze` clean, 53 tests passing; `flutter build web` succeeds with tiles bundled
- ✅ **Real-device tested (2026-06-16):** the live web app worked on Dan's iPhone on campus (GPS, offline tiles, persistence, export) and on a technician's Android phone; both exports merged in the hub. The hub's full viz suite (group filter, health/spread colouring, stats, density heatmap, interpolated field) verified on the real 2-phone/11-point export.
  - Caveat seen: the technician's Android reported a coarse cell-tower location (~1.4km off) — students with imprecise / "Precise Location off" settings will produce off-target points. Mitigation pending: a handout line to enable high-accuracy location, optionally an in-app "approximate location" warning at save time.

- ✅ **Repo reorganized (2026-06-17):** the standalone Python tools moved out of the Flutter app to the repo root (`classroom_map/`, `student_handout/`); unused desktop scaffolding (`macos/windows/linux`) deleted (regenerable via `flutter create`); project briefs moved to `docs/`. The Flutter app (`aq_mapping_app/`) is unchanged and still one codebase building iOS + Android + web. The native-capable state is tagged `v1.0.0`.

- ✅ **v3 / app 2.0.0 (2026-07-24, built after lab 2's send failures — ~half of groups couldn't email their CSV: no email account, or the app opened inside WeChat):**
  - **"Send to class" one-tap upload** (`upload_service.dart` + `classroom_map/upload_endpoint/` Apps Script → Google Sheet whose columns are byte-identical to the app CSV, so its CSV download drops into Home Base's `csvs/`). Opt-in via `UPLOAD_URL` in deploy.config.json (empty = button absent — live site unchanged until Dan deploys the endpoint per `SETUP_UPLOAD.md` and flips the config). Idempotent: sends all rows every time, endpoint + Home Base dedup by UID; no DB schema change. Works inside WeChat (plain fetch POST).
  - **WeChat/QQ interceptor** in `web/index.html`: bilingual overlay (UA `MicroMessenger`/` QQ/`; `?simulate=wechat` to test) steering to "⋯ → Open in Browser" before data lands in WeChat's separate storage sandbox; softer dismissible wording when UPLOAD_URL is configured (stamped by `patch_web_shell.py`).
  - **Campus POI layer**: optional `/campus_pois.geojson` at repo root (draw on geojson.io; `campus_pois.example.geojson` shows the format) → labelled indigo pins + boundary outline in the app map (runtime fetch, prefs-cached for offline) and on Home Base's Map tab (`--pois`; dropdown restyle arrays extended over the POI traces — Plotly cycles short arrays). Workflow copies it to the site root (institution deployment only).
  - App QR caption now bilingual "use your Camera, not WeChat" (`make_qr.py` grew CJK font support + shrink-to-fit). Tag `v2.0-lab2` preserves the exact lab-2 state; all v3 features are config-gated off by default.

- ✅ **v3 activation prep (2026-08-07 — decision: "Send to class" = primary path for lab 3, email = backup; Power Automate ruled out, no app/licence on the U of T account):**
  - **Endpoint corrections now propagate:** `Code.gs` is last-write-wins with change detection — a re-sent unchanged row writes nothing (fast under LockService), an edited reading overwrites its old row in place and refreshes RECEIVED_AT; response gains `updated` (the app ignores unknown keys — zero Dart changes). Verified by executing the real Code.gs in Node with mocked SpreadsheetApp/LockService/ContentService (7 scenarios incl. in-place correction + no-op re-send).
  - **Home Base precedence for duplicate UIDs:** latest app export > earlier app export > class-sheet download. Sheet downloads self-identify by their RECEIVED_AT column (only they have it), so filenames never matter — Google's default download name works as-is. Implemented as partition-ordered concat + `drop_duplicates(keep="last")` in `load_folder`. Verified against the real June exports + synthetic conflict files; full dashboard builds green.
  - **Fallback layers (v2 stays runnable):** `home_base_v2.py` = frozen lab-2 dashboard tool extracted from the tag, kept beside the v3 file and verified to run; `"UPLOAD_URL": ""` + push reverts the live site to exact lab-2 behaviour; tag `v2.0-lab2` = whole-repo lab-2 state. SETUP_UPLOAD.md gained the lab-day flow (wifi-first note for roaming Chinese SIMs — Google unreachable via home-carrier routing; transit-not-storage: delete the sheet after the debrief download) and a Rollback section; GETTING_STARTED/README synced. June test CSVs archived to `csvs/archive_2026-06_junetest/` (subfolders are outside the glob).

## Next Steps (priority order — v1.1 and v1.2 are shipped & deployed)
1. **Phone verification of v1.2** (Dan, ~2 min): UTSC URL still has his existing data/session (empty `STORAGE_KEY` keeps legacy storage names — regression-tested, but the phone is ground truth); `/demo/` starts blank with Example University branding. Also the untested corners of the send-flow device matrix: iPhone home-screen PWA (standalone mode), Android Chrome, desktop Firefox (expect the labelled saved-instead fallback).
2. **Pre-article polish round** (`docs/v2_improvement_plan.md` §5): README screenshots + demo GIF (regenerate from sample data only), CI workflow running `flutter analyze`+`flutter test`+hub smoke test with badges, CITATION.cff + Zenodo DOI on next release, regenerate the student handout (new "Send to instructor" wording + the pending "enable Precise Location" line).
3. **Publication** (`docs/article_draft.md`): fill the [bracketed] facts from the 2026-07-16 run, regenerate figures from `sample_csvs/`, submit. Venue plan updated 2026-07-18 (details in the draft's venue notes): activity paper → The Physics Teacher first (Connected Science Learning second; Physics Education demoted — discourages phone-as-equipment full papers), **plus a JOSE software paper in parallel** (reviews the repo itself; polish round ≈ JOSE checklist). Atmospheric-science community voiced interest via the summer-school TA's conference report → BAMS/Eos piece or AGU/AMS/CMOS talk as companion; TA summer-school pilot (v1.2 config test + second site) → JGE research paper later if learning outcomes collected.
4. **Activate v3 before lab 3 (~week of 2026-08-10) — decided 2026-08-07: upload primary, email backup; endpoint+hub changes landed (see status).** Dan's remaining steps: deploy the Apps Script (`classroom_map/upload_endpoint/SETUP_UPLOAD.md`, ~5 min), set `UPLOAD_URL` in deploy.config.json + push, then the rehearsal checklist: (a) phone → Send to class → rows in sheet; (b) edit a reading, re-send → correction lands in place; (c) sheet download + emailed export both in `csvs/` → Home Base shows one copy per row with the emailed value winning; (d) **real WeChat** (UA-simulated only so far): QR → softened overlay → upload works inside the webview; (e) existing iPhone-PWA install still has its data. Windows laptop: re-download `home_base.py` (**now load-bearing** — precedence change) + new `home_base_v2.py`, empty its `csvs/`. Optional: draw `campus_pois.geojson`. Tag `v3.0-lab3` once rehearsed. Any failure → Rollback section of SETUP_UPLOAD.md. Remaining v2.0 dream: live/Dash Home Base with auto-refreshing checklist; LAN/hotspot mode (same upload code path).
5. *(optional)* outdoor-only interpolation (indoor points = interpolating "through walls"; deferred 2026-06-16); group-code picker + `ACCURACY_M` column (⚠ schema v3 + migration + ffi test); zh-CN strings for visiting cohorts.
