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

aq_mapping_app/                        # —— the Flutter app, in detail ——
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
The debrief outcome is a projected map showing one group's points ("here's group 24") and all groups combined. **Decision (pivoted 2026-06-13): the classroom hub is a standalone Python/Plotly script, NOT a Flutter desktop build.** It lives in `classroom_map/` (repo root) and reads the phone app's CSV exports. Rationale: runs identically on the instructor's Windows work laptop and Mac with just `pip install` (no Visual Studio/Xcode/Flutter desktop toolchain), is ~a few hundred lines the instructor can maintain, and outputs self-contained HTML to project and share with students. The Flutter codebase stays **phone-app-only**.
- The hub lives at repo root in **`classroom_map/`** (moved out of the Flutter app 2026-06-17). `build_map.py` merges a folder of CSVs (dedup by UID), renders `classroom_map.html` (Show dropdown: All/Outdoor/Indoor/per-group; Colour-by dropdown: PM2.5/PM10/CO2/HCHO/Temp/Humidity) plus a PM2.5 density `classroom_heatmap.html`. Band colours/thresholds mirror `aq_mapping_app/lib/models/map_variable.dart` (the `VARS` list — keep in sync). `make_sample_data.py` makes synthetic UTSC data. Double-click `run_windows.bat` / `run_mac.command`. See `classroom_map/README.md`.
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

## Current Status (as of 2026-06-16)
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
- ✅ `flutter analyze` clean, 45 tests passing; `flutter build web` succeeds with tiles bundled
- ✅ **Real-device tested (2026-06-16):** the live web app worked on Dan's iPhone on campus (GPS, offline tiles, persistence, export) and on a technician's Android phone; both exports merged in the hub. The hub's full viz suite (group filter, health/spread colouring, stats, density heatmap, interpolated field) verified on the real 2-phone/11-point export.
  - Caveat seen: the technician's Android reported a coarse cell-tower location (~1.4km off) — students with imprecise / "Precise Location off" settings will produce off-target points. Mitigation pending: a handout line to enable high-accuracy location, optionally an in-app "approximate location" warning at save time.

- ✅ **Repo reorganized (2026-06-17):** the standalone Python tools moved out of the Flutter app to the repo root (`classroom_map/`, `student_handout/`); unused desktop scaffolding (`macos/windows/linux`) deleted (regenerable via `flutter create`); project briefs moved to `docs/`. The Flutter app (`aq_mapping_app/`) is unchanged and still one codebase building iOS + Android + web. The native-capable state is tagged `v1.0.0`.

## Next Steps (priority order)
1. **Push the unpushed commits** — `git push` deploys the polished web app (offline tiles, data-safety banner) to the live URL via Actions and syncs the hub changes. Until pushed, the live site is the pre-polish build.
2. **Phase 2 — local-LAN sync** — small Flask server on the instructor's laptop/hotspot; a "Sync to class" push so the projected map fills as groups return (now easy since the hub is Python)
3. **Re-verify icon on iPhone** (native build only) — web is the primary distribution path now; native is optional
4. *(optional)* **Outdoor-only interpolation** — `classroom_interpolated.html` currently interpolates all points; a spatial field is physically meaningful only for outdoor readings (indoor = interpolating "through walls"). Filtering to outdoor would be more correct. Discussed + deferred 2026-06-16.
5. *(optional, classroom prep)* add a "Group 01…25" naming convention for students so the hub's group dropdown sorts cleanly; remind students to enable precise location.
