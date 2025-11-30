import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../features/expenses/domain/entities/expense.dart';
import 'expense_form_screen.dart';
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onDelete;
  final Function(Expense)? onUpdate;
  final SharedPreferences prefs;

  const ExpenseDetailScreen({
    super.key,
    required this.expense,
    required this.prefs,
    this.onDelete,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = expense.type == 'income';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giao dịch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExpenseFormScreen(
                    expense: expense,
                    prefs: prefs,
                  ),
                ),
              );
              if (result == true && onUpdate != null) {
                // Since we don't have the updated object here without fetching,
                // we might need to rely on the parent to refresh.
                // But for now let's just pop with true to indicate update.
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              }
            },
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Xác nhận xóa'),
                    content: const Text('Bạn có chắc muốn xóa giao dịch này?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () {
                          onDelete!();
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context)
                              .pop(true); // Close detail screen with result
                        },
                        child: const Text(
                          'Xóa',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Card
            Card(
              color: isIncome
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 48,
                      color: isIncome ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isIncome ? 'Thu nhập' : 'Chi tiêu',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color:
                                isIncome ? AppColors.success : AppColors.error,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatCurrency(expense.amount)} đ',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                isIncome ? AppColors.success : AppColors.error,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category
            if (expense.categoryId != null)
              _buildInfoRow(
                context,
                'Danh mục',
                expense.categoryId!, // TODO: Map ID to Name if needed
                icon: Icons.category,
              ),

            const Divider(height: 32),

            // Description
            if (expense.description != null &&
                expense.description!.isNotEmpty) ...[
              Text(
                'Mô tả',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                expense.description!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Divider(height: 32),
            ],

            // Date
            _buildInfoRow(
              context,
              'Ngày giao dịch',
              DateFormat('dd/MM/yyyy').format(expense.date),
              icon: Icons.calendar_today,
            ),

            const SizedBox(height: 16),

            // Payment method
            if (expense.paymentMethod != null)
              _buildInfoRow(
                context,
                'Phương thức thanh toán',
                expense.paymentMethod!,
                icon: Icons.payment,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Color? color,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color ?? AppColors.primary, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '', decimalDigits: 0)
        .format(amount);
  }
}
