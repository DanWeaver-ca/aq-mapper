import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/measurement.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'aq_measurements.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
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
        ''');
      },
    );
  }

  Future<int> insertMeasurement(Measurement measurement) async {
    final db = await database;
    return await db.insert('measurements', measurement.toMap());
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

  Future<int> deleteAllMeasurements() async {
    final db = await database;
    return await db.delete('measurements');
  }
}
