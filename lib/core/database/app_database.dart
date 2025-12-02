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
      onOpen: (db) async {
        // Ensure multi-tenant safety: add user_id columns if missing
        await _ensureColumn(db, 'todos', 'user_id INTEGER');
        await _ensureColumn(db, 'expenses', 'user_id INTEGER');
        await _ensureColumn(db, 'events', 'user_id INTEGER');
        // Budgets table may not exist in older installs
        await _ensureBudgetsTable(db);
        // Ensure new columns for events
        await _ensureColumn(db, 'events', 'recurrence_pattern TEXT');
      },
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
        user_id INTEGER,
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
        user_id INTEGER,
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
        recurrence_pattern TEXT,
        is_recurring INTEGER DEFAULT 0,
        notification_enabled INTEGER DEFAULT 1,
        user_id INTEGER,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // 4. Bảng Budgets (offline cache)
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER,
        client_id TEXT PRIMARY KEY,
        user_id INTEGER,
        category_id INTEGER,
        amount REAL NOT NULL,
        period TEXT,
        start_date TEXT,
        end_date TEXT,
        alert_threshold INTEGER,
        is_active INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<void> _ensureColumn(
      Database db, String table, String columnDef) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final name = columnDef.split(' ').first.trim();
    final exists = info.any((c) => (c['name'] as String?) == name);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef');
    }
  }

  Future<void> _ensureBudgetsTable(Database db) async {
    try {
      // Try simple select to check existence
      await db.rawQuery('SELECT 1 FROM budgets LIMIT 1');
    } catch (_) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER,
          client_id TEXT PRIMARY KEY,
          user_id INTEGER,
          category_id INTEGER,
          amount REAL NOT NULL,
          period TEXT,
          start_date TEXT,
          end_date TEXT,
          alert_threshold INTEGER,
          is_active INTEGER DEFAULT 1,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0,
          version INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
    }
  }
}
