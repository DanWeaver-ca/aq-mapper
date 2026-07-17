import 'package:flutter_test/flutter_test.dart';
import 'package:aq_mapping_app/app_config.dart';
import 'package:aq_mapping_app/services/database_service.dart';

// These run against the compile-time defaults (no --dart-define-from-file in
// `flutter test`), which are the UTSC reference deployment — the point is to
// guard the derivation logic every fork relies on.
void main() {
  test('standard device IDs derive from prefix + count', () {
    final ids = standardDeviceIds();
    expect(ids.length, deviceCount);
    expect(ids.first, '${deviceIdPrefix}01');
    expect(ids, everyElement(startsWith(deviceIdPrefix)));
    expect(ids.toSet().length, ids.length, reason: 'IDs must be unique');
  });

  test('campus coordinate strings parse into a valid map center', () {
    expect(defaultMapCenter.latitude, inInclusiveRange(-90, 90));
    expect(defaultMapCenter.longitude, inInclusiveRange(-180, 180));
  });

  test('branding strings are non-empty', () {
    expect(appTitle.trim(), isNotEmpty);
    expect(sensorName.trim(), isNotEmpty);
    expect(appVersion.trim(), isNotEmpty);
  });

  test('empty storage key keeps the original database name', () {
    // Guards existing installs: with no STORAGE_KEY define (the default and
    // the UTSC deployment), storage names must not change or user data
    // silently "disappears" behind a new file name.
    expect(storageKey, isEmpty);
    expect(DatabaseService.databaseFileName, 'aq_measurements.db');
  });
}
