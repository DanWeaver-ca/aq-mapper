# AQ Mapper

Flutter app (iOS + Android) for the UTSC air quality lab. Student groups carry
Temtop M2000+ handheld sensors around campus, type readings into the app
(GPS + timestamp attached automatically), and the data feeds a color-coded
pollution map and a CSV export that can be merged across groups.

## Lab workflow

1. **Session setup** (first launch): enter your group name, the sensor's
   device ID (`UTSC-AQMS-01`…`25`), and temperature unit. These tag every
   measurement.
2. **Measure**: at each site, watch the sensor for a few minutes, then enter
   the typical value and its variability (e.g., CO₂ `425` ± `15` ppm). Toggle
   Indoor/Outdoor, add notes (wind, foot traffic, sources), and save — GPS and
   time are captured for you.
3. **Explore**: the Map screen colors points by any variable (PM2.5, PM10,
   CO₂, HCHO, Temp, RH) with a threshold legend, and has a heatmap toggle.
   History lets you review, edit, or delete entries.
4. **Share**: Export & Share produces a CSV (Temtop-compatible column names
   first, then GPS/group/variability columns) named after your device, e.g.
   `aq_UTSC-AQMS-07_20260612_140321.csv`. Send it to the instructor via
   AirDrop, email, or Drive.
5. **Merge** (instructor): on the receiving device, save each group's CSV to
   Files, then use *Import CSV from another group* on the Data screen.
   Duplicate rows are skipped automatically; imported points show a dark
   border on the map and can be cleared separately without touching your own
   data.

Raw CSV files downloaded from the Temtop device itself cannot be imported —
they have no GPS coordinates. Import only files exported by this app.

## Build & run

```bash
export XDG_CONFIG_HOME=$HOME/Projects/.config  # workaround for ~/.config ownership issue
flutter pub get
flutter analyze
flutter test
flutter run            # connected device/simulator
flutter build ios
flutter build apk
```

## Release signing (Android)

Release builds currently use the debug key. Before distributing an APK:

1. Create a keystore (once, keep it safe and **never commit it**):

   ```bash
   keytool -genkey -v -keystore ~/aq-mapper-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias aqmapper
   ```

2. Create `android/key.properties` (gitignored):

   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=aqmapper
   storeFile=/Users/<you>/aq-mapper-release.jks
   ```

3. In `android/app/build.gradle.kts`, load the properties and replace the
   debug signing config:

   ```kotlin
   import java.util.Properties

   val keystoreProperties = Properties().apply {
       val f = rootProject.file("key.properties")
       if (f.exists()) f.inputStream().use { load(it) }
   }

   android {
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String?
               keyPassword = keystoreProperties["keyPassword"] as String?
               storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
               storePassword = keystoreProperties["storePassword"] as String?
           }
       }
       buildTypes {
           release {
               signingConfig = signingConfigs.getByName("release")
           }
       }
   }
   ```

## Tests

`flutter test` covers: model/DB round-trips, the v1→v2 schema migration
(in-memory SQLite via `sqflite_common_ffi`), CSV export→import round-trips,
import dedup by UID, map color thresholds at every band boundary, validation
bounds, and entry-form widget validation.
