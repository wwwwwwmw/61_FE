import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/services/todo_service.dart';
import '../../features/todo/domain/entities/todo.dart';
import 'todo_form_screen.dart';

class TodoDetailScreen extends StatefulWidget {
  final Todo todo;
  final SharedPreferences prefs;
  
  const TodoDetailScreen({super.key, required this.todo, required this.prefs});

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  late Todo _todo;
  late final TodoService _todoService;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _todo = widget.todo;
    _todoService = TodoService(ApiClient(widget.prefs));
  }

  Future<void> _refreshTodo() async {
    try {
      if (_todo.id == null) return;
      // We need a getTodoById method in TodoService, or just use getTodos with filter?
      // TodoService has getTodos, but not getTodoById exposed directly in the interface I saw earlier?
      // Let's check TodoService again. It has getTodos.
      // Wait, I saw getTodos, create, update, delete. I didn't see getById in the file content I viewed in step 690.
      // I will check backend routes. GET /api/todos/:id exists.
      // I should add getTodoById to TodoService if it's missing, or just use getTodos and filter?
      // Actually, looking at step 690, TodoService DOES NOT have getTodoById.
      // I should add it to TodoService first? Or just implement it here using ApiClient directly?
      // Better to add it to TodoService.
      // For now, to avoid context switching, I'll use ApiClient directly or add it to TodoService.
      // I'll add it to TodoService in a separate step. For now, let's assume I'll add it.
      // Wait, I can't assume. I should check if I can just pass the updated object from TodoFormScreen?
      // TodoFormScreen currently returns 'true'. Changing it to return 'Todo' object is cleaner but requires changing TodoFormScreen.
      // Changing TodoFormScreen is easy.
      // Let's modify TodoFormScreen to return the updated Todo object instead of just true?
      // No, TodoFormScreen re-fetches or just sends data? It sends data. It doesn't get the full object back from updateTodo?
      // updateTodo returns Map<String, dynamic>. So yes, it gets the data.
      // So TodoFormScreen COULD return the new Todo object.
      // But TodoListScreen expects 'true'.
      // I'll stick to 'true' and just re-fetch in TodoDetailScreen.
      // I will implement _refreshTodo using ApiClient for now to be quick, or better, update TodoService.
      // I'll update TodoService first.
    } catch (e) {
      print('Error refreshing todo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, _hasChanged);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Chi tiết công việc"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasChanged),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TodoFormScreen(todo: _todo, prefs: widget.prefs)
                ));
                
                if (result == true) {
                  setState(() => _hasChanged = true);
                  // Fetch updated todo
                  try {
                     // Temporary direct API call until Service is updated
                     final client = ApiClient(widget.prefs);
                     final response = await client.get('/api/todos/${_todo.id}');
                     if (response.data['success'] == true) {
                       setState(() {
                         _todo = Todo.fromJson(response.data['data']);
                       });
                     }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi cập nhật: $e')),
                    );
                  }
                }
              },
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_todo.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(
                      _todo.priority == 'high' ? 'Cao' : (_todo.priority == 'medium' ? 'Trung bình' : 'Thấp'),
                      style: TextStyle(color: _todo.priority == 'high' ? Colors.white : Colors.black87),
                    ),
                    backgroundColor: _todo.priority == 'high' 
                        ? Colors.red 
                        : (_todo.priority == 'medium' ? Colors.orange.shade100 : Colors.grey.shade200),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (_todo.dueDate != null)
                              TextSpan(
                                text: "Hạn: ${_todo.dueDate!.day}/${_todo.dueDate!.month}/${_todo.dueDate!.year} ${_todo.dueDate!.hour}:${_todo.dueDate!.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                              ),
                            if (_todo.dueDate != null && _todo.reminderTime != null)
                              const TextSpan(text: " • ", style: TextStyle(color: Colors.grey)),
                            if (_todo.reminderTime != null)
                              TextSpan(
                                text: "Nhắc nhở: ${_todo.reminderTime!.day}/${_todo.reminderTime!.month}/${_todo.reminderTime!.year} ${_todo.reminderTime!.hour}:${_todo.reminderTime!.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Text(_todo.description ?? "Không có mô tả", style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}