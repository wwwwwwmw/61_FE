import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'sync_service.dart';

class ExpensesService {
  // Keep a compatible constructor for existing call sites; the argument is unused.
  ExpensesService([dynamic unused]);

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

  // Read expenses from local DB with filters; return { 'data': [...] } for compatibility
  Future<Map<String, dynamic>> getExpenses({
    String? type,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    bool includeDeleted = false,
  }) async {
    final db = await AppDatabase().database;
    final userId = await _getCurrentUserId();

    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (!includeDeleted) {
      whereClauses.add('is_deleted = ?');
      whereArgs.add(0);
    }
    if (userId != null) {
      whereClauses.add('user_id = ?');
      whereArgs.add(userId);
    }
    if (type != null && type.isNotEmpty) {
      whereClauses.add('type = ?');
      whereArgs.add(type);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      whereClauses.add('category_id = ?');
      whereArgs.add(int.tryParse(categoryId) ?? categoryId);
    }
    if (startDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final results = await db.query(
      'expenses',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereClauses.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );

    return {'data': results};
  }

  // Create a local expense and mark as unsynced. Returns inserted client_id.
  Future<String> createExpense(Map<String, dynamic> data) async {
    final db = await AppDatabase().database;
    final clientId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();
    final userId = await _getCurrentUserId();

    final amountRaw = data['amount'];
    final double amount = amountRaw is int
        ? amountRaw.toDouble()
        : (amountRaw is double
            ? amountRaw
            : double.tryParse(amountRaw?.toString() ?? '0') ?? 0.0);

    final row = <String, dynamic>{
      'id': null,
      'client_id': clientId,
      'amount': amount,
      'type': data['type'],
      'category_id': data['category_id'],
      'description': data['description'],
      'date': (data['date'] as String?) ?? DateTime.now().toIso8601String(),
      'payment_method': data['payment_method'],
      'user_id': userId,
      'is_deleted': 0,
      'is_synced': 0,
      'version': 1,
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    await db.insert(
      'expenses',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Trigger background sync (not awaited)
    // ignore: unawaited_futures
    SyncService().syncAll();

    return clientId;
  }

  // Update a local expense by client_id; fall back to id if needed. Returns updated row count.
  Future<int> updateExpense(String clientId, Map<String, dynamic> data) async {
    final db = await AppDatabase().database;
    final nowIso = DateTime.now().toIso8601String();

    final update = <String, dynamic>{
      ...data,
      'is_synced': 0,
      'updated_at': nowIso,
    };

    if (data.containsKey('amount')) {
      final amountRaw = data['amount'];
      update['amount'] = amountRaw is int
          ? amountRaw.toDouble()
          : (amountRaw is double
              ? amountRaw
              : double.tryParse(amountRaw?.toString() ?? '0') ?? 0.0);
    }

    int count = await db.update(
      'expenses',
      update,
      where: 'client_id = ?',
      whereArgs: [clientId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // If not matched by client_id, try matching by id (for legacy callers)
    if (count == 0) {
      count = await db.update(
        'expenses',
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

  // Soft delete by client_id; fall back to id if not found.
  Future<int> deleteExpense(String clientId, {bool permanent = false}) async {
    final db = await AppDatabase().database;

    // Only soft delete per requirement
    final payload = <String, dynamic>{
      'is_deleted': 1,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    };

    int count = await db.update(
      'expenses',
      payload,
      where: 'client_id = ?',
      whereArgs: [clientId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (count == 0) {
      count = await db.update(
        'expenses',
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

  // Local statistics grouped by type
  Future<Map<String, dynamic>> getStatistics({
    String? type,
    String? categoryId,
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
      whereClauses.add('type = ?');
      whereArgs.add(type);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      whereClauses.add('category_id = ?');
      whereArgs.add(int.tryParse(categoryId) ?? categoryId);
    }
    if (startDate != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final whereSql = whereClauses.join(' AND ');
    final rows = await db.rawQuery(
      'SELECT type, SUM(amount) as total FROM expenses WHERE $whereSql GROUP BY type',
      whereArgs,
    );

    double totalIncome = 0;
    double totalExpense = 0;
    for (final r in rows) {
      final t = r['type'] as String?;
      final num total = (r['total'] as num?) ?? 0;
      if (t == 'income') totalIncome += total.toDouble();
      if (t == 'expense') totalExpense += total.toDouble();
    }

    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
    };
  }
}
