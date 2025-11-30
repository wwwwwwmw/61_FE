import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import 'category_form_screen.dart';

class CategoryListScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const CategoryListScreen({super.key, required this.prefs});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final client = ApiClient(widget.prefs);
      final res = await client.get(AppConstants.categoriesEndpoint);
      if (res.data['success']) {
        setState(() {
          _categories = res.data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCategory(int id) async {
    try {
      final client = ApiClient(widget.prefs);
      await client.delete('${AppConstants.categoriesEndpoint}/$id');
      _fetchCategories();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã xóa danh mục')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa danh mục đang dùng')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Danh mục')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (ctx, index) {
                final cat = _categories[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _parseColor(cat['color']),
                    child: const Icon(Icons.folder, color: Colors.white),
                  ),
                  title: Text(cat['name']),
                  subtitle: Text(cat['type'] == 'both'
                      ? 'Chung'
                      : (cat['type'] == 'expense' ? 'Chi tiêu' : 'Công việc')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          final res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryFormScreen(
                                  prefs: widget.prefs, category: cat),
                            ),
                          );
                          if (res == true) _fetchCategories();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCategory(cat['id']),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryFormScreen(prefs: widget.prefs),
            ),
          );
          if (res == true) _fetchCategories();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _parseColor(String? hexString) {
    if (hexString == null) return AppColors.primary;
    try {
      return Color(int.parse(hexString.replaceAll('#', '0xFF')));
    } catch (e) {
      return AppColors.primary;
    }
  }
}
