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
aq_mapping_app/
  lib/
    main.dart                          # App entry point, Material 3 theme
    app_config.dart                    # Branding (app title) + default map center — edit here
                                       #   to rebrand for other campuses/outreach events
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
      data_screen.dart                 # CSV export & share, import/merge, clear imported, delete all
    services/
      database_service.dart            # SQLite CRUD, v1→v2 migration, insertIfNew dedup
      session_service.dart             # shared_preferences wrapper for session settings
      location_service.dart            # GPS wrapper with permission handling
      csv_export_service.dart          # CSV generation + sharing
      csv_import_service.dart          # CSV parsing/validation + merge (source='imported')
    widgets/
      heatmap_layer.dart               # flutter_map_heatmap wrapper (only file touching it)
  test/                                # 41 tests: model, CSV round-trip, migration (ffi),
                                       #   dedup, thresholds, bounds, widget validation
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
The debrief outcome is a projected map showing one group's points ("here's group 24") and all groups combined. **Decision (pivoted 2026-06-13): the classroom hub is a standalone Python/Plotly script, NOT a Flutter desktop build.** It lives in `aq_mapping_app/tool/classroom_map/` and reads the phone app's CSV exports. Rationale: runs identically on the instructor's Windows work laptop and Mac with just `pip install` (no Visual Studio/Xcode/Flutter desktop toolchain), is ~a few hundred lines the instructor can maintain, and outputs self-contained HTML to project and share with students. The Flutter codebase stays **phone-app-only**.
- The hub: `build_map.py` merges a folder of CSVs (dedup by UID), renders `classroom_map.html` (Show dropdown: All/Outdoor/Indoor/per-group; Colour-by dropdown: PM2.5/PM10/CO2/HCHO/Temp/Humidity) plus a PM2.5 density `classroom_heatmap.html`. Band colours/thresholds mirror `lib/models/map_variable.dart` (the `VARS` list — keep in sync). `make_sample_data.py` makes synthetic UTSC data. Double-click `run_windows.bat` / `run_mac.command`. See `tool/classroom_map/README.md`.
- Constraints unchanged: student devices are **mixed iOS + Android**; tiles need wifi but Plotly JS is inlined. Transport today = collect CSVs (AirDrop/email/shared folder) into `csvs/`.
- **Phase 2 (future)** = the laptop hosts a local-LAN endpoint (e.g. a small Flask server — easy now that the hub is Python) so phones push readings over the instructor's hotspot and the map fills as groups return; campus-wide live while roaming is out of scope.
- The Flutter app keeps a **map group filter** (`map_screen.dart`) and **multi-file CSV import** (`csv_import_service.dart`) — useful on-device, retained after the pivot. The earlier macOS-desktop hub experiment was rolled back.

## App Icon
Launcher icons are generated by `flutter_launcher_icons` from `assets/icon/app_icon.png` (full-bleed, iOS+legacy Android) and `app_icon_foreground.png` (adaptive Android). Source art is produced by `tool/icon/make_icon.py`, which renders the same teal `filter_drama` cloud + particle dots as the in-app `_CloudParticlesIcon` (dots nudged left to clear the inner arc). Regenerate: edit the script → `python3 tool/icon/make_icon.py` → `dart run flutter_launcher_icons`. iOS caches launcher icons — delete the app from the device before reinstalling to see changes.

