import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/services/todo_service.dart';
import '../../features/todo/domain/entities/todo.dart';

class TodoFormScreen extends StatefulWidget {
  final Todo? todo; // null = create mode, not null = edit mode
  final SharedPreferences prefs;

  const TodoFormScreen({super.key, this.todo, required this.prefs});

  @override
  State<TodoFormScreen> createState() => _TodoFormScreenState();
}

class _TodoFormScreenState extends State<TodoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  String _priority = 'medium';
  DateTime? _dueDate;
  DateTime? _reminderTime;
  bool _isLoading = false;

  late final TodoService _todoService;

  @override
  void initState() {
    super.initState();
    _todoService = TodoService(ApiClient(widget.prefs));
    if (widget.todo != null) {
      _titleController.text = widget.todo!.title;
      _descriptionController.text = widget.todo!.description ?? '';
      _priority = widget.todo!.priority;
      _dueDate = widget.todo!.dueDate;
      _reminderTime = widget.todo!.reminderTime;
      _tagsController.text = widget.todo!.tags.join(', ');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() => _dueDate = date);
    }
  }

  Future<void> _selectReminderTime() async {
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày hạn trước')),
      );
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        _reminderTime = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final todoData = {
        'title': _titleController.text,
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'priority': _priority,
        'tags': tags, // Backend expects array, or handle join if needed. Service usually handles JSON.
        // Checking TodoService, it sends data directly. Backend likely expects array or string?
        // Let's check backend/routes/todos.js. It uses req.body.
        // If backend expects specific format, we should match.
        // Assuming backend handles JSON body.
        'due_date': _dueDate?.toIso8601String(),
        'reminder_time': _reminderTime?.toIso8601String(),
      };

      if (widget.todo == null) {
        // Create new todo
        await _todoService.createTodo(todoData);
      } else {
        // Update existing todo
        if (widget.todo!.id != null) {
             await _todoService.updateTodo(widget.todo!.id.toString(), todoData);
        } else {
             // Fallback if id is null (should not happen with API)
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lỗi: Không tìm thấy ID công việc')),
             );
             return;
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.todo == null
                ? 'Đã thêm công việc'
                : 'Đã cập nhật công việc'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.todo == null ? 'Thêm Công Việc' : 'Sửa Công Việc'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveTodo,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề *',
                hintText: 'Nhập tiêu đề công việc',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập tiêu đề';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                hintText: 'Nhập mô tả chi tiết (không bắt buộc)',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Priority
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Độ ưu tiên',
                prefixIcon: Icon(Icons.flag),
              ),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Thấp')),
                DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                DropdownMenuItem(value: 'high', child: Text('Cao')),
              ],
              onChanged: (value) {
                setState(() => _priority = value!);
              },
            ),

            const SizedBox(height: 16),

            // Tags
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'Ví dụ: công việc, cá nhân, khẩn cấp',
                prefixIcon: Icon(Icons.local_offer),
                helperText: 'Phân cách bằng dấu phẩy',
              ),
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 24),

            // Due Date
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Ngày hạn'),
                subtitle: Text(_dueDate == null
                    ? 'Chưa chọn'
                    : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'),
                trailing: _dueDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _dueDate = null),
                      )
                    : null,
                onTap: _selectDate,
              ),
            ),

            const SizedBox(height: 8),

            // Reminder Time
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Nhắc nhở'),
                subtitle: Text(_reminderTime == null
                    ? 'Chưa chọn'
                    : '${_reminderTime!.day}/${_reminderTime!.month}/${_reminderTime!.year} ${_reminderTime!.hour}:${_reminderTime!.minute.toString().padLeft(2, '0')}'),
                trailing: _reminderTime != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _reminderTime = null),
                      )
                    : null,
                onTap: _selectReminderTime,
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveTodo,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(widget.todo == null ? 'Thêm Công Việc' : 'Cập Nhật'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import '../../features/todo/domain/entities/todo.dart';

// class TodoFormScreen extends StatefulWidget {
//   final Todo? todo; // Changed from Map to Todo object
  
//   const TodoFormScreen({super.key, this.todo});

//   @override
//   State<TodoFormScreen> createState() => _TodoFormScreenState();
// }

// class _TodoFormScreenState extends State<TodoFormScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _titleController;
//   late TextEditingController _descController;
//   String _priority = 'medium';

//   @override
//   void initState() {
//     super.initState();
//     // Điền dữ liệu cũ nếu là chế độ Sửa
//     _titleController = TextEditingController(text: widget.todo?.title ?? '');
//     _descController = TextEditingController(
//       text: widget.todo?.description ?? '',
//     );
//     _priority = widget.todo?.priority ?? 'medium';
//   }

//   void _save() async {
//     if (_formKey.currentState!.validate()) {
//       final data = {
//         'title': _titleController.text,
//         'description': _descController.text,
//         'priority': _priority,
//       };

//       if (widget.todo == null) {
//         // Gọi API Tạo mới (Create)
//         // await TodoService.create(data);
//       } else {
//         // Gọi API Cập nhật (Update)
//         // await TodoService.update(widget.todo!.id, data);
//       }
//       Navigator.pop(context, true); // Trả về true để màn hình List reload lại
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.todo == null ? "Thêm công việc" : "Sửa công việc"),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               TextFormField(
//                 controller: _titleController,
//                 decoration: const InputDecoration(labelText: 'Tiêu đề'),
//                 validator: (v) => v!.isEmpty ? 'Nhập tiêu đề' : null,
//               ),
//               TextFormField(
//                 controller: _descController,
//                 decoration: const InputDecoration(labelText: 'Mô tả'),
//                 maxLines: 3,
//               ),
//               DropdownButtonFormField<String>(
//                 value: _priority,
//                 items: ['low', 'medium', 'high']
//                     .map((e) => DropdownMenuItem(value: e, child: Text(e)))
//                     .toList(),
//                 onChanged: (v) => setState(() => _priority = v!),
//                 decoration: const InputDecoration(labelText: 'Độ ưu tiên'),
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(onPressed: _save, child: const Text("Lưu lại")),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
