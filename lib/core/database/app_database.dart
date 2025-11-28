import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';

class AppDatabase {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);
    
    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // Todos table
    await db.execute('''
      CREATE TABLE todos (
        id INTEGER PRIMARY KEY,
        client_id TEXT UNIQUE,
        title TEXT NOT NULL,
        description TEXT,
        is_completed INTEGER DEFAULT 0,
        category_id INTEGER,
        priority TEXT DEFAULT 'medium',
        tags TEXT,
        due_date TEXT,
        reminder_time TEXT,
        position INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1
      )
    ''');
    
    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY,
        client_id TEXT UNIQUE,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id INTEGER,
        description TEXT,
        date TEXT NOT NULL,
        payment_method TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1
      )
    ''');
    
    // Events table
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY,
        client_id TEXT UNIQUE,
        title TEXT NOT NULL,
        description TEXT,
        event_date TEXT NOT NULL,
        event_type TEXT,
        color TEXT DEFAULT '#e74c3c',
        icon TEXT DEFAULT 'event',
        is_recurring INTEGER DEFAULT 0,
        recurrence_pattern TEXT,
        notification_enabled INTEGER DEFAULT 1,
        notification_times TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1
      )
    ''');
    
    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT DEFAULT '#3498db',
        icon TEXT DEFAULT 'category',
        type TEXT DEFAULT 'both',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Budgets table
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY,
        category_id INTEGER,
        amount REAL NOT NULL,
        period TEXT DEFAULT 'monthly',
        start_date TEXT NOT NULL,
        end_date TEXT,
        alert_threshold INTEGER DEFAULT 80,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Create indexes
    await db.execute('CREATE INDEX idx_todos_completed ON todos(is_completed)');
    await db.execute('CREATE INDEX idx_todos_synced ON todos(is_synced)');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_expenses_synced ON expenses(is_synced)');
    await db.execute('CREATE INDEX idx_events_date ON events(event_date)');
    await db.execute('CREATE INDEX idx_events_synced ON events(is_synced)');
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
  }
  
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('todos');
    await db.delete('expenses');
    await db.delete('events');
    await db.delete('categories');
    await db.delete('budgets');
  }
}
