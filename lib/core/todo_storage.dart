import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import '../features/todo/domain/entities/todo.dart';
import 'database/app_database.dart';

class TodoStorage {
  static Future<List<Todo>> loadTodos() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final todosJson = prefs.getString('todos') ?? '[]';
      final List<dynamic> todosList = json.decode(todosJson);
      return todosList
          .map((json) => Todo.fromJson(json))
          .where((todo) => !todo.isDeleted)
          .toList();
    } else {
      final db = await AppDatabase().database;
      final result = await db.query(
        'todos',
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'position DESC, created_at DESC',
      );
      return result.map((json) => Todo.fromJson(json)).toList();
    }
  }

  static Future<void> saveTodo(Todo todo) async {
    if (kIsWeb) {
      final todos = await loadTodos();
      final index = todos.indexWhere((t) => t.clientId == todo.clientId);

      if (index != -1) {
        todos[index] = todo;
      } else {
        todos.add(todo);
      }

      final prefs = await SharedPreferences.getInstance();
      final todosJson = json.encode(todos.map((t) => t.toJson()).toList());
      await prefs.setString('todos', todosJson);
    } else {
      final db = await AppDatabase().database;
      await db.insert(
        'todos',
        todo.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
