import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import này quan trọng
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../features/expenses/domain/entities/expense.dart'; // Import Expense entity

class ExpenseFormScreen extends StatefulWidget {
  final SharedPreferences prefs; // Thêm biến này
  final Expense? expense;        // Thêm biến này để hỗ trợ Edit

  // Cập nhật Constructor
  const ExpenseFormScreen({
    super.key, 
    required this.prefs, 
    this.expense
  });

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Fill data nếu là edit mode
    if (widget.expense != null) {
      _amountController.text = widget.expense!.amount.toString();
      _descController.text = widget.expense!.description ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // [SỬA LỖI] Truyền prefs vào ApiClient
      final client = ApiClient(widget.prefs);
      
      final data = {
        'amount': double.parse(_amountController.text),
        'type': 'expense',
        'category_id': 1, // Tạm thời hardcode, bạn nên làm dropdown chọn category
        'description': _descController.text,
        'date': DateTime.now().toIso8601String(),
        'payment_method': 'cash',
      };

      late final response;
      if (widget.expense == null) {
        // Create
        response = await client.post(AppConstants.expensesEndpoint, data: data);
      } else {
        // Update
        response = await client.put(
          '${AppConstants.expensesEndpoint}/${widget.expense!.id}', 
          data: data
        );
      }

      if (response.data['success']) {
        // Xử lý cảnh báo ngân sách (chỉ khi tạo mới)
        if (widget.expense == null && response.data['budgetAlert'] != null) {
          final alert = response.data['budgetAlert'];
          if (mounted) {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(
                  alert['type'] == 'danger' ? '⚠️ Cảnh báo' : '🔔 Thông báo',
                  style: TextStyle(
                    color: alert['type'] == 'danger' ? Colors.red : Colors.orange,
                  ),
                ),
                content: Text(alert['message']),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Đóng'),
                  )
                ],
              ),
            );
          }
        }
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Thêm khoản chi' : 'Sửa khoản chi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Số tiền'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Nhập số tiền' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.expense == null ? 'Lưu' : 'Cập nhật'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}