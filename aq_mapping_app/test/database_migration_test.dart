import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aq_mapping_app/services/database_service.dart';

const createV1 = '''
  CREATE TABLE measurements(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    pm25 REAL,
    pm10 REAL,
    co2 REAL,
    hcho REAL,
    temperature REAL,
    humidity REAL,
    notes TEXT
  )
''';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  test('v1 → v2 migration preserves data and backfills uid', () async {
    final db = await factory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await db.execute(createV1);
    await db.insert('measurements', {
      'timestamp': '2026-03-11T14:30:00.000',
      'latitude': 43.7841,
      'longitude': -79.1873,
      'pm25': 14.7,
      'co2': 425.0,
      'notes': 'pre-upgrade row',
    });

    await DatabaseService.onUpgradeDb(db, 1, 2);

    final rows = await db.query('measurements');
    expect(rows, hasLength(1));
    final row = rows.first;
    expect(row['pm25'], 14.7);
    expect(row['notes'], 'pre-upgrade row');
    expect(row['uid'], 'legacy-1-2026-03-11T14:30:00.000');
    expect(row['temp_unit'], 'C');
    expect(row['source'], 'local');
    expect(row['is_indoor'], isNull);

    // New columns accept writes.
    await db.insert('measurements', {
      'uid': 'UTSC-AQMS-01-1-aaaa',
      'timestamp': '2026-06-12T10:00:00.000',
      'latitude': 43.78,
      'longitude': -79.18,
      'particles': 2311.0,
      'pm25_var': 1.2,
      'group_name': 'Maple',
      'device_id': 'UTSC-AQMS-01',
      'is_indoor': 1,
    });
    expect(await db.query('measurements'), hasLength(2));
    await db.close();
  });

  test('fresh v2 schema and migrated v1 schema have identical columns',
      () async {
    final fresh = await factory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await DatabaseService.onCreateDb(fresh, 2);
    final migrated = await factory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await migrated.execute(createV1);
    await DatabaseService.onUpgradeDb(migrated, 1, 2);

    Future<Set<String>> columns(Database db) async =>
        (await db.rawQuery('PRAGMA table_info(measurements)'))
            .map((r) => r['name'] as String)
            .toSet();

    expect(await columns(migrated), await columns(fresh));
    await fresh.close();
    await migrated.close();
  });

  test('unique index rejects duplicate uids', () async {
    final db = await factory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await DatabaseService.onCreateDb(db, 2);

    final row = {
      'uid': 'dup-uid',
      'timestamp': '2026-06-12T10:00:00.000',
      'latitude': 43.78,
      'longitude': -79.18,
    };
    await db.insert('measurements', row);
    expect(() => db.insert('measurements', Map.of(row)),
        throwsA(isA<DatabaseException>()));
    await db.close();
  });
}