## Student Distribution — Web/PWA (decided 2026-06-13)
Students use **personal phones, mixed iOS + Android**, with **no institutional Apple/MDM support**. To avoid app-store friction every cohort, the data-entry app is distributed as a **web app / PWA**: students open a URL (Add to Home Screen) — no store, no Apple ID, no APK. **Same codebase still builds native iOS/Android.**
- **Web SQLite:** `sqflite` doesn't run on web, so a conditional-import factory (`lib/services/db_factory_{stub,io,web}.dart`, called from `main.dart`) swaps in `sqflite_common_ffi_web` (WASM + IndexedDB) on web. Uses the **no-web-worker** backend on purpose (the shared-worker one needs COOP/COEP headers GitHub Pages can't set). `web/sqlite3.wasm` is committed; regenerate via `dart run sqflite_common_ffi_web:setup`.
- **CSV export:** split behind a conditional import (`csv_export_platform_{io,web}.dart`) so `dart:io` stays out of the web build — native share sheet on mobile, browser download on web. Import is bytes-only (no `dart:io`).
- **Hosting:** GitHub Pages via `.github/workflows/deploy-web.yml` (builds web, sets `--base-href` to the repo name, deploys on push to main). Needs a **public** repo (Pages is free only on public repos) and Settings → Pages → Source = "GitHub Actions".
- **iOS Safari caveats (the real risk):** Add-to-Home-Screen is manual; IndexedDB can be evicted under storage pressure / ITP, so rule = **export your CSV before closing**; Safari-tab vs home-screen-icon storage are separate sandboxes. Map tiles still need wifi.
- Build/test: `flutter build web --release`; locally serve `build/web` over http to test.

## Current Status (as of 2026-06-13)
- ✅ Complete revision: session setup, entry form (± variability, indoor/outdoor, hard/soft validation, edit mode), history, map (variable selector + legend + heatmap + imported borders), Temtop-aligned CSV, import/merge with uid dedup, DB schema v2 + migration
- ✅ App improvements retained: map **group filter** (All / per-group, auto-fits camera), **multi-file CSV import** (pick many at once; web/desktop-safe via in-memory bytes; per-file failure reporting)
- ✅ **Classroom hub pivoted to Python/Plotly** (`tool/classroom_map/`): merges CSVs, group + indoor/outdoor + variable filters, app-matched band colours, density heatmap, double-click launchers, README. Verified against synthetic data (all-groups + isolated-group renders). Flutter macOS-desktop hub experiment rolled back.
- ✅ AQ-themed launcher icon wired for iOS + Android (see App Icon above)
- ✅ **Web/PWA target — DEPLOYED LIVE** at `https://danweaver-ca.github.io/aq-mapper/` (repo `DanWeaver-ca/aq-mapper`, public, GitHub Actions → Pages). Conditional DB factory + CSV export, branded PWA.
- ✅ **Polish round (2026-06-14):**
  - **Offline campus tiles** — 128 OSM tiles for UTSC pre-bundled as `assets/tiles/<z>_<x>_<y>.png` (zooms 14–17, ~2MB) via `tool/download_campus_tiles.py`; served by `widgets/offline_first_tile_provider.dart` (asset-first, network fallback) so the map works offline in the field.
  - **Hub summary-stats panel** (`classroom_stats.html`) + one-click map image export (toolbar camera + PNG/PDF via kaleido).
  - **Data-safety reminder** banner on the Data screen + **version label** (`appVersion` in `app_config.dart`) on the home screen.
  - **Root `README.md` + MIT `LICENSE`**; **student QR + handout** (`tool/student_handout/`).
- ✅ `flutter analyze` clean, 45 tests passing; `flutter build web` succeeds with tiles bundled
- ⏳ Offline tiles, data-safety banner, and the whole web build **not yet verified on a real iPhone** — the iOS Safari spike is still the gate

## Next Steps (priority order)
1. **iOS Safari spike (the de-risk)** — open the live URL on a real iPhone: location permission → enter a reading → appears on map; pan the campus offline (airplane mode) to confirm bundled tiles draw; Add to Home Screen; reopen from icon; export downloads a CSV; confirm data persists. This is where the web plan could still disappoint
2. **Push the latest polish** — `git push` to deploy the offline tiles + reminders (auto-deploys via Actions)
3. **Hub dry run with real data** — export a few phones' CSVs into `tool/classroom_map/csvs/`, run the launcher, rehearse the "here's group N → all groups → stats" debrief
4. **Re-verify icon on iPhone** (native build) — rebuild/reinstall (delete app first due to iOS icon caching)
5. **Phase 2 — local-LAN sync** — small Flask server on the instructor's laptop/hotspot; a "Sync to class" push so the projected map fills as groups return
