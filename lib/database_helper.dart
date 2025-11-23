import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('timers.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE timers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        hours INTEGER NOT NULL,
        minutes INTEGER NOT NULL,
        seconds INTEGER NOT NULL,
        scheduledTime TEXT,
        isScheduled INTEGER NOT NULL,
        wasScheduledStart INTEGER NOT NULL,
        endMessage TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add endMessage column to existing tables
      await db.execute('ALTER TABLE timers ADD COLUMN endMessage TEXT');
    }
  }

  Future<int> insertTimer(Map<String, dynamic> timer) async {
    final db = await database;
    return await db.insert('timers', timer);
  }

  Future<List<Map<String, dynamic>>> getAllTimers() async {
    final db = await database;
    return await db.query('timers', orderBy: 'id ASC');
  }

  Future<int> deleteTimer(int id) async {
    final db = await database;
    return await db.delete(
      'timers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateTimer(int id, Map<String, dynamic> timer) async {
    final db = await database;
    return await db.update(
      'timers',
      timer,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}

