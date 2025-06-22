import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseServices {
  static final DatabaseServices instance = DatabaseServices._init();
  static Database? _database;
  DatabaseServices._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('locations.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL,
            longitude REAL,
            accuracy REAL,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertLocation(Map<String, dynamic> location) async {
    final db = await database;
    await db.insert('locations', {
      'latitude': location['latitude'],
      'longitude': location['longitude'],
      'accuracy': location['accuracy'],
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllLocations() async {
    final db = await database;
    return await db.query('locations', orderBy: 'timestamp DESC');
  }


  Future<void> clearLocations() async {
    final db = await database;
    await db.delete('locations');
  }
}