import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../database/app_database.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();

  // Dùng late để khởi tạo sau
  late final ApiClient _apiClient;
  late final SharedPreferences _prefs;
  bool _isInitialized = false;

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  // Hàm khởi tạo bắt buộc gọi ở main.dart
  void initialize(SharedPreferences prefs) {
    if (_isInitialized) return;
    _prefs = prefs;
    _apiClient = ApiClient(prefs); // [QUAN TRỌNG] Truyền prefs vào đây
    _isInitialized = true;
  }

  Timer? _syncTimer;
  bool _isSyncing = false;
  StreamSubscription? _connectivitySubscription;

  void startSyncService() {
    if (!_isInitialized) {
      print("⚠️ SyncService chưa được khởi tạo! Gọi initialize() trước.");
      return;
    }

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncAll();
      }
    });

    _syncTimer = Timer.periodic(AppConstants.syncInterval, (_) => syncAll());
  }

  Future<void> syncAll() async {
    if (_isSyncing || !_isInitialized) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    _isSyncing = true;
    print('🔄 Bắt đầu đồng bộ...');

    try {
      final db = await AppDatabase().database;
      await _syncTodos(db);
      await _syncExpenses(db);
      await _syncEvents(db);
      await _syncBudgets(db);

      await _prefs.setString(
          AppConstants.lastSyncKey, DateTime.now().toIso8601String());
      print('✅ Đồng bộ hoàn tất!');
    } catch (e) {
      print('❌ Lỗi đồng bộ: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // --- 1. SYNC TODOS ---
  Future<void> _syncTodos(Database db) async {
    try {
      final unsynced = await db.query('todos', where: 'is_synced = 0');
      for (var todo in unsynced) {
        final isNew = todo['id'] == null;
        final tagsString = todo['tags'] as String?;
        final List<String> tagsList =
            (tagsString != null && tagsString.isNotEmpty)
                ? tagsString.split(',')
                : [];

        final data = {
          'title': todo['title'],
          'description': todo['description'],
          'is_completed': (todo['is_completed'] as int) == 1,
          'category_id': todo['category_id'],
          'priority': todo['priority'],
          'tags': tagsList,
          'due_date': todo['due_date'],
          'reminder_time': todo['reminder_time'],
          'client_id': todo['client_id'],
        };

        if (isNew) {
          final res =
              await _apiClient.post(AppConstants.todosEndpoint, data: data);
          if (res.data['success']) {
            await db.update(
                'todos',
                {
                  'id': res.data['data']['id'],
                  'is_synced': 1,
                  'version': res.data['data']['version']
                },
                where: 'client_id = ?',
                whereArgs: [todo['client_id']]);
          }
        } else {
          final res = await _apiClient
              .put('${AppConstants.todosEndpoint}/${todo['id']}', data: data);
          if (res.data['success']) {
            await db.update('todos',
                {'is_synced': 1, 'version': res.data['data']['version']},
                where: 'id = ?', whereArgs: [todo['id']]);
          }
        }
      }

      final lastSync = _prefs.getString(AppConstants.lastSyncKey);
      final res = await _apiClient.post('${AppConstants.todosEndpoint}/sync',
          data: {'todos': [], 'lastSyncTime': lastSync});

      if (res.data['success']) {
        final changes = res.data['data']['serverChanges'] as List;
        for (var item in changes) {
          final tagsStr = (item['tags'] as List?)?.join(',') ?? "";
          await db.insert(
              'todos',
              {
                ...item,
                'is_completed': item['is_completed'] == true ? 1 : 0,
                'is_deleted': item['is_deleted'] == true ? 1 : 0,
                'tags': tagsStr,
                'is_synced': 1,
                'client_id': item['client_id'] ?? item['id'].toString()
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      print('Sync Todos Error: $e');
    }
  }

  // --- 2. SYNC EXPENSES ---
  Future<void> _syncExpenses(Database db) async {
    try {
      final unsynced = await db.query('expenses', where: 'is_synced = 0');
      for (var ex in unsynced) {
        final isNew = ex['id'] == null;
        final data = {
          'amount': ex['amount'],
          'type': ex['type'],
          'category_id': ex['category_id'],
          'description': ex['description'],
          'date': ex['date'],
          'payment_method': ex['payment_method'],
          'client_id': ex['client_id'],
        };

        if (isNew) {
          final res =
              await _apiClient.post(AppConstants.expensesEndpoint, data: data);
          if (res.data['success']) {
            await db.update(
                'expenses',
                {
                  'id': res.data['data']['id'],
                  'is_synced': 1,
                  'version': res.data['data']['version']
                },
                where: 'client_id = ?',
                whereArgs: [ex['client_id']]);
          }
        } else {
          final res = await _apiClient
              .put('${AppConstants.expensesEndpoint}/${ex['id']}', data: data);
          if (res.data['success']) {
            await db.update('expenses', {'is_synced': 1},
                where: 'id = ?', whereArgs: [ex['id']]);
          }
        }
      }

      final lastSync = _prefs.getString(AppConstants.lastSyncKey);
      final res = await _apiClient.post('${AppConstants.expensesEndpoint}/sync',
          data: {'expenses': [], 'lastSyncTime': lastSync});

      if (res.data['success']) {
        final changes = res.data['data']['serverChanges'] as List;
        for (var item in changes) {
          await db.insert(
              'expenses',
              {
                ...item,
                'is_deleted': item['is_deleted'] == true ? 1 : 0,
                'is_synced': 1,
                'client_id': item['client_id'] ?? item['id'].toString()
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      print('Sync Expenses Error: $e');
    }
  }

  // --- 3. SYNC EVENTS ---
  Future<void> _syncEvents(Database db) async {
    try {
      final unsynced = await db.query('events', where: 'is_synced = 0');
      for (var ev in unsynced) {
        final isNew = ev['id'] == null;
        final data = {
          'title': ev['title'],
          'description': ev['description'],
          'event_date': ev['event_date'],
          'event_type': ev['event_type'],
          'color': ev['color'],
          'is_recurring': (ev['is_recurring'] as int) == 1,
          'notification_enabled': (ev['notification_enabled'] as int) == 1,
          'client_id': ev['client_id'],
        };

        if (isNew) {
          final res =
              await _apiClient.post(AppConstants.eventsEndpoint, data: data);
          if (res.data['success']) {
            await db.update(
                'events',
                {
                  'id': res.data['data']['id'],
                  'is_synced': 1,
                  'version': res.data['data']['version']
                },
                where: 'client_id = ?',
                whereArgs: [ev['client_id']]);
          }
        } else {
          final res = await _apiClient
              .put('${AppConstants.eventsEndpoint}/${ev['id']}', data: data);
          if (res.data['success']) {
            await db.update('events', {'is_synced': 1},
                where: 'id = ?', whereArgs: [ev['id']]);
          }
        }
      }

      final lastSync = _prefs.getString(AppConstants.lastSyncKey);
      final res = await _apiClient.post('${AppConstants.eventsEndpoint}/sync',
          data: {'events': [], 'lastSyncTime': lastSync});

      if (res.data['success']) {
        final changes = res.data['data']['serverChanges'] as List;
        for (var item in changes) {
          await db.insert(
              'events',
              {
                ...item,
                'is_recurring': item['is_recurring'] == true ? 1 : 0,
                'notification_enabled':
                    item['notification_enabled'] == true ? 1 : 0,
                'is_deleted': item['is_deleted'] == true ? 1 : 0,
                'is_synced': 1,
                'client_id': item['client_id'] ?? item['id'].toString()
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      print('Sync Events Error: $e');
    }
  }

  // --- 4. SYNC BUDGETS ---
  Future<void> _syncBudgets(Database db) async {
    try {
      final unsynced = await db.query('budgets', where: 'is_synced = 0');
      for (var b in unsynced) {
        final isNew = b['id'] == null;
        final data = {
          'category_id': b['category_id'],
          'amount': b['amount'],
          'period': b['period'],
          'start_date': b['start_date'],
          'end_date': b['end_date'],
          'alert_threshold': b['alert_threshold'],
          'is_active': (b['is_active'] as int? ?? 1) == 1,
          'client_id': b['client_id'],
        };

        if (isNew) {
          final res =
              await _apiClient.post(AppConstants.budgetsEndpoint, data: data);
          if (res.data['success']) {
            await db.update(
              'budgets',
              {
                'id': res.data['data']['id'],
                'is_synced': 1,
                'version': res.data['data']['version'] ?? 1,
                'updated_at': res.data['data']['updated_at'] ??
                    DateTime.now().toIso8601String(),
              },
              where: 'client_id = ?',
              whereArgs: [b['client_id']],
            );
          }
        } else {
          final res = await _apiClient
              .put('${AppConstants.budgetsEndpoint}/${b['id']}', data: data);
          if (res.data['success']) {
            await db.update(
              'budgets',
              {
                'is_synced': 1,
                'version': res.data['data']['version'] ?? 1,
                'updated_at': res.data['data']['updated_at'] ??
                    DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [b['id']],
            );
          }
        }
      }

      // Pull server changes (if a sync endpoint exists in future)
      // For now, rely on regular GET endpoints in UI.
    } catch (e) {
      print('Sync Budgets Error: $e');
    }
  }
}
