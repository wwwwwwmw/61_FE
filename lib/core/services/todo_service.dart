import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'sync_service.dart';

class TodoService {
  TodoService();

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

  // Read local todos (is_deleted = 0), newest first
  Future<List<Map<String, dynamic>>> getLocalTodos() async {
    final db = await AppDatabase().database;
    final userId = await _getCurrentUserId();
    final rows = await db.query(
      'todos',
      where:
          userId != null ? 'is_deleted = 0 AND user_id = ?' : 'is_deleted = 0',
      whereArgs: userId != null ? [userId] : null,
      orderBy: 'created_at DESC',
    );
    return rows;
  }

  // Create a todo locally and mark as unsynced
  Future<String> createTodoLocal(Map<String, dynamic> todoData) async {
    final db = await AppDatabase().database;
    final nowIso = DateTime.now().toIso8601String();
    final clientId = const Uuid().v4();
    final userId = await _getCurrentUserId();

    // Convert tags: List<String> -> comma-separated String
    final dynamic tagsValue = todoData['tags'];
    final String tagsString = tagsValue is List
        ? tagsValue.whereType<String>().join(',')
        : (tagsValue is String ? tagsValue : '');

    final row = <String, dynamic>{
      'id': null, // new local row (no server id yet)
      'client_id': clientId,
      'title': todoData['title'] ?? '',
      'description': todoData['description'],
      'is_completed': 0,
      'category_id': todoData['category_id'],
      'priority': todoData['priority'],
      'tags': tagsString,
      'due_date': todoData['due_date'],
      'reminder_time': todoData['reminder_time'],
      'user_id': userId,
      'is_deleted': 0,
      'is_synced': 0,
      'version': 1,
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    await db.insert(
      'todos',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Trigger background sync
    // Not awaited intentionally to avoid blocking UI
    // ignore: unawaited_futures
    SyncService().syncAll();

    return clientId;
  }

  // Update a local todo by client_id and mark as unsynced
  Future<int> updateTodoLocal(
      String clientId, Map<String, dynamic> todoData) async {
    final db = await AppDatabase().database;
    final nowIso = DateTime.now().toIso8601String();

    final updateMap = <String, dynamic>{
      ...todoData,
      'is_synced': 0,
      'updated_at': nowIso,
    };

    // Normalize tags if provided
    if (todoData.containsKey('tags')) {
      final dynamic tagsValue = todoData['tags'];
      updateMap['tags'] = tagsValue is List
          ? tagsValue.whereType<String>().join(',')
          : (tagsValue is String ? tagsValue : '');
    }

    // Normalize is_completed if provided (bool -> int)
    if (todoData.containsKey('is_completed')) {
      final val = todoData['is_completed'];
      if (val is bool) updateMap['is_completed'] = val ? 1 : 0;
    }

    final count = await db.update(
      'todos',
      updateMap,
      where: 'client_id = ?',
      whereArgs: [clientId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Trigger background sync
    // ignore: unawaited_futures
    SyncService().syncAll();

    return count;
  }

  // Soft delete a local todo (is_deleted = 1) and mark as unsynced
  Future<int> deleteTodoLocal(String clientId) async {
    final db = await AppDatabase().database;
    final count = await db.update(
      'todos',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'client_id = ?',
      whereArgs: [clientId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Trigger background sync
    // ignore: unawaited_futures
    SyncService().syncAll();

    return count;
  }
}
