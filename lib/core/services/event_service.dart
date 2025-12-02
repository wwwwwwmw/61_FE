import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'sync_service.dart';

class EventService {
  // Keep constructor compatible with existing call sites; argument unused
  EventService([dynamic unused]);

  Future<int?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uidStr = prefs.getString('user_id');
      final uid = uidStr != null ? int.tryParse(uidStr) : null;
      return uid ?? prefs.getInt('user_id');
    } catch (_) {
      return null;
    }
  }

  // Helper to normalize boolean-like values into SQLite int (0/1)
  int _boolToInt(dynamic value, {int? fallback}) {
    if (value is bool) return value ? 1 : 0;
    if (value is num) return value != 0 ? 1 : 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return 1;
      if (v == 'false' || v == '0' || v == 'no') return 0;
    }
    return fallback ?? 0;
  }

  // Read events from local DB with filters
  Future<List<Map<String, dynamic>>> getEvents({
    String? search,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await AppDatabase().database;
    final userId = await _getCurrentUserId();

    final whereClauses = <String>['is_deleted = 0'];
    final whereArgs = <Object?>[];
    if (userId != null) {
      whereClauses.add('user_id = ?');
      whereArgs.add(userId);
    }

    if (type != null && type.isNotEmpty) {
      whereClauses.add('event_type = ?');
      whereArgs.add(type);
    }
    if (startDate != null) {
      whereClauses.add('event_date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('event_date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }
    if (search != null && search.isNotEmpty) {
      whereClauses.add('(title LIKE ? OR description LIKE ?)');
      whereArgs.addAll(['%$search%', '%$search%']);
    }

    final rows = await db.query(
      'events',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'event_date ASC',
    );
    return rows;
  }

  // Create an event locally and mark as unsynced
  Future<Map<String, dynamic>> createEvent(
      Map<String, dynamic> eventData) async {
    final db = await AppDatabase().database;
    final clientId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();
    final userId = await _getCurrentUserId();

    final row = <String, dynamic>{
      'id': null,
      'client_id': clientId,
      'title': eventData['title'] ?? '',
      'description': eventData['description'],
      'event_date': eventData['event_date'],
      'event_type': eventData['event_type'],
      'color': eventData['color'],
      'recurrence_pattern': eventData['recurrence_pattern'],
      'is_recurring': _boolToInt(eventData['is_recurring']),
      'notification_enabled':
          _boolToInt(eventData['notification_enabled'], fallback: 1),
      'user_id': userId,
      'is_deleted': 0,
      'is_synced': 0,
      'version': 1,
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    await db.insert(
      'events',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Trigger background sync (not awaited)
    // ignore: unawaited_futures
    SyncService().syncAll();

    return row;
  }

  // Update local event by client_id (fallback to id if needed)
  Future<int> updateEvent(
      String clientId, Map<String, dynamic> eventData) async {
    final db = await AppDatabase().database;
    final nowIso = DateTime.now().toIso8601String();

    final update = <String, dynamic>{
      ...eventData,
      'is_synced': 0,
      'updated_at': nowIso,
    };

    if (eventData.containsKey('is_recurring')) {
      update['is_recurring'] = _boolToInt(eventData['is_recurring']);
    }
    if (eventData.containsKey('recurrence_pattern')) {
      update['recurrence_pattern'] = eventData['recurrence_pattern'];
    }
    if (eventData.containsKey('notification_enabled')) {
      update['notification_enabled'] =
          _boolToInt(eventData['notification_enabled'], fallback: 1);
    }

    int count = await db.update(
      'events',
      update,
      where: 'client_id = ?',
      whereArgs: [clientId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Fallback: if not found by client_id, try id (legacy callers may pass id)
    if (count == 0) {
      count = await db.update(
        'events',
        update,
        where: 'id = ?',
        whereArgs: [int.tryParse(clientId) ?? clientId],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Trigger background sync (not awaited)
    // ignore: unawaited_futures
    SyncService().syncAll();

    return count;
  }

  // Soft delete local event
  Future<int> deleteEvent(String clientId) async {
    final db = await AppDatabase().database;

    final payload = <String, dynamic>{
      'is_deleted': 1,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    };

    int count = await db.update(
      'events',
      payload,
      where: 'client_id = ?',
      whereArgs: [clientId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (count == 0) {
      count = await db.update(
        'events',
        payload,
        where: 'id = ?',
        whereArgs: [int.tryParse(clientId) ?? clientId],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Trigger background sync (not awaited)
    // ignore: unawaited_futures
    SyncService().syncAll();

    return count;
  }
}
