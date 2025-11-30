import 'package:dio/src/response.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

class CategoryFormScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final Map<String, dynamic>? category;

  const CategoryFormScreen({super.key, required this.prefs, this.category});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedType = 'both';
  String _selectedColor = '#3498db'; // Default Blue

  final List<Map<String, String>> _colors = [
    {'name': 'Blue', 'hex': '#3498db'},
    {'name': 'Red', 'hex': '#e74c3c'},
    {'name': 'Green', 'hex': '#2ecc71'},
    {'name': 'Yellow', 'hex': '#f1c40f'},
    {'name': 'Purple', 'hex': '#9b59b6'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!['name'];
      _selectedType = widget.category!['type'];
      _selectedColor = widget.category!['color'] ?? '#3498db';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final client = ApiClient(widget.prefs);
      final data = {
        'name': _nameController.text,
        'type': _selectedType,
        'color': _selectedColor,
        'icon': 'folder', // Default icon
      };

      late final Response response;
      if (widget.category == null) {
        response =
            await client.post(AppConstants.categoriesEndpoint, data: data);
      } else {
        response = await client.put(
            '${AppConstants.categoriesEndpoint}/${widget.category!['id']}',
            data: data);
      }

      if (response.data['success']) {
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title:
              Text(widget.category == null ? 'Thêm Danh mục' : 'Sửa Danh mục')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên danh mục'),
                validator: (v) => v!.isEmpty ? 'Nhập tên' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Loại'),
                items: const [
                  DropdownMenuItem(value: 'both', child: Text('Chung')),
                  DropdownMenuItem(value: 'todo', child: Text('Công việc')),
                  DropdownMenuItem(value: 'expense', child: Text('Chi tiêu')),
                ],
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedColor,
                decoration: const InputDecoration(labelText: 'Màu sắc'),
                items: _colors
                    .map((c) => DropdownMenuItem(
                          value: c['hex'],
                          child: Row(
                            children: [
                              Container(
                                  width: 20,
                                  height: 20,
                                  color: Color(int.parse(
                                      c['hex']!.replaceAll('#', '0xFF')))),
                              const SizedBox(width: 10),
                              Text(c['name']!),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedColor = v!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
