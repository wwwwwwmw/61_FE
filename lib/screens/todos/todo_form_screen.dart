import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../features/todo/domain/entities/todo.dart';

class TodoFormScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final Todo? todo;

  const TodoFormScreen({super.key, required this.prefs, this.todo});

  @override
  State<TodoFormScreen> createState() => _TodoFormScreenState();
}

class _TodoFormScreenState extends State<TodoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  DateTime? _dueDate;
  DateTime? _reminderTime;
  String _priority = 'medium';

  // Quản lý danh mục
  List<dynamic> _categories = [];
  int? _selectedCategoryId;
  bool _isLoadingCategories = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories(); // Tải danh mục người dùng đã tạo

    if (widget.todo != null) {
      _titleController.text = widget.todo!.title;
      _descController.text = widget.todo!.description ?? '';
      _priority = widget.todo!.priority;
      _dueDate = widget.todo!.dueDate;
      _reminderTime = widget.todo!.reminderTime;
      _selectedCategoryId = widget.todo!.categoryId;
    }
  }

  // Tải danh mục của User (API đã lọc theo user_id rồi)
  Future<void> _fetchCategories() async {
    try {
      final client = ApiClient(widget.prefs);
      // Gọi API lấy danh mục, filter type=todo hoặc both
      final res =
          await client.get('${AppConstants.categoriesEndpoint}?type=todo');
      if (res.data['success']) {
        setState(() {
          _categories = res.data['data'];
          _isLoadingCategories = false;

          // Nếu đang edit mà danh mục cũ bị xóa, reset về null
          if (_selectedCategoryId != null) {
            final exists =
                _categories.any((c) => c['id'] == _selectedCategoryId);
            if (!exists) _selectedCategoryId = null;
          }
        });
      }
    } catch (e) {
      print("Lỗi tải danh mục: $e");
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final client = ApiClient(widget.prefs);

      // Lấy tên danh mục làm tag (nếu có chọn danh mục)
      List<String> tags = [];
      if (_selectedCategoryId != null) {
        final cat = _categories.firstWhere(
            (c) => c['id'] == _selectedCategoryId,
            orElse: () => null);
        if (cat != null) tags.add(cat['name']);
      }

      final data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'priority': _priority,
        'due_date': _dueDate?.toIso8601String(),
        'reminder_time': _reminderTime?.toIso8601String(),
        'category_id': _selectedCategoryId,
        'tags': tags, // Lưu tên danh mục vào tags để tương thích hiển thị cũ
      };

      if (widget.todo == null) {
        await client.post(AppConstants.todosEndpoint, data: data);
      } else {
        await client.put('${AppConstants.todosEndpoint}/${widget.todo!.id}',
            data: data);
      }

      if (mounted) Navigator.pop(context, true); // Trả về true để reload list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Chọn ngày giờ
  Future<void> _pickDateTime(bool isDueDate) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: isDueDate ? (_dueDate ?? now) : (_reminderTime ?? now),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          isDueDate ? (_dueDate ?? now) : (_reminderTime ?? now)),
    );
    if (time == null) return;

    final result =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isDueDate) {
        _dueDate = result;
      } else {
        _reminderTime = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.todo == null ? 'Thêm công việc' : 'Sửa công việc'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v!.isEmpty ? 'Nhập tiêu đề' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // --- CHỌN DANH MỤC (Thay thế Tags) ---
              DropdownButtonFormField<int>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.map<DropdownMenuItem<int>>((cat) {
                  return DropdownMenuItem<int>(
                    value: cat['id'],
                    child: Row(
                      children: [
                        Icon(Icons.circle,
                            color: Color(int.parse(
                                cat['color'].replaceAll('#', '0xFF'))),
                            size: 12),
                        const SizedBox(width: 8),
                        Text(cat['name']),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
                hint: _isLoadingCategories
                    ? const Text('Đang tải danh mục...')
                    : const Text('Chọn danh mục'),
              ),
              const SizedBox(height: 16),

              // Chọn độ ưu tiên
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Độ ưu tiên',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'low',
                      child:
                          Text('Thấp', style: TextStyle(color: Colors.green))),
                  DropdownMenuItem(
                      value: 'medium',
                      child: Text('Trung bình',
                          style: TextStyle(color: Colors.orange))),
                  DropdownMenuItem(
                      value: 'high',
                      child: Text('Cao', style: TextStyle(color: Colors.red))),
                ],
                onChanged: (v) => setState(() => _priority = v!),
              ),
              const SizedBox(height: 16),

              // Chọn ngày
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDateTime(true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_dueDate == null
                          ? 'Hạn chót'
                          : DateFormat('dd/MM HH:mm').format(_dueDate!)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDateTime(false),
                      icon: const Icon(Icons.alarm),
                      label: Text(_reminderTime == null
                          ? 'Nhắc nhở'
                          : DateFormat('dd/MM HH:mm').format(_reminderTime!)),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _reminderTime != null &&
                                  _reminderTime!.isBefore(DateTime.now())
                              ? Colors.red
                              : null),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveTodo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Lưu công việc',
                        style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
