import '../constants/app_constants.dart';
import '../network/api_client.dart';

class TodoService {
  final ApiClient _apiClient;

  TodoService(this._apiClient);

  // Get todos with optional filters & search
  Future<List<Map<String, dynamic>>> getTodos({
    String? search,
    String? categoryId,
    String? priority,
    bool? completed,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (search != null && search.isNotEmpty) query['q'] = search;
      if (categoryId != null && categoryId.isNotEmpty) {
        query['category_id'] = categoryId;
      }
      if (priority != null && priority.isNotEmpty) query['priority'] = priority;
      if (completed != null) query['completed'] = completed.toString();
      final response = await _apiClient.get(
        AppConstants.todosEndpoint,
        queryParameters: query,
      );
      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e) {
      print('Error getting todos: $e');
      rethrow;
    }
  }

  // Create todo
  Future<Map<String, dynamic>> createTodo(Map<String, dynamic> todoData) async {
    try {
      final response = await _apiClient.post(
        AppConstants.todosEndpoint,
        data: todoData,
      );
      return response.data['data'];
    } catch (e) {
      print('Error creating todo: $e');
      rethrow;
    }
  }

  // Update todo
  Future<Map<String, dynamic>> updateTodo(
    String id,
    Map<String, dynamic> todoData,
  ) async {
    try {
      final response = await _apiClient.put(
        '${AppConstants.todosEndpoint}/$id',
        data: todoData,
      );
      return response.data['data'];
    } catch (e) {
      print('Error updating todo: $e');
      rethrow;
    }
  }

  // Toggle complete
  Future<Map<String, dynamic>> toggleComplete(String id, bool bool) async {
    try {
      final response = await _apiClient.patch(
        '${AppConstants.todosEndpoint}/$id/toggle',
      );
      return response.data['data'];
    } catch (e) {
      print('Error toggling complete: $e');
      rethrow;
    }
  }

  // Delete todo
  Future<void> deleteTodo(String id) async {
    try {
      await _apiClient.delete('${AppConstants.todosEndpoint}/$id');
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
        '${AppConstants.todosEndpoint}/sync',
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
