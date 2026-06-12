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

## Current Status (as of 2026-06-12)
- ✅ Complete revision implemented: session setup (group/device/°C-°F), entry form with ± variability + indoor/outdoor + hard/soft validation + edit mode, history screen (edit/swipe-delete), map variable selector + legend + heatmap toggle + imported-point borders, Temtop-aligned 22-column CSV, in-app CSV import/merge with uid dedup, DB schema v2 with v1→v2 migration
- ✅ `flutter analyze` clean, 41 tests passing
- ⏳ Not yet run in iOS Simulator since the revision (pods may need `pod install`)
- ⏳ Not yet tested on physical iPhone 16 Pro

## Next Steps (priority order)
1. **Simulator smoke pass** — fresh install → session setup → entries (incl. ± and indoor) → map chips/legend/heatmap → history edit/delete → export → re-import own file (expect "0 imported, N duplicates") → clear imported. Also upgrade-in-place from a v1 build to verify the migration on-device
2. **Test on iPhone 16 Pro** — connect via USB, set signing team in Xcode (Runner → Signing & Capabilities → Team), trust cert on device
3. **Android build** — test APK on Android device once iOS is stable (switch to release signing first, see README)
4. **App icon + name** — replace default Flutter icon with something AQ-themed
5. **Possible enhancement** — register the app as a CSV open-in handler (CFBundleDocumentTypes) so AirDropped files open directly in the app
