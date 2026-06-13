import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/measurement.dart';

class ImportCounts {
  final int inserted;
  final int skipped;
  const ImportCounts({required this.inserted, required this.skipped});
}

class DatabaseService {
  static Database? _database;

  /// Test hook: inject an already-open database (e.g. in-memory ffi).
  @visibleForTesting
  static set testDatabase(Database? db) => _database = db;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // On web the FFI backend keys storage by the database name (IndexedDB);
    // there is no filesystem path to join.
    final path = kIsWeb
        ? 'aq_measurements.db'
        : join(await getDatabasesPath(), 'aq_measurements.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: onCreateDb,
      onUpgrade: onUpgradeDb,
    );
  }

  /// Public static so migration tests can run the real schema SQL against an
  /// in-memory ffi database.
  static Future<void> onCreateDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE measurements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        pm25 REAL,
        pm25_var REAL,
        pm10 REAL,
        pm10_var REAL,
        particles REAL,
        co2 REAL,
        co2_var REAL,
        hcho REAL,
        hcho_var REAL,
        temperature REAL,
        temperature_var REAL,
        temp_unit TEXT NOT NULL DEFAULT 'C',
        humidity REAL,
        humidity_var REAL,
        group_name TEXT,
        device_id TEXT,
        is_indoor INTEGER,
        source TEXT NOT NULL DEFAULT 'local',
        notes TEXT
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_measurements_uid ON measurements(uid)');
  }

  static Future<void> onUpgradeDb(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // SQLite's ALTER TABLE cannot add UNIQUE columns, so uid is added
      // nullable, backfilled, then indexed.
      const newColumns = [
        'uid TEXT',
        'pm25_var REAL',
        'pm10_var REAL',
        'particles REAL',
        'co2_var REAL',
        'hcho_var REAL',
        'temperature_var REAL',
        "temp_unit TEXT NOT NULL DEFAULT 'C'",
        'humidity_var REAL',
        'group_name TEXT',
        'device_id TEXT',
        'is_indoor INTEGER',
        "source TEXT NOT NULL DEFAULT 'local'",
      ];
      for (final column in newColumns) {
        await db.execute('ALTER TABLE measurements ADD COLUMN $column');
      }
      await db.execute(
          "UPDATE measurements SET uid = 'legacy-' || id || '-' || timestamp "
          'WHERE uid IS NULL');
      await db.execute(
          'CREATE UNIQUE INDEX idx_measurements_uid ON measurements(uid)');
    }
  }

  Future<int> insertMeasurement(Measurement measurement) async {
    final db = await database;
    return await db.insert('measurements', measurement.toMap());
  }

  Future<int> updateMeasurement(Measurement measurement) async {
    final db = await database;
    return await db.update(
      'measurements',
      measurement.toMap(),
      where: 'id = ?',
      whereArgs: [measurement.id],
    );
  }

  /// Inserts only measurements whose uid is not already in the database.
  Future<ImportCounts> insertIfNew(List<Measurement> measurements) async {
    final db = await database;
    final existing = (await db.query('measurements', columns: ['uid']))
        .map((row) => row['uid'] as String)
        .toSet();
    final fresh = <Measurement>[];
    final seenInBatch = <String>{};
    for (final m in measurements) {
      if (!existing.contains(m.uid) && seenInBatch.add(m.uid)) {
        fresh.add(m);
      }
    }
    final batch = db.batch();
    for (final m in fresh) {
      // Drop any incoming row id — this database assigns its own.
      batch.insert('measurements', m.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
    return ImportCounts(
      inserted: fresh.length,
      skipped: measurements.length - fresh.length,
    );
  }

  Future<List<Measurement>> getAllMeasurements() async {
    final db = await database;
    final maps = await db.query('measurements', orderBy: 'timestamp DESC');
    return maps.map((map) => Measurement.fromMap(map)).toList();
  }

  Future<int> deleteMeasurement(int id) async {
    final db = await database;
    return await db.delete('measurements', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteImported() async {
    final db = await database;
    return await db
        .delete('measurements', where: 'source = ?', whereArgs: ['imported']);
  }

  Future<int> deleteAllMeasurements() async {
    final db = await database;
    return await db.delete('measurements');
  }

  /// Returns counts keyed by source ('local' / 'imported').
  Future<Map<String, int>> countBySource() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT source, COUNT(*) AS n FROM measurements GROUP BY source');
    return {
      for (final row in rows) row['source'] as String: row['n'] as int,
    };
  }
}
