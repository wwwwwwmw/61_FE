import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import 'todo_form_screen.dart';
import 'todo_detail_screen.dart';
import '../../features/todo/domain/entities/todo.dart';
import '../../core/services/todo_service.dart';

class TodoListScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const TodoListScreen({super.key, required this.prefs});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  List<dynamic> _allTodos = []; // Lưu toàn bộ data thô từ API
  List<dynamic> _categories = [];
  bool _isLoading = true;
  late final TodoService _todoService;

  // Filters
  int _selectedCategoryId = -1; // -1: Tất cả
  DateTime? _selectedDate; // Null: Tất cả ngày

  @override
  void initState() {
    super.initState();
    _todoService = TodoService();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchCategories(),
      _fetchTodos(),
    ]);
  }

  Future<void> _fetchCategories() async {
    try {
      final client = ApiClient(widget.prefs);
      final res =
          await client.get('${AppConstants.categoriesEndpoint}?type=todo');
      if (res.data['success']) {
        if (mounted) {
          setState(() {
            _categories = [
              {'id': -1, 'name': 'Tất cả'},
              ...res.data['data']
            ];
          });
        }
      }
    } catch (e) {
      print('Lỗi tải danh mục: $e');
    }
  }

  Future<void> _fetchTodos() async {
    if (_allTodos.isEmpty) setState(() => _isLoading = true);
    try {
      final rows = await _todoService.getLocalTodos();
      // Normalize for UI: convert tags string -> List<String>, is_completed int->bool
      final normalized = rows.map((m) {
        final map = Map<String, dynamic>.from(m);
        final tags = map['tags'];
        if (tags is String) {
          map['tags'] = tags.isEmpty
              ? <String>[]
              : tags.split(',').map((e) => e.trim()).toList();
        }
        final ic = map['is_completed'];
        if (ic is int) map['is_completed'] = ic == 1;
        final idel = map['is_deleted'];
        if (idel is int) map['is_deleted'] = idel == 1;
        return map;
      }).toList();

      if (mounted) {
        setState(() {
          _allTodos = normalized;
          _isLoading = false;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Lỗi tải todos local: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC NHÓM VÀ SẮP XẾP ---
  Map<String, List<dynamic>> _processTodos() {
    // 1. Lọc dữ liệu
    List<dynamic> filtered = _allTodos.where((todo) {
      // Lọc theo Danh mục
      bool catMatch = true;
      if (_selectedCategoryId != -1) {
        String filterName = _categories
            .firstWhere((c) => c['id'] == _selectedCategoryId)['name'];
        List tags = todo['tags'] is List ? todo['tags'] : [];
        catMatch = tags.contains(filterName);
      }

      // Lọc theo Ngày (nếu user chọn ngày cụ thể)
      bool dateMatch = true;
      if (_selectedDate != null && todo['due_date'] != null) {
        DateTime due = DateTime.parse(todo['due_date']).toLocal();
        dateMatch = isSameDay(due, _selectedDate!);
      } else if (_selectedDate != null && todo['due_date'] == null) {
        dateMatch = false; // Chọn ngày mà task ko có ngày -> ẩn
      }

      return catMatch && dateMatch;
    }).toList();

    // 2. Phân nhóm
    Map<String, List<dynamic>> groups = {
      'today': [],
      'future': [],
      'past': [],
      'no_date': []
    };

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    for (var todo in filtered) {
      if (todo['due_date'] == null) {
        groups['no_date']!.add(todo);
        continue;
      }

      DateTime due = DateTime.parse(todo['due_date']).toLocal();
      if (due.isBefore(todayStart)) {
        groups['past']!.add(todo);
      } else if (due.isBefore(tomorrowStart)) {
        groups['today']!.add(todo);
      } else {
        groups['future']!.add(todo);
      }
    }

    // 3. Sắp xếp nội bộ từng nhóm
    // Today: Theo giờ
    groups['today']!.sort((a, b) => a['due_date'].compareTo(b['due_date']));
    // Future: Tăng dần (gần nhất trước)
    groups['future']!.sort((a, b) => a['due_date'].compareTo(b['due_date']));
    // Past: Giảm dần (mới quá hạn nhất lên đầu) hoặc Tăng dần tuỳ ý
    groups['past']!.sort((a, b) => b['due_date'].compareTo(a['due_date']));

    return groups;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // --- LOGIC XỬ LÝ SỰ KIỆN ---

  Future<void> _toggleTodoStatus(dynamic todo) async {
    final currentStatus = todo['is_completed'] == true;
    final newStatus = !currentStatus;
    final reminderTimeStr = todo['reminder_time'];

    // Update UI ngay
    setState(() {
      todo['is_completed'] = newStatus;
    });

    // Check nhắc nhở quá hạn
    if (!newStatus && reminderTimeStr != null) {
      final reminderTime = DateTime.parse(reminderTimeStr).toLocal();
      if (reminderTime.isBefore(DateTime.now())) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⚠️ Nhắc nhở quá hạn'),
            content: Text(
                'Hạn nhắc (${DateFormat('HH:mm dd/MM').format(reminderTime)}) đã trôi qua.\nBạn có muốn đặt lại giờ không?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Không')),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _editTodo(todo);
                },
                child: const Text('Đặt lại'),
              ),
            ],
          ),
        );
      }
    }

    // Local update via TodoService using client_id
    try {
      final String clientId = todo['client_id'];
      await _todoService.updateTodoLocal(clientId, {
        'is_completed': newStatus,
      });
    } catch (e) {
      // Optionally revert UI on failure
    }
  }

  Future<void> _editTodo(dynamic todoMap) async {
    final todoObj = Todo.fromJson(todoMap);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TodoFormScreen(prefs: widget.prefs, todo: todoObj),
      ),
    );
    if (result == true) _fetchTodos();
  }

  Future<void> _deleteTodo(String clientId) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa công việc?'),
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
        await _todoService.deleteTodoLocal(clientId);
        setState(() {
          _allTodos.removeWhere((t) => t['client_id'] == clientId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Đã xóa')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  // --- MÀU SẮC ƯU TIÊN ---
  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return const Color.fromARGB(255, 185, 13, 30); // Đỏ nhạt
      case 'medium':
        return const Color.fromARGB(255, 231, 189, 50); // Vàng/Cam nhạt
      case 'low':
        return const Color.fromARGB(255, 48, 177, 52); // Xanh lá nhạt
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _processTodos();
    final hasData = groups['today']!.isNotEmpty ||
        groups['future']!.isNotEmpty ||
        groups['past']!.isNotEmpty ||
        groups['no_date']!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Công việc của tôi')),
      body: Column(
        children: [
          // 1. THANH LỌC DANH MỤC
          SizedBox(
            height: 50,
            child: _categories.isEmpty
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _categories.length,
                    itemBuilder: (ctx, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategoryId == cat['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat['name']),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategoryId = cat['id']);
                            }
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                        ),
                      );
                    },
                  ),
          ),

          // 2. THANH LỌC NGÀY (Nằm dưới danh mục)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
              border: Border(
                top: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1)),
                bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_list,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6)),
                const SizedBox(width: 8),
                Text(
                  "Lọc ngày: ",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_selectedDate == null)
                  TextButton(
                    onPressed: _pickDateFilter,
                    child: const Text("Tất cả"),
                  )
                else
                  Chip(
                    label:
                        Text(DateFormat('dd/MM/yyyy').format(_selectedDate!)),
                    onDeleted: () => setState(() => _selectedDate = null),
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                  ),
                const Spacer(),
                if (_selectedDate == null)
                  IconButton(
                    icon: Icon(Icons.calendar_month,
                        color: Theme.of(context).colorScheme.primary),
                    onPressed: _pickDateFilter,
                  )
              ],
            ),
          ),

          // 3. DANH SÁCH CÔNG VIỆC (Đã phân nhóm)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !hasData
                    ? const Center(child: Text('Không có công việc nào'))
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 80),
                        children: [
                          if (groups['today']!.isNotEmpty) ...[
                            _buildSectionHeader('Hôm nay', Colors.blue),
                            ...groups['today']!.map((t) => _buildTodoItem(t)),
                          ],
                          if (groups['future']!.isNotEmpty) ...[
                            _buildSectionHeader('Sắp tới', Colors.indigo),
                            ...groups['future']!.map((t) => _buildTodoItem(t)),
                          ],
                          if (groups['no_date']!.isNotEmpty) ...[
                            _buildSectionHeader('Chưa đặt ngày', Colors.grey),
                            ...groups['no_date']!.map((t) => _buildTodoItem(t)),
                          ],
                          if (groups['past']!.isNotEmpty) ...[
                            _buildSectionHeader('Đã qua (Quá hạn)', Colors.red),
                            ...groups['past']!.map((t) => _buildTodoItem(t)),
                          ],
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TodoFormScreen(prefs: widget.prefs)),
          );
          if (result == true) _fetchTodos();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _pickDateFilter() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const Expanded(child: Divider(indent: 10, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildTodoItem(dynamic todo) {
    final isDone = todo['is_completed'] == true;
    final bgColor = _getPriorityColor(todo['priority']);

    // Tên danh mục (lấy từ tags)
    String catName = 'Chung';
    if (todo['tags'] != null && (todo['tags'] as List).isNotEmpty) {
      catName = (todo['tags'] as List).first.toString();
    }

    return Card(
      color: isDone
          ? Colors.grey[200]
          : bgColor, // Nếu xong thì màu xám, chưa xong thì màu ưu tiên
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TodoDetailScreen(
                  prefs: widget.prefs, clientId: todo['client_id']),
            ),
          );
          if (result == true) _fetchTodos();
        },
        // Checkbox
        leading: Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: isDone,
            activeColor: Colors.green,
            shape: const CircleBorder(),
            onChanged: (v) => _toggleTodoStatus(todo),
          ),
        ),
        // Nội dung
        title: Text(
          todo['title'],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? Colors.grey : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (todo['description'] != null && todo['description'].isNotEmpty)
              Text(todo['description'],
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              children: [
                // Badge Danh mục
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Text(
                    catName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54),
                  ),
                ),
                const SizedBox(width: 8),
                // Ngày hạn
                if (todo['due_date'] != null) ...[
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[700]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM HH:mm')
                        .format(DateTime.parse(todo['due_date']).toLocal()),
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500),
                  ),
                ]
              ],
            ),
          ],
        ),
        // Menu 3 chấm
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'edit') {
              _editTodo(todo);
            } else if (value == 'delete') {
              _deleteTodo(todo['client_id']);
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit, color: Colors.blue),
                SizedBox(width: 8),
                Text('Sửa')
              ]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Xóa')
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
