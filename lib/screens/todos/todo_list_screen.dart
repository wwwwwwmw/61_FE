import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';

class TodoListScreen extends StatefulWidget {
  final dynamic prefs; // SharedPrefs
  const TodoListScreen({super.key, required this.prefs});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  List<dynamic> _todos = [];
  String? _selectedTag; // Tag đang lọc
  final List<String> _tags = ['All', 'Work', 'Personal', 'Urgent', 'Shopping'];

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  Future<void> _fetchTodos() async {
    try {
      final client = ApiClient();
      // Truyền param tag vào API
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Công việc của tôi')),
      body: Column(
        children: [
          // --- THANH LỌC TAG ---
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                        _fetchTodos(); // Gọi lại API khi đổi tag
                      }
                    },
                  ),
                );
              },
            ),
          ),
          
          // --- DANH SÁCH CÔNG VIỆC ---
          Expanded(
            child: _todos.isEmpty
                ? const Center(child: Text('Không có công việc nào'))
                : ListView.builder(
                    itemCount: _todos.length,
                    itemBuilder: (ctx, index) {
                      final todo = _todos[index];
                      return ListTile(
                        leading: Checkbox(
                          value: todo['is_completed'],
                          onChanged: (v) {}, // Logic toggle status
                        ),
                        title: Text(todo['title']),
                        subtitle: Text(
                          todo['tags'] is List 
                              ? (todo['tags'] as List).join(', ') 
                              : (todo['tags'] ?? ''),
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Nav to Add Todo Screen
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}