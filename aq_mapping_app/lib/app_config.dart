import 'package:latlong2/latlong.dart';

/// App-wide branding and defaults.
///
/// Every value here can be overridden per deployment WITHOUT editing this
/// file: change /deploy.config.json (repo root) and build with
///   flutter build web --dart-define-from-file=../deploy.config.json
/// — which is what the GitHub Pages workflow does on every push. The
/// defaults below are the UTSC reference deployment, so a plain
/// `flutter run` still works during development. Adopting this app for
/// another institution = editing deploy.config.json; see /SETUP.md.

/// App name shown on the home screen.
const String appTitle =
    String.fromEnvironment('APP_TITLE', defaultValue: 'Air Quality Mapper');

/// Shown small in the UI so you can tell which build a student is running.
/// Bump when distributing a new version. Deliberately NOT configurable —
/// it identifies the code, not the institution.
const String appVersion = '1.2.0';

/// Shown under "Send to instructor" on the Data screen so students can
/// address the share (the Web Share API cannot pre-fill a recipient).
/// Empty hides the hint. Public by design — it ships in the app bundle,
/// so use a role/department address if that matters.
const String instructorEmail = String.fromEnvironment('INSTRUCTOR_EMAIL',
    defaultValue: 'dan.weaver@utoronto.ca');

/// Sensor brand used in UI wording ("the ID printed on your Temtop
/// sensor"). The CSV column names are NOT derived from this — they are a
/// fixed file-format contract shared by the app, the classroom hub, and
/// the Temtop device's own exports (see models/measurement.dart).
const String sensorName =
    String.fromEnvironment('SENSOR_NAME', defaultValue: 'Temtop');

/// Device-ID dropdown scheme: prefix + zero-padded 1..count
/// ("UTSC-AQMS-01" … "UTSC-AQMS-25"). Session setup always appends an
/// "Other…" free-text option for sensors outside the scheme.
const String deviceIdPrefix =
    String.fromEnvironment('DEVICE_ID_PREFIX', defaultValue: 'UTSC-AQMS-');
const int deviceCount = int.fromEnvironment('DEVICE_COUNT', defaultValue: 25);

/// The standard device IDs derived from [deviceIdPrefix] + [deviceCount].
List<String> standardDeviceIds() => List.generate(deviceCount,
    (i) => '$deviceIdPrefix${(i + 1).toString().padLeft(2, '0')}');

/// Namespaces on-device storage (database file + settings keys) so that two
/// deployments hosted under the SAME web origin — e.g. the UTSC app at
/// /aq-mapper/ and the public demo at /aq-mapper/demo/, since all GitHub
/// project pages of one account share an origin — don't see each other's
/// data. Empty (the default) keeps the original storage names, so existing
/// installs keep their data. Set it (e.g. "demo") for any additional
/// deployment under the same domain.
const String storageKey =
    String.fromEnvironment('STORAGE_KEY', defaultValue: '');

// Dart has no double.fromEnvironment, so the campus coordinates travel as
// strings and are parsed once below (hence `final`, not `const`).
const String _campusLat =
    String.fromEnvironment('CAMPUS_LAT', defaultValue: '43.7841');
const String _campusLon =
    String.fromEnvironment('CAMPUS_LON', defaultValue: '-79.1873');

/// Last-resort map center when there are no measurements and GPS is
/// unavailable (the configured campus). The map prefers measurement
/// locations, then the device's own location.
final LatLng defaultMapCenter =
    LatLng(double.parse(_campusLat), double.parse(_campusLon));
