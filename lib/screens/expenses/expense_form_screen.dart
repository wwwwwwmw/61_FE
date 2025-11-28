import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/database/app_database.dart';

class ExpenseFormScreen extends StatefulWidget {
  final Map<String, dynamic>? expense;

  const ExpenseFormScreen({super.key, this.expense});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _type = 'expense';
  DateTime _date = DateTime.now();
  String _paymentMethod = 'cash';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _amountController.text = widget.expense!['amount'].toString();
      _descriptionController.text = widget.expense!['description'] ?? '';
      _type = widget.expense!['type'];
      _date = DateTime.parse(widget.expense!['date']);
      _paymentMethod = widget.expense!['payment_method'] ?? 'cash';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() => _date = date);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final now = DateTime.now();

      final expenseData = {
        'client_id': widget.expense?['client_id'] ?? const Uuid().v4(),
        'amount': amount,
        'type': _type,
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'date': _date.toIso8601String(),
        'payment_method': _paymentMethod,
        'created_at': widget.expense?['created_at'] ?? now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'is_deleted': 0,
        'is_synced': 0,
        'version': (widget.expense?['version'] ?? 0) + 1,
      };

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final expensesJson = prefs.getString('expenses') ?? '[]';
        final List<dynamic> expenses = json.decode(expensesJson);

        if (widget.expense == null) {
          expenses.add(expenseData);
        } else {
          final index = expenses.indexWhere(
            (e) => e['client_id'] == widget.expense!['client_id'],
          );
          if (index != -1) {
            expenses[index] = expenseData;
          }
        }

        await prefs.setString('expenses', json.encode(expenses));
      } else {
        final db = await AppDatabase().database;
        if (widget.expense == null) {
          await db.insert('expenses', expenseData);
        } else {
          await db.update(
            'expenses',
            expenseData,
            where: 'client_id = ?',
            whereArgs: [widget.expense!['client_id']],
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expense == null
                  ? 'Đã thêm giao dịch'
                  : 'Đã cập nhật giao dịch',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
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
        title: Text(
          widget.expense == null ? 'Thêm Giao Dịch' : 'Sửa Giao Dịch',
        ),
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
            IconButton(icon: const Icon(Icons.check), onPressed: _saveExpense),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward, size: 16),
                            SizedBox(width: 4),
                            Text('Chi Tiêu'),
                          ],
                        ),
                        selected: _type == 'expense',
                        onSelected: (selected) {
                          if (selected) setState(() => _type = 'expense');
                        },
                        selectedColor: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward, size: 16),
                            SizedBox(width: 4),
                            Text('Thu Nhập'),
                          ],
                        ),
                        selected: _type == 'income',
                        onSelected: (selected) {
                          if (selected) setState(() => _type = 'income');
                        },
                        selectedColor: AppColors.success.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Số tiền *',
                hintText: 'Nhập số tiền',
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: '₫',
                labelStyle: TextStyle(
                  color: _type == 'income'
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập số tiền';
                }
                if (double.tryParse(value) == null) {
                  return 'Số tiền không hợp lệ';
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
                labelText: 'Mô tả *',
                hintText: 'Ví dụ: Ăn trưa, Tiền lương...',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập mô tả';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Payment Method
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Phương thức thanh toán',
                prefixIcon: Icon(Icons.payment),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Tiền mặt')),
                DropdownMenuItem(value: 'card', child: Text('Thẻ')),
                DropdownMenuItem(value: 'bank', child: Text('Chuyển khoản')),
                DropdownMenuItem(value: 'e-wallet', child: Text('Ví điện tử')),
              ],
              onChanged: (value) {
                setState(() => _paymentMethod = value!);
              },
            ),

            const SizedBox(height: 16),

            // Date
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Ngày giao dịch'),
                subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectDate,
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveExpense,
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
                label: Text(
                  widget.expense == null ? 'Thêm Giao Dịch' : 'Cập Nhật',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'income'
                      ? AppColors.success
                      : AppColors.error,
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
