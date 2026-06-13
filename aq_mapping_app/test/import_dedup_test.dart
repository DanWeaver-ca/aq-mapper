import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aq_mapping_app/services/csv_export_service.dart';
import 'package:aq_mapping_app/services/csv_import_service.dart';
import 'package:aq_mapping_app/services/database_service.dart';

import 'measurement_test.dart' show fullMeasurement;

void main() {
  sqfliteFfiInit();

  late Database db;
  late DatabaseService service;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await DatabaseService.onCreateDb(db, 2);
    DatabaseService.testDatabase = db;
    service = DatabaseService();
  });

  tearDown(() async {
    DatabaseService.testDatabase = null;
    await db.close();
  });

  test('insertIfNew skips uids already in the database', () async {
    final m = fullMeasurement();
    await service.insertMeasurement(m);

    final result = await service.insertIfNew([
      m, // duplicate
      m.copyWith(uid: 'other-uid-1'),
      m.copyWith(uid: 'other-uid-2'),
      m.copyWith(uid: 'other-uid-2'), // duplicate within the batch
    ]);

    expect(result.inserted, 2);
    expect(result.skipped, 2);
    expect(await service.getAllMeasurements(), hasLength(3));
  });

  test('re-importing own export is a counted no-op', () async {
    final own = fullMeasurement();
    await service.insertMeasurement(own);

    final csvText = CsvExportService().buildCsv([own]);
    final result = await CsvImportService(service).importCsvText(csvText);

    expect(result.imported, 0);
    expect(result.duplicates, 1);
    expect(result.errors, 0);
    // Own row keeps source='local'.
    final counts = await service.countBySource();
    expect(counts['local'], 1);
    expect(counts.containsKey('imported'), isFalse);
  });

  test('importing another group\'s export tags rows as imported', () async {
    final other = fullMeasurement().copyWith(
      uid: 'UTSC-AQMS-11-99-beef',
      groupName: 'Birch Group',
      deviceId: 'UTSC-AQMS-11',
    );
    final csvText = CsvExportService().buildCsv([other]);
    final result = await CsvImportService(service).importCsvText(csvText);

    expect(result.imported, 1);
    final all = await service.getAllMeasurements();
    expect(all.single.source, 'imported');
    expect(all.single.groupName, 'Birch Group');
    expect(all.single.deviceId, 'UTSC-AQMS-11');
  });

  test('deleteImported keeps local rows', () async {
    await service.insertMeasurement(fullMeasurement());
    await service.insertIfNew([
      fullMeasurement().copyWith(uid: 'imp-1', source: 'imported'),
      fullMeasurement().copyWith(uid: 'imp-2', source: 'imported'),
    ]);

    final removed = await service.deleteImported();
    expect(removed, 2);
    final remaining = await service.getAllMeasurements();
    expect(remaining, hasLength(1));
    expect(remaining.single.source, 'local');
  });

  test('importMany merges several groups and aggregates counts', () async {
    final g11 = fullMeasurement().copyWith(
        uid: 'g11-1', groupName: 'Birch', deviceId: 'UTSC-AQMS-11');
    final g12 = fullMeasurement().copyWith(
        uid: 'g12-1', groupName: 'Cedar', deviceId: 'UTSC-AQMS-12');
    final export = CsvExportService();

    final result = await CsvImportService(service).importMany([
      (name: 'group11.csv', content: export.buildCsv([g11])),
      (name: 'group12.csv', content: export.buildCsv([g12])),
      // group11 sent again — every row is a cross-file duplicate.
      (name: 'group11_again.csv', content: export.buildCsv([g11])),
    ]);

    expect(result.files, 3);
    expect(result.imported, 2);
    expect(result.duplicates, 1);
    expect(result.errors, 0);
    expect(result.failures, isEmpty);

    final groups =
        (await service.getAllMeasurements()).map((m) => m.groupName).toSet();
    expect(groups, {'Birch', 'Cedar'});
  });

  test('importMany skips a bad file but still imports the good ones',
      () async {
    final good = fullMeasurement().copyWith(uid: 'good-1', groupName: 'Elm');
    const temtopCsv =
        'DATE,PM2.5(ug/m3),PM10(ug/m3),PARTICLES(per/L),CO2(ppm),'
        'HCHO(mg/m3),TEMPERATURE,HUMIDITY(%),TEMPUNIT\n'
        '2025-07-11 10:08:02,014.7,024.8,2311,487,0.051,020.7,075.3,C\n';

    final result = await CsvImportService(service).importMany([
      (name: 'elm.csv', content: CsvExportService().buildCsv([good])),
      (name: 'raw_device.csv', content: temtopCsv),
    ]);

    expect(result.imported, 1);
    expect(result.failures, hasLength(1));
    expect(result.failures.single, contains('raw_device.csv'));
    expect(result.failures.single, contains('Temtop'));
    expect(await service.getAllMeasurements(), hasLength(1));
  });

  test('raw Temtop device CSV is rejected with a clear message', () async {
    const temtopCsv =
        'DATE,PM2.5(ug/m3),PM10(ug/m3),PARTICLES(per/L),CO2(ppm),'
        'HCHO(mg/m3),TEMPERATURE,HUMIDITY(%),TEMPUNIT\n'
        '2025-07-11 10:08:02,014.7,024.8,2311,487,0.051,020.7,075.3,C\n';
    expect(
      () => CsvImportService(service).importCsvText(temtopCsv),
      throwsA(isA<CsvImportException>().having(
          (e) => e.message, 'message', contains('Temtop'))),
    );
  });

  test('updateMeasurement edits in place', () async {
    final m = fullMeasurement();
    final id = await service.insertMeasurement(m);
    await service
        .updateMeasurement(m.copyWith(id: id, pm25: 99.0, notes: 'edited'));
    final stored = (await service.getAllMeasurements()).single;
    expect(stored.pm25, 99.0);
    expect(stored.notes, 'edited');
    expect(stored.uid, m.uid);
  });
}
