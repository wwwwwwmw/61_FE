import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  // ... các biến khác

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Gọi API trực tiếp (hoặc qua Service)
      final client = ApiClient(); 
      final res = await client.post(AppConstants.expensesEndpoint, data: {
        'amount': double.parse(_amountController.text),
        'type': 'expense',
        'category_id': 1, // Thay bằng ID chọn từ UI
        'description': _descController.text,
        'date': DateTime.now().toIso8601String(),
      });

      if (res.data['success']) {
        // --- XỬ LÝ CẢNH BÁO NGÂN SÁCH ---
        final alert = res.data['budgetAlert'];
        if (alert != null && mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                alert['type'] == 'danger' ? '⚠️ Cảnh báo vượt ngân sách!' : '🔔 Chú ý',
                style: TextStyle(
                  color: alert['type'] == 'danger' ? Colors.red : Colors.orange,
                ),
              ),
              content: Text(alert['message']),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Đã hiểu'),
                )
              ],
            ),
          );
        }
        
        if (mounted) Navigator.pop(context, true); // Về màn hình trước
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm khoản chi')),
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
                validator: (v) => v!.isEmpty ? 'Nhập số tiền' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Lưu chi tiêu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}