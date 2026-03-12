# AQ Mapper - Air Quality Mobile Mapping App

## Project Overview
A Flutter mobile app (iOS + Android) for UTSC air quality lab activities. Visiting students carry Temtop M2000+ sensors around campus and enter readings into the app, which auto-captures GPS coordinates. Data can be visualized on a map and exported as CSV.

## Tech Stack
- **Framework**: Flutter (Dart)
- **Maps**: OpenStreetMap via `flutter_map` + `latlong2` (no API key needed)
- **GPS**: `geolocator` package
- **Storage**: SQLite via `sqflite`
- **Export**: CSV via `csv` + `share_plus`
- **State**: Simple StatefulWidgets (no Provider/Bloc needed at current scale)

## Project Structure
```
aq_mapping_app/
  lib/
    main.dart                          # App entry point, Material 3 theme
    models/measurement.dart            # Data model (PM2.5, PM10, CO2, HCHO, temp, humidity, GPS, notes)
    screens/
      home_screen.dart                 # Navigation hub (3 buttons)
      entry_screen.dart                # Sensor reading form + GPS capture
      map_screen.dart                  # OpenStreetMap with color-coded markers
      export_screen.dart               # CSV export + share + delete-all
    services/
      database_service.dart            # SQLite CRUD
      location_service.dart            # GPS wrapper with permission handling
      csv_export_service.dart          # CSV generation + sharing
```

## Key Design Decisions
- **OpenStreetMap** over Google Maps: no API key, no Google services dependency (important for visiting Chinese students)
- **Offline-first**: SQLite + GPS work without internet; only map tiles need connectivity
- **CSV headers** match Temtop M2000+ sensor output format for easy comparison
- **Map markers** color-coded by PM2.5: green (<=12), orange (<=35), deep orange (<=55), red (>55)

## Build & Run
```bash
# Flutter must be on PATH
export XDG_CONFIG_HOME=$HOME/Projects/.config  # workaround for ~/.config ownership issue

flutter pub get
flutter analyze
flutter run              # run on connected device/simulator
flutter build ios        # iOS build
flutter build apk        # Android build
flutter build web        # web build (for testing)
```

## Platform Config
- **iOS**: Location permissions in `ios/Runner/Info.plist` (NSLocationWhenInUseUsageDescription)
- **Android**: Location + internet permissions in `android/app/src/main/AndroidManifest.xml`

## Sensor Reference
The Temtop M2000+ measures: PM2.5, PM10, particle count, CO2, HCHO, temperature, humidity.
CSV output columns from device: DATE, PM2.5(ug/m3), PM10(ug/m3), PARTICLES(per/L), CO2(ppm), HCHO(mg/m3), TEMPERATURE, HUMIDITY(%), TEMPUNIT

## Lab Context
- UTSC campus coordinates: 43.7841, -79.1873
- Students explore indoor (classrooms, food court) and outdoor (forest, roads) locations
- Lab documents are in `lab_documents/` directory
