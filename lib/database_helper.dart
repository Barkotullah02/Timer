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
      version: 1,
      onCreate: _createDB,
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
        wasScheduledStart INTEGER NOT NULL
      )
    ''');
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

