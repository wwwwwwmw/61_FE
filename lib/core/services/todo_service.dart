import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';

class TodoService {
  final ApiClient _apiClient;

  TodoService(this._apiClient);

  // Get all todos
  Future<List<Map<String, dynamic>>> getTodos() async {
    try {
      final response = await _apiClient.get('/api/todos');
      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e) {
      print('Error getting todos: $e');
      rethrow;
    }
  }

  // Create todo
  Future<Map<String, dynamic>> createTodo(Map<String, dynamic> todoData) async {
    try {
      final response = await _apiClient.post('/api/todos', data: todoData);
      return response.data['data'];
    } catch (e) {
      print('Error creating todo: $e');
      rethrow;
    }
  }

  // Update todo
  Future<Map<String, dynamic>> updateTodo(
    String clientId,
    Map<String, dynamic> todoData,
  ) async {
    try {
      final response = await _apiClient.put(
        '/api/todos/$clientId',
        data: todoData,
      );
      return response.data['data'];
    } catch (e) {
      print('Error updating todo: $e');
      rethrow;
    }
  }

  // Toggle complete
  Future<Map<String, dynamic>> toggleComplete(
    String clientId,
    bool isCompleted,
  ) async {
    try {
      final response = await _apiClient.patch('/api/todos/$clientId/toggle');
      return response.data['data'];
    } catch (e) {
      print('Error toggling complete: $e');
      rethrow;
    }
  }

  // Delete todo
  Future<void> deleteTodo(String clientId) async {
    try {
      await _apiClient.delete('/api/todos/$clientId');
    } catch (e) {
      print('Error deleting todo: $e');
      rethrow;
    }
  }

  // Sync todos (backend expects { todos, lastSyncTime })
  Future<Map<String, dynamic>> syncTodos(
    List<Map<String, dynamic>> localTodos, {
    DateTime? lastSyncTime,
  }) async {
    try {
      final response = await _apiClient.post(
        AppConstants.todosEndpoint + '/sync',
        data: {
          'todos': localTodos,
          'lastSyncTime':
              (lastSyncTime ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .toIso8601String(),
        },
      );
      return Map<String, dynamic>.from(response.data['data'] ?? response.data);
    } catch (e) {
      print('Error syncing todos: $e');
      rethrow;
    }
  }
}
