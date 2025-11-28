
import 'dart:async';
import '../../core/database/app_database.dart';
import '../../core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncService {
  final AppDatabase _database;
  final ApiClient _apiClient;
  final SharedPreferences _prefs;
  
  Timer? _syncTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isSyncing = false;
  
  SyncService(this._database, this._apiClient, this._prefs) {
    _initConnectivityListener();
    _startPeriodicSync();
  }
  
  // Initialize connectivity listener(Check network status automatically
  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        // Network is back, trigger sync
        syncAll();
      }
    });
  }
  
  // Start periodic sync every 5 minutes when online
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(AppConstants.syncInterval, (timer) {
      syncAll();
    });
  }
  
  // Main sync function - syncs all data types
  Future<bool> syncAll() async {
    if (_isSyncing) return false;
    
    try {
      _isSyncing = true;
      
      // Check network connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('📴 No internet connection, skipping sync');
        return false;
      }
      
      print('🔄 Starting sync...');
      
      // Sync todos
      await _syncTodos();
      
      // Sync expenses
      await _syncExpenses();
      
      // Sync events
      await _syncEvents();
      
      // Update last sync time
      await _prefs.setString(
        AppConstants.lastSyncKey,
        DateTime.now().toIso8601String(),
      );
      
      print('✅ Sync completed successfully');
      return true;
    } catch (e) {
      print('❌ Sync error: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }
  
  // Sync todos
  Future<void> _syncTodos() async {
    try {
      final db = await _database.database;
      
      // Get unsync todos from local database
      final unsynced = await db.query(
        'todos',
        where: 'is_synced = ? AND is_deleted = ?',
        whereArgs: [0, 0],
      );
      
      // Upload unsynced todos to server
      for (var todo in unsynced) {
        try {
          if (todo['id'] == null || todo['id'] == 0) {
            // Create new todo on server
            final response = await _apiClient.post(
              AppConstants.todosEndpoint,
              data: {
                'title': todo['title'],
                'description': todo['description'],
                'is_completed': todo['is_completed'] == 1,
                'category_id': todo['category_id'],
                'priority': todo['priority'],
                'tags': (todo['tags'] as String).split(',').where((t) => t.isNotEmpty).toList(),
                'due_date': todo['due_date'],
                'reminder_time': todo['reminder_time'],
                'client_id': todo['client_id'],
              },
            );
            
            if (response.data['success']) {
              // Update local record with server ID
              await db.update(
                'todos',
                {
                  'id': response.data['data']['id'],
                  'is_synced': 1,
                  'version': response.data['data']['version'],
                },
                where: 'client_id = ?',
                whereArgs: [todo['client_id']],
              );
            }
          } else {
            // Update existing todo on server
            final response = await _apiClient.put(
              '${AppConstants.todosEndpoint}/${todo['id']}',
              data: {
                'title': todo['title'],
                'description': todo['description'],
                'is_completed': todo['is_completed'] == 1,
                'category_id': todo['category_id'],
                'priority': todo['priority'],
                'tags': (todo['tags'] as String).split(',').where((t) => t.isNotEmpty).toList(),
                'due_date': todo['due_date'],
                'reminder_time': todo['reminder_time'],
              },
            );
            
            if (response.data['success']) {
              await db.update(
                'todos',
                {'is_synced': 1, 'version': response.data['data']['version']},
                where: 'id = ?',
                whereArgs: [todo['id']],
              );
            }
          }
        } catch (e) {
          print('Error syncing todo ${todo['client_id']}: $e');
        }
      }
      
      // Get server changes
      final lastSync = _prefs.getString(AppConstants.lastSyncKey) ?? '1970-01-01T00:00:00Z';
      final response = await _apiClient.post(
        '${AppConstants.todosEndpoint}/sync',
        data: {
          'todos': [],
          'lastSyncTime': lastSync,
        },
      );
      
      if (response.data['success']) {
        // Apply server changes to local database
        final serverChanges = response.data['data']['serverChanges'] as List;
        for (var serverTodo in serverChanges) {
          await db.insert(
            'todos',
            {
              'id': serverTodo['id'],
              'client_id': serverTodo['client_id'],
              'title': serverTodo['title'],
              'description': serverTodo['description'],
              'is_completed': serverTodo['is_completed'] ? 1 : 0,
              'category_id': serverTodo['category_id'],
              'priority': serverTodo['priority'],
              'tags': (serverTodo['tags'] as List).join(','),
              'due_date': serverTodo['due_date'],
              'reminder_time': serverTodo['reminder_time'],
              'position': serverTodo['position'] ?? 0,
              'created_at': serverTodo['created_at'],
              'updated_at': serverTodo['updated_at'],
              'is_deleted': serverTodo['is_deleted'] ? 1 : 0,
              'is_synced': 1,
              'version': serverTodo['version'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      
      print('✅ Todos synced');
    } catch (e) {
      print('❌ Todos sync error: $e');
    }
  }
  
  // Sync expenses
  Future<void> _syncExpenses() async {
    try {
      final db = await _database.database;
      
      final unsynced = await db.query(
        'expenses',
        where: 'is_synced = ? AND is_deleted = ?',
        whereArgs: [0, 0],
      );
      
      for (var expense in unsynced) {
        try {
          if (expense['id'] == null || expense['id'] == 0) {
            final response = await _apiClient.post(
              AppConstants.expensesEndpoint,
              data: {
                'amount': expense['amount'],
                'type': expense['type'],
                'category_id': expense['category_id'],
                'description': expense['description'],
                'date': expense['date'],
                'payment_method': expense['payment_method'],
                'client_id': expense['client_id'],
              },
            );
            
            if (response.data['success']) {
              await db.update(
                'expenses',
                {
                  'id': response.data['data']['id'],
                  'is_synced': 1,
                  'version': response.data['data']['version'],
                },
                where: 'client_id = ?',
                whereArgs: [expense['client_id']],
              );
            }
          } else {
            final response = await _apiClient.put(
              '${AppConstants.expensesEndpoint}/${expense['id']}',
              data: {
                'amount': expense['amount'],
                'type': expense['type'],
                'category_id': expense['category_id'],
                'description': expense['description'],
                'date': expense['date'],
                'payment_method': expense['payment_method'],
              },
            );
            
            if (response.data['success']) {
              await db.update(
                'expenses',
                {'is_synced': 1},
                where: 'id = ?',
                whereArgs: [expense['id']],
              );
            }
          }
        } catch (e) {
          print('Error syncing expense: $e');
        }
      }
      
      print('✅ Expenses synced');
    } catch (e) {
      print('❌ Expenses sync error: $e');
    }
  }
  
  // Sync events
  Future<void> _syncEvents() async {
    try {
      final db = await _database.database;
      
      final unsynced = await db.query(
        'events',
        where: 'is_synced = ? AND is_deleted = ?',
        whereArgs: [0, 0],
      );
      
      for (var event in unsynced) {
        try {
          if (event['id'] == null || event['id'] == 0) {
            final response = await _apiClient.post(
              AppConstants.eventsEndpoint,
              data: {
                'title': event['title'],
                'description': event['description'],
                'event_date': event['event_date'],
                'event_type': event['event_type'],
                'color': event['color'],
                'icon': event['icon'],
                'is_recurring': event['is_recurring'] == 1,
                'recurrence_pattern': event['recurrence_pattern'],
                'notification_enabled': event['notification_enabled'] == 1,
                'client_id': event['client_id'],
              },
            );
            
            if (response.data['success']) {
              await db.update(
                'events',
                {
                  'id': response.data['data']['id'],
                  'is_synced': 1,
                  'version': response.data['data']['version'],
                },
                where: 'client_id = ?',
                whereArgs: [event['client_id']],
              );
            }
          } else {
            final response = await _apiClient.put(
              '${AppConstants.eventsEndpoint}/${event['id']}',
              data: {
                'title': event['title'],
                'description': event['description'],
                'event_date': event['event_date'],
                'event_type': event['event_type'],
                'color': event['color'],
                'icon': event['icon'],
                'is_recurring': event['is_recurring'] == 1,
                'recurrence_pattern': event['recurrence_pattern'],
                'notification_enabled': event['notification_enabled'] == 1,
              },
            );
            
            if (response.data['success']) {
              await db.update(
                'events',
                {'is_synced': 1},
                where: 'id = ?',
                whereArgs: [event['id']],
              );
            }
          }
        } catch (e) {
          print('Error syncing event: $e');
        }
      }
      
      print('✅ Events synced');
    } catch (e) {
      print('❌ Events sync error: $e');
    }
  }
  
  // Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
