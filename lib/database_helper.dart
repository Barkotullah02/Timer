import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io' show Platform;

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
    // Initialize FFI for desktop platforms (Windows, Linux)
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
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

    await db.execute('''
      CREATE TABLE greetings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 -> v2: add endMessage column to existing timers table
      await db.execute('ALTER TABLE timers ADD COLUMN endMessage TEXT');
    }
    if (oldVersion < 3) {
      // v2 -> v3: add greetings table for the GreetingPage feature
      await db.execute('''
        CREATE TABLE greetings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
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

  // ----- greetings -----

  Future<int> insertGreeting(Map<String, dynamic> greeting) async {
    final db = await database;
    return await db.insert('greetings', greeting);
  }

  Future<List<Map<String, dynamic>>> getAllGreetings() async {
    final db = await database;
    return await db.query('greetings', orderBy: 'id ASC');
  }

  Future<int> deleteGreeting(int id) async {
    final db = await database;
    return await db.delete(
      'greetings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateGreeting(int id, Map<String, dynamic> greeting) async {
    final db = await database;
    return await db.update(
      'greetings',
      greeting,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
