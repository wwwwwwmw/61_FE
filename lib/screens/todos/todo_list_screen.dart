import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/database/app_database.dart';
import '../../core/network/api_client.dart';
import '../../core/services/todo_service.dart';
import '../../features/todo/domain/entities/todo.dart';
import 'todo_form_screen.dart';
import 'todo_detail_screen.dart';

class TodoListScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const TodoListScreen({super.key, required this.prefs});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final AppDatabase _database = AppDatabase();
  late final TodoService _todoService;
  List<Todo> _todos = [];
  bool _isLoading = true;
  bool _isOnline = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _todoService = TodoService(ApiClient(widget.prefs));
    _checkConnectivity();
    _loadTodos();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });
  }

  Future<void> _loadTodos() async {
    setState(() => _isLoading = true);

    try {
      await _checkConnectivity();

      // ONLY PostgreSQL - SQLite disabled for testing
      try {
        final apiTodos = await _todoService.getTodos();

        // TODO: Save to SQLite later for offline
        // final db = await _database.database;
        // for (var todoJson in apiTodos) {
        //   await db.insert(
        //     'todos',
        //     todoJson,
        //     conflictAlgorithm: ConflictAlgorithm.replace,
        //   );
        // }

        setState(() {
          _todos = apiTodos
              .map((json) => Todo.fromJson(json))
              .where((t) => !t.isDeleted)
              .toList();
          _isLoading = false;
        });
      } catch (e) {
        print('API error: $e');
        _showError('Không kết nối được API: $e');
        setState(() => _isLoading = false);
        // Disable SQLite fallback
        // await _loadFromSQLite();
      }
    } catch (e) {
      print('Error loading todos: $e');
      _showError('Lỗi: $e');
      setState(() => _isLoading = false);
    }
  }

  // SQLite fallback - DISABLED
  // Future<void> _loadFromSQLite() async {
  //   final db = await _database.database;
  //   final result = await db.query(
  //     'todos',
  //     where: 'is_deleted = ?',
  //     whereArgs: [0],
  //     orderBy: 'position DESC, created_at DESC',
  //   );
  //
  //   setState(() {
  //     _todos = result.map((json) => Todo.fromJson(json)).toList();
  //     _isLoading = false;
  //   });
  // }

  List<Todo> get _filteredTodos {
    switch (_filter) {
      case 'active':
        return _todos.where((t) => !t.isCompleted).toList();
      case 'completed':
        return _todos.where((t) => t.isCompleted).toList();
      default:
        return _todos;
    }
  }

  Future<void> _toggleComplete(Todo todo) async {
    // Optimistic UI update
    final updatedTodo = todo.copyWith(
      isCompleted: !todo.isCompleted,
      updatedAt: DateTime.now(),
    );

    setState(() {
      final index = _todos.indexWhere((t) => t.clientId == todo.clientId);
      if (index != -1) {
        _todos[index] = updatedTodo;
      }
    });

    try {
      // ONLY PostgreSQL API
      await _todoService.toggleComplete(todo.clientId!, !todo.isCompleted);

      // TODO: Update SQLite later
      // final db = await _database.database;
      // await db.update(...);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedTodo.isCompleted ? 'Đã hoàn thành ✓' : 'Đã hủy hoàn thành',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _showError('Lỗi API: $e');
      // Revert UI on error
      setState(() {
        final index = _todos.indexWhere((t) => t.clientId == todo.clientId);
        if (index != -1) {
          _todos[index] = todo;
        }
      });
    }
  }

  // SQLite only save - DISABLED
  // Future<void> _saveToSQLiteOnly(Todo todo) async {
  //   ...
  // }

  Future<void> _deleteTodo(Todo todo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "${todo.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // ONLY PostgreSQL API
        await _todoService.deleteTodo(todo.clientId!);

        // TODO: Also delete from SQLite later
        // final db = await _database.database;
        // await db.update(...);

        await _loadTodos();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã xóa công việc')));
        }
      } catch (e) {
        _showError('Lỗi khi xóa: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppColors.priorityHigh;
      case 'medium':
        return AppColors.priorityMedium;
      default:
        return AppColors.priorityLow;
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return 'Cao';
      case 'medium':
        return 'Trung bình';
      default:
        return 'Thấp';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Công Việc'),
            const SizedBox(width: 8),
            if (!_isOnline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Offline',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Tất cả')),
              const PopupMenuItem(
                value: 'active',
                child: Text('Chưa hoàn thành'),
              ),
              const PopupMenuItem(
                value: 'completed',
                child: Text('Đã hoàn thành'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredTodos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có công việc nào',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhấn nút + để thêm mới',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTodos,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredTodos.length,
                itemBuilder: (context, index) {
                  final todo = _filteredTodos[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Checkbox(
                        value: todo.isCompleted,
                        onChanged: (value) => _toggleComplete(todo),
                        shape: const CircleBorder(),
                      ),
                      title: Text(
                        todo.title,
                        style: TextStyle(
                          decoration: todo.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (todo.description != null &&
                              todo.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              todo.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(
                                    todo.priority,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getPriorityLabel(todo.priority),
                                  style: TextStyle(
                                    color: _getPriorityColor(todo.priority),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (todo.dueDate != null) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(todo.dueDate!),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Sửa'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: AppColors.error),
                                SizedBox(width: 8),
                                Text(
                                  'Xóa',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TodoFormScreen(todo: todo),
                              ),
                            );
                            if (result == true) _loadTodos();
                          } else if (value == 'delete') {
                            _deleteTodo(todo);
                          }
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TodoDetailScreen(todo: todo),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TodoFormScreen()),
          );
          if (result == true) _loadTodos();
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm công việc'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
