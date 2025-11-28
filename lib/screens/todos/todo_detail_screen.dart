import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/database/app_database.dart';
import '../../features/todo/domain/entities/todo.dart';
import 'todo_form_screen.dart';

class TodoDetailScreen extends StatefulWidget {
  final Todo todo;
  
  const TodoDetailScreen({Key? key, required this.todo}) : super(key: key);

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  late Todo _todo;

  @override
  void initState() {
    super.initState();
    _todo = widget.todo;
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

  Future<void> _toggleComplete() async {
    try {
      final db = await AppDatabase().database;
      await db.update(
        'todos',
        {
          'is_completed': _todo.isCompleted ? 0 : 1,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
        where: 'client_id = ?',
        whereArgs: [_todo.clientId],
      );
      
      setState(() {
        _todo = _todo.copyWith(isCompleted: !_todo.isCompleted);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_todo.isCompleted 
              ? 'Đã đánh dấu hoàn thành' 
              : 'Đã đánh dấu chưa hoàn thành'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteTodo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa công việc này?'),
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
        final db = await AppDatabase().database;
        await db.update(
          'todos',
          {
            'is_deleted': 1,
            'updated_at': DateTime.now().toIso8601String(),
            'is_synced': 0,
          },
          where: 'client_id = ?',
          whereArgs: [_todo.clientId],
        );
        
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa công việc')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Tiết Công Việc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TodoFormScreen(todo: _todo),
                ),
              );
              if (result == true && mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteTodo,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Card(
            color: _todo.isCompleted ? AppColors.success.withOpacity(0.1) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _todo.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: _todo.isCompleted ? AppColors.success : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _todo.isCompleted ? 'Đã hoàn thành' : 'Chưa hoàn thành',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: _todo.isCompleted ? AppColors.success : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (_todo.isCompleted)
                          Text(
                            'Hoàn thành vào ${DateFormat('dd/MM/yyyy').format(_todo.updatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _todo.isCompleted,
                    onChanged: (_) => _toggleComplete(),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Title
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.title, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tiêu đề',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _todo.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          // Description
          if (_todo.description != null && _todo.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Mô tả',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _todo.description!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 8),
          
          // Priority
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('Độ ưu tiên'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getPriorityColor(_todo.priority).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getPriorityLabel(_todo.priority),
                  style: TextStyle(
                    color: _getPriorityColor(_todo.priority),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          
          // Tags
          if (_todo.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_offer, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Tags',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _todo.tags.map((tag) => Chip(
                        label: Text(tag),
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        labelStyle: TextStyle(color: AppColors.primary),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Due Date
          if (_todo.dueDate != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Ngày hạn'),
                subtitle: Text(DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_todo.dueDate!)),
              ),
            ),
          ],
          
          // Reminder
          if (_todo.reminderTime != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Nhắc nhở'),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(_todo.reminderTime!),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          
          // Metadata
          Text(
            'Thông tin khác',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, size: 20),
                  title: const Text('Ngày tạo'),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(_todo.createdAt),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.update, size: 20),
                  title: const Text('Cập nhật lần cuối'),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(_todo.updatedAt),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleComplete,
        icon: Icon(_todo.isCompleted ? Icons.replay : Icons.check),
        label: Text(_todo.isCompleted ? 'Đánh dấu chưa xong' : 'Hoàn thành'),
        backgroundColor: _todo.isCompleted ? Colors.grey : AppColors.success,
        foregroundColor: Colors.white,
      ),
    );
  }
}
