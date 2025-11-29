import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  factory AppDatabase() => _instance;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Bảng Todos
    await db.execute('''
      CREATE TABLE todos (
        id INTEGER, 
        client_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        is_completed INTEGER DEFAULT 0,
        category_id INTEGER,
        priority TEXT,
        tags TEXT, -- Lưu mảng dưới dạng chuỗi "tag1,tag2"
        due_date TEXT,
        reminder_time TEXT,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // 2. Bảng Expenses
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER,
        client_id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id INTEGER,
        description TEXT,
        date TEXT,
        payment_method TEXT,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // 3. Bảng Events
    await db.execute('''
      CREATE TABLE events (
        id INTEGER,
        client_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        event_date TEXT,
        event_type TEXT,
        color TEXT,
        is_recurring INTEGER DEFAULT 0,
        notification_enabled INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }
}