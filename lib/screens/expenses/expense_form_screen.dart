import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';

class ExpenseFormScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final dynamic expense; // Map hoặc Expense
  const ExpenseFormScreen({super.key, required this.prefs, this.expense});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;
  String _type = 'expense';
  int? _categoryId;
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.expense != null) {
      final amt = widget.expense is Map
          ? widget.expense['amount']
          : widget.expense.amount;
      final desc = widget.expense is Map
          ? widget.expense['description']
          : widget.expense.description;
      final type =
          widget.expense is Map ? widget.expense['type'] : widget.expense.type;
      _amountController.text = amt.toString();
      _descController.text = desc ?? '';
      _type = (type == 'income') ? 'income' : 'expense';
      _categoryId = widget.expense is Map
          ? widget.expense['category_id']
          : int.tryParse(widget.expense.categoryId ?? '');
      final dateRaw = widget.expense is Map
          ? widget.expense['date']
          : widget.expense.date.toIso8601String();
      try {
        _selectedDate = DateTime.parse(dateRaw.toString());
      } catch (_) {}
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final client = ApiClient(widget.prefs);
      final res =
          await client.get('${AppConstants.categoriesEndpoint}?type=expense');
      final data = (res.data is Map && res.data['data'] != null)
          ? res.data['data']
          : res.data;
      if (data is List) {
        setState(() {
          _categories = data;
          _isLoadingCategories = false;
          // Nếu chưa chọn, mặc định danh mục đầu tiên
          if (_categoryId == null && _categories.isNotEmpty) {
            _categoryId = _categories.first['id'];
          }
        });
      } else {
        setState(() => _isLoadingCategories = false);
      }
    } catch (_) {
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final client = ApiClient(widget.prefs); // [FIX]

      final data = <String, dynamic>{
        'amount': double.parse(_amountController.text),
        'type': _type,
        'category_id': _categoryId ??
            (_categories.isNotEmpty ? _categories.first['id'] : 1),
        'description': _descController.text,
        'date': _selectedDate.toIso8601String(),
        'payment_method': 'cash',
      };

      late final Response response;
      if (widget.expense == null) {
        response = await client.post(AppConstants.expensesEndpoint, data: data);
      } else {
        final id =
            widget.expense is Map ? widget.expense['id'] : widget.expense.id;
        response = await client.put('${AppConstants.expensesEndpoint}/$id',
            data: data);
      }

      if (response.data['success']) {
        if (widget.expense == null && response.data['budgetAlert'] != null) {
          final alert = response.data['budgetAlert'];
          if (mounted) {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(
                    alert['type'] == 'danger' ? '⚠️ Cảnh báo' : '🔔 Thông báo'),
                content: Text(alert['message']),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Đóng'))
                ],
              ),
            );
          }
        }
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.expense == null
              ? (_type == 'income' ? 'Thêm khoản thu' : 'Thêm khoản chi')
              : (_type == 'income' ? 'Sửa khoản thu' : 'Sửa khoản chi'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Type selector
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Chi'),
                      value: 'expense',
                      groupValue: _type,
                      onChanged: (v) => setState(() => _type = v ?? 'expense'),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Thu'),
                      value: 'income',
                      groupValue: _type,
                      onChanged: (v) => setState(() => _type = v ?? 'expense'),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Số tiền'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Nhập số tiền' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày giao dịch',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),
              // Chọn danh mục chi tiêu/thu nhập
              DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories
                    .map<DropdownMenuItem<int>>((cat) => DropdownMenuItem(
                          value: cat['id'],
                          child: Text(cat['name'] ?? 'Danh mục'),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _categoryId = val),
                hint: _isLoadingCategories
                    ? const Text('Đang tải danh mục...')
                    : const Text('Chọn danh mục'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveExpense,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
