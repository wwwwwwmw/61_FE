import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import 'todo_form_screen.dart';
import 'todo_detail_screen.dart'; // Đảm bảo import file này

class TodoListScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const TodoListScreen({super.key, required this.prefs});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  List<dynamic> _todos = [];
  bool _isLoading = true;
  String? _selectedTag;
  final List<String> _tags = ['All', 'Work', 'Personal', 'Urgent', 'Shopping'];

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  Future<void> _fetchTodos() async {
    setState(() => _isLoading = true);
    try {
      final client = ApiClient(widget.prefs);
      final res = await client.get(
        AppConstants.todosEndpoint,
        queryParameters: _selectedTag != null && _selectedTag != 'All'
            ? {'tag': _selectedTag}
            : null,
      );
      if (res.data['success']) {
        setState(() {
          _todos = res.data['data'];
        });
      }
    } catch (e) {
      print('Lỗi tải todos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTodo(int id) async {
    try {
      final client = ApiClient(widget.prefs);
      await client.delete('${AppConstants.todosEndpoint}/$id');
      // Không cần fetch lại toàn bộ, chỉ cần xóa khỏi list local
      setState(() {
        _todos.removeWhere((t) => t['id'] == id);
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa công việc')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Công việc của tôi')),
      body: Column(
        children: [
          // Filter Tags
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: _tags.length,
              itemBuilder: (ctx, index) {
                final tag = _tags[index];
                final isSelected = (_selectedTag ?? 'All') == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedTag = tag);
                        _fetchTodos();
                      }
                    },
                  ),
                );
              },
            ),
          ),
          
          // Todo List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _todos.isEmpty
                    ? const Center(child: Text('Không có công việc nào'))
                    : ListView.builder(
                        itemCount: _todos.length,
                        itemBuilder: (ctx, index) {
                          final todo = _todos[index];
                          return Dismissible(
                            key: Key(todo['id'].toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Xác nhận xóa'),
                                  content: const Text('Bạn có chắc muốn xóa công việc này?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) {
                              _deleteTodo(todo['id']);
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                onTap: () async {
                                  // Chuyển sang màn hình chi tiết
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TodoDetailScreen(
                                        prefs: widget.prefs, 
                                        todoId: todo['id']
                                      ),
                                    ),
                                  );
                                  if (result == true) _fetchTodos(); // Reload nếu có thay đổi
                                },
                                leading: Checkbox(
                                  value: todo['is_completed'] == true,
                                  onChanged: (v) async {
                                    // Gọi API toggle complete tại đây nếu muốn
                                  }, 
                                ),
                                title: Text(
                                  todo['title'],
                                  style: TextStyle(
                                    decoration: todo['is_completed'] == true
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: todo['tags'] != null
                                    ? Text(
                                        (todo['tags'] is List) 
                                          ? (todo['tags'] as List).join(', ')
                                          : todo['tags'].toString(),
                                        style: TextStyle(color: AppColors.primary),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      // [FIX] Nút thêm công việc
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TodoFormScreen(prefs: widget.prefs),
            ),
          );
          if (result == true) {
            _fetchTodos(); // Reload list khi quay lại
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}