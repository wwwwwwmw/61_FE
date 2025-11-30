import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../features/todo/domain/entities/todo.dart'; // [QUAN TRỌNG] Import Todo Entity
import 'todo_form_screen.dart';

class TodoDetailScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final int todoId;

  const TodoDetailScreen(
      {super.key, required this.prefs, required this.todoId});

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  Todo? _todo; // [FIX] Đổi kiểu từ Map thành Todo object
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final client = ApiClient(widget.prefs);
      final res =
          await client.get('${AppConstants.todosEndpoint}/${widget.todoId}');
      if (res.data['success']) {
        setState(() {
          // [FIX] Parse JSON thành Todo object ngay khi lấy về
          _todo = Todo.fromJson(res.data['data']);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _deleteTodo() async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa công việc'),
        content: const Text('Hành động này không thể hoàn tác?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final client = ApiClient(widget.prefs);
        await client.delete('${AppConstants.todosEndpoint}/${widget.todoId}');
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_todo == null) {
      return const Scaffold(
          body: Center(child: Text("Không tìm thấy dữ liệu")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TodoFormScreen(
                    prefs: widget.prefs,
                    todo:
                        _todo, // [OK] Giờ _todo đã là kiểu Todo, truyền sang Form OK
                  ),
                ),
              );
              if (result == true) _fetchDetail();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteTodo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _todo!.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.description, 'Mô tả',
                _todo!.description ?? 'Không có mô tả'),
            const SizedBox(height: 12),
            _buildInfoRow(
                Icons.flag, 'Độ ưu tiên', _todo!.priority.toUpperCase()),
            const SizedBox(height: 12),
            if (_todo!.dueDate != null)
              _buildInfoRow(Icons.calendar_today, 'Hạn chót',
                  DateFormat('dd/MM/yyyy HH:mm').format(_todo!.dueDate!)),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.category, 'Danh mục ID',
                _todo!.categoryId?.toString() ?? 'Chưa phân loại'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.info_outline, 'Trạng thái',
                _todo!.isCompleted ? 'Đã xong' : 'Đang thực hiện'),
            const SizedBox(height: 12),
            // Hiển thị Tags
            Row(
              children: [
                const Icon(Icons.label, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: _todo!.tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.1),
                              labelStyle:
                                  const TextStyle(color: AppColors.primary),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}
