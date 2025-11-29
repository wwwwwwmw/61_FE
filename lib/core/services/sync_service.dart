import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../database/app_database.dart';

class SyncService {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;
  
  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  
  factory SyncService({ApiClient? apiClient, SharedPreferences? prefs}) {
    if (apiClient != null) _instance._apiClientInternal = apiClient;
    if (prefs != null) _instance._prefsInternal = prefs;
    return _instance;
  }
  
  ApiClient? _apiClientInternal;
  SharedPreferences? _prefsInternal;
  
  // Getters để đảm bảo không null khi dùng singleton
  ApiClient get client => _apiClientInternal ?? ApiClient();
  SharedPreferences get prefs => _prefsInternal!; // Cần đảm bảo prefs đã init ở main

  SyncService._internal() : _apiClient = ApiClient(), _prefs =  throw UnimplementedError("Init via factory first"); 
  // Lưu ý: Trong thực tế, bạn nên khởi tạo SyncService ở main hoặc dùng GetIt để inject dependency.
  // Để đơn giản cho code này, ta giả định ApiClient và SharedPreferences được truyền vào.

  Timer? _syncTimer;
  bool _isSyncing = false;

  // Hàm khởi động service (gọi ở main hoặc home)
  void startSyncService() {
    // 1. Lắng nghe sự kiện có mạng
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        print("📶 Có mạng trở lại - Kích hoạt Sync");
        syncAll();
      }
    });

    // 2. Chạy định kỳ (ví dụ 5 phút 1 lần)
    _syncTimer = Timer.periodic(AppConstants.syncInterval, (_) {
      syncAll();
    });
  }

  void stopSyncService() {
    _syncTimer?.cancel();
  }

  // --- MAIN SYNC FUNCTION ---
  Future<void> syncAll() async {
    if (_isSyncing) return;

    // Kiểm tra mạng trước khi chạy
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print("📴 Không có mạng - Bỏ qua Sync");
      return;
    }

    _isSyncing = true;
    print("🔄 Bắt đầu đồng bộ dữ liệu...");

    try {
      // Init Database nếu chưa có
      final db = await AppDatabase().database;

      // 1. Sync từng phần
      await _syncTodos(db);
      await _syncExpenses(db);
      await _syncEvents(db);

      // 2. Cập nhật thời gian sync cuối cùng
      if (_prefsInternal != null) {
        await _prefsInternal!.setString(AppConstants.lastSyncKey, DateTime.now().toIso8601String());
      }
      
      print("✅ Đồng bộ hoàn tất thành công!");
    } catch (e) {
      print("❌ Lỗi trong quá trình đồng bộ: $e");
    } finally {
      _isSyncing = false;
    }
  }

  // --- 1. SYNC TODOS ---
  Future<void> _syncTodos(Database db) async {
    try {
      // A. ĐẨY LÊN SERVER (PUSH)
      // Lấy các todo chưa sync (is_synced = 0)
      final unsynced = await db.query('todos', where: 'is_synced = 0');
      
      for (var todo in unsynced) {
        final isNew = todo['id'] == null; // Chưa có ID server => Tạo mới
        
        // Chuẩn bị data (Convert tags từ chuỗi sang mảng cho server)
        final tagsString = todo['tags'] as String?;
        final List<String> tagsList = tagsString != null && tagsString.isNotEmpty 
            ? tagsString.split(',') 
            : [];

        final data = {
          'title': todo['title'],
          'description': todo['description'],
          'is_completed': todo['is_completed'] == 1,
          'category_id': todo['category_id'],
          'priority': todo['priority'],
          'tags': tagsList,
          'due_date': todo['due_date'],
          'reminder_time': todo['reminder_time'],
          'client_id': todo['client_id'], // Quan trọng để map lại
        };

        if (isNew) {
          // POST
          final res = await client.post(AppConstants.todosEndpoint, data: data);
          if (res.data['success']) {
            // Cập nhật lại ID server và đánh dấu đã sync
            await db.update('todos', {
              'id': res.data['data']['id'],
              'is_synced': 1,
              'version': res.data['data']['version']
            }, where: 'client_id = ?', whereArgs: [todo['client_id']]);
          }
        } else {
          // PUT (Update)
          final res = await client.put('${AppConstants.todosEndpoint}/${todo['id']}', data: data);
          if (res.data['success']) {
            await db.update('todos', {
              'is_synced': 1,
              'version': res.data['data']['version']
            }, where: 'id = ?', whereArgs: [todo['id']]);
          }
        }
      }

      // B. KÉO VỀ MÁY (PULL)
      // Gọi API sync của server để lấy các thay đổi mới nhất
      final lastSyncTime = _prefsInternal?.getString(AppConstants.lastSyncKey) ?? "1970-01-01T00:00:00Z";
      
      final syncRes = await client.post('${AppConstants.todosEndpoint}/sync', data: {
        'todos': [], // Có thể gửi list conflict nếu cần
        'lastSyncTime': lastSyncTime
      });

      if (syncRes.data['success']) {
        final serverChanges = syncRes.data['data']['serverChanges'] as List;
        
        for (var serverTodo in serverChanges) {
          // Insert hoặc Replace vào local DB
          await db.insert('todos', {
            'id': serverTodo['id'],
            'client_id': serverTodo['client_id'] ?? serverTodo['id'].toString(), // Fallback
            'title': serverTodo['title'],
            'description': serverTodo['description'],
            'is_completed': serverTodo['is_completed'] == true ? 1 : 0,
            'category_id': serverTodo['category_id'],
            'priority': serverTodo['priority'],
            'tags': (serverTodo['tags'] as List?)?.join(',') ?? "", // Server trả về mảng -> lưu chuỗi
            'due_date': serverTodo['due_date'],
            'reminder_time': serverTodo['reminder_time'],
            'is_deleted': serverTodo['is_deleted'] == true ? 1 : 0,
            'is_synced': 1, // Dữ liệu từ server về mặc định là đã sync
            'version': serverTodo['version'] ?? 1,
            'updated_at': serverTodo['updated_at']
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

    } catch (e) {
      print("Error syncing todos: $e");
    }
  }

  // --- 2. SYNC EXPENSES ---
  Future<void> _syncExpenses(Database db) async {
    try {
      // A. PUSH
      final unsynced = await db.query('expenses', where: 'is_synced = 0');
      
      for (var expense in unsynced) {
        final isNew = expense['id'] == null;
        final data = {
          'amount': expense['amount'],
          'type': expense['type'],
          'category_id': expense['category_id'],
          'description': expense['description'],
          'date': expense['date'],
          'payment_method': expense['payment_method'],
          'client_id': expense['client_id']
        };

        if (isNew) {
          final res = await client.post(AppConstants.expensesEndpoint, data: data);
          if (res.data['success']) {
            await db.update('expenses', {
              'id': res.data['data']['id'],
              'is_synced': 1,
              'version': res.data['data']['version']
            }, where: 'client_id = ?', whereArgs: [expense['client_id']]);
          }
        } else {
          final res = await client.put('${AppConstants.expensesEndpoint}/${expense['id']}', data: data);
          if (res.data['success']) {
            await db.update('expenses', {'is_synced': 1}, where: 'id = ?', whereArgs: [expense['id']]);
          }
        }
      }

      // B. PULL
      final lastSyncTime = _prefsInternal?.getString(AppConstants.lastSyncKey) ?? "1970-01-01T00:00:00Z";
      final syncRes = await client.post('${AppConstants.expensesEndpoint}/sync', data: {
        'expenses': [],
        'lastSyncTime': lastSyncTime
      });

      if (syncRes.data['success']) {
        final serverChanges = syncRes.data['data']['serverChanges'] as List;
        for (var item in serverChanges) {
          await db.insert('expenses', {
            'id': item['id'],
            'client_id': item['client_id'] ?? item['id'].toString(),
            'amount': item['amount'],
            'type': item['type'],
            'category_id': item['category_id'],
            'description': item['description'],
            'date': item['date'],
            'payment_method': item['payment_method'],
            'is_deleted': item['is_deleted'] == true ? 1 : 0,
            'is_synced': 1,
            'version': item['version'] ?? 1,
            'updated_at': item['updated_at']
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      print("Error syncing expenses: $e");
    }
  }

  // --- 3. SYNC EVENTS ---
  Future<void> _syncEvents(Database db) async {
    try {
      // A. PUSH
      final unsynced = await db.query('events', where: 'is_synced = 0');
      
      for (var event in unsynced) {
        final isNew = event['id'] == null;
        final data = {
          'title': event['title'],
          'description': event['description'],
          'event_date': event['event_date'],
          'event_type': event['event_type'],
          'color': event['color'],
          'is_recurring': event['is_recurring'] == 1,
          'notification_enabled': event['notification_enabled'] == 1,
          'client_id': event['client_id']
        };

        if (isNew) {
          final res = await client.post(AppConstants.eventsEndpoint, data: data);
          if (res.data['success']) {
            await db.update('events', {
              'id': res.data['data']['id'],
              'is_synced': 1,
              'version': res.data['data']['version']
            }, where: 'client_id = ?', whereArgs: [event['client_id']]);
          }
        } else {
          final res = await client.put('${AppConstants.eventsEndpoint}/${event['id']}', data: data);
          if (res.data['success']) {
            await db.update('events', {'is_synced': 1}, where: 'id = ?', whereArgs: [event['id']]);
          }
        }
      }

      // B. PULL
      final lastSyncTime = _prefsInternal?.getString(AppConstants.lastSyncKey) ?? "1970-01-01T00:00:00Z";
      final syncRes = await client.post('${AppConstants.eventsEndpoint}/sync', data: {
        'events': [],
        'lastSyncTime': lastSyncTime
      });

      if (syncRes.data['success']) {
        final serverChanges = syncRes.data['data']['serverChanges'] as List;
        for (var item in serverChanges) {
          await db.insert('events', {
            'id': item['id'],
            'client_id': item['client_id'] ?? item['id'].toString(),
            'title': item['title'],
            'description': item['description'],
            'event_date': item['event_date'],
            'event_type': item['event_type'],
            'color': item['color'],
            'is_recurring': item['is_recurring'] == true ? 1 : 0,
            'notification_enabled': item['notification_enabled'] == true ? 1 : 0,
            'is_deleted': item['is_deleted'] == true ? 1 : 0,
            'is_synced': 1,
            'version': item['version'] ?? 1,
            'updated_at': item['updated_at']
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      print("Error syncing events: $e");
    }
  }
}