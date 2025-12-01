import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/services/expenses_service.dart';
import '../../features/expenses/domain/entities/expense.dart';
import '../../core/constants/app_constants.dart';
import 'expense_form_screen.dart';
import 'expense_detail_screen.dart';
import 'expense_stats_screen.dart';
import 'expense_list_screen.dart';

class ExpenseHomeScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const ExpenseHomeScreen({super.key, required this.prefs});

  @override
  State<ExpenseHomeScreen> createState() => _ExpenseHomeScreenState();
}

class _ExpenseHomeScreenState extends State<ExpenseHomeScreen> {
  bool _isLoading = true;
  String? _loadError;
  double _totalIncome = 0;
  double _totalExpense = 0;
  double? _monthlyBudget;
  String? _budgetAlert;
  List<Expense> _recentTransactions = [];
  late final ExpensesService _expensesService;

  @override
  void initState() {
    super.initState();
    _expensesService = ExpensesService(ApiClient(widget.prefs));
    _loadBudget();
    _loadData();
  }

  void _loadBudget() {
    final raw = widget.prefs.getString(AppConstants.monthlyBudgetKey);
    if (raw != null) {
      _monthlyBudget = double.tryParse(raw);
    }
  }

  Future<void> _setBudget() async {
    final controller = TextEditingController(
      text: _monthlyBudget?.toStringAsFixed(0) ?? '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ngân sách tháng'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Nhập số tiền (VND)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              Navigator.pop(ctx, v);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (result != null) {
      await widget.prefs
          .setString(AppConstants.monthlyBudgetKey, result.toString());
      setState(() {
        _monthlyBudget = result;
        _evaluateBudget();
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final data = await _expensesService.getExpenses();
      // Accept both {data: [...]} and direct list responses for robustness
      final dynamic raw = data['data'] ?? data;
      final List<dynamic> expensesData = raw is List ? raw : [];
      // Adjust based on actual API response structure.
      // If getExpenses returns Map<String, dynamic> from response.data, and response.data['data'] is the list.
      // Let's check getExpenses implementation again.
      // It returns Map<String, dynamic>.from(res.data).
      // So if res.data is { success: true, data: [...] }, then data['data'] is the list.

      final List<Expense> expenses =
          expensesData.map((e) => Expense.fromJson(e)).toList();

      _calculateStats(expenses);
      _loadError = null;
    } catch (e) {
      String message =
          'Không thể tải dữ liệu chi tiêu. Kiểm tra kết nối server.';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.unknown) {
          message = 'Không thể kết nối tới server tại ${AppConstants.baseUrl}.';
        } else if (e.response != null) {
          message = e.response?.data is Map<String, dynamic>
              ? (e.response?.data['message'] ?? message)
              : message;
        }
      }
      _loadError = message;
      // ignore: avoid_print
      print('Error loading expenses: $e');
      // Handle error (show snackbar, etc.)
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateStats(List<Expense> expenses) {
    double income = 0;
    double expense = 0;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    for (var item in expenses) {
      // Chỉ tính trong tháng hiện tại để phục vụ ngân sách tháng
      if (item.date.isBefore(monthStart)) continue;
      if (item.type == 'income') {
        income += item.amount;
      } else {
        expense += item.amount;
      }
    }

    // Sort by date descending
    expenses.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _totalIncome = income;
      _totalExpense = expense;
      _recentTransactions = expenses.take(10).toList();
    });
    _evaluateBudget();
  }

  void _evaluateBudget() {
    if (_monthlyBudget == null) {
      _budgetAlert = null;
      return;
    }
    // Net spending (expense - income) for month
    final net = _totalExpense - _totalIncome;
    if (net > _monthlyBudget!) {
      final diff = net - _monthlyBudget!;
      _budgetAlert = 'Vượt ngân sách tháng: +${_formatCurrency(diff)}';
    } else if ((_monthlyBudget! + _totalIncome - _totalExpense) < 0) {
      _budgetAlert = 'Ngân sách + Thu - Chi < 0 (cần xem lại).';
    } else {
      _budgetAlert = null;
    }
  }

  Future<void> _deleteExpense(Expense exp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content:
            Text('Bạn có chắc muốn xóa ${exp.description ?? 'giao dịch'}?'),
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
        await _expensesService.deleteExpense(exp.id.toString());
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Đã xóa giao dịch')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
        }
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  Color _getTypeColor(String type) {
    return type == 'income' ? AppColors.success : AppColors.error;
  }

  IconData _getCategoryIcon(String? category) {
    // Simple icon mapping - can be improved with a Category model/service
    switch (category) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_cart;
      case 'entertainment':
        return Icons.movie;
      case 'salary':
        return Icons.account_balance_wallet;
      default:
        return Icons.attach_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _totalIncome - _totalExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Chi Tiêu'),
        actions: [
          IconButton(
            tooltip: 'Đặt ngân sách tháng',
            icon: const Icon(Icons.account_balance),
            onPressed: _setBudget,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExpenseStatsScreen(prefs: widget.prefs),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_budgetAlert != null) ...[
                    Card(
                      color: AppColors.error.withOpacity(0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _budgetAlert!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton(
                              onPressed: _setBudget,
                              child: const Text('Sửa ngân sách'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_loadError != null) ...[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_loadError!)),
                            TextButton(
                              onPressed: _loadData,
                              child: const Text('Thử lại'),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Summary Card
                  _buildSummaryCard(balance),

                  const SizedBox(height: 24),

                  // Quick Stats
                  _buildQuickStats(),

                  const SizedBox(height: 24),

                  // Recent Transactions Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Giao Dịch Gần Đây',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_recentTransactions.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExpenseListScreen(
                                  prefs: widget.prefs,
                                ),
                              ),
                            );
                          },
                          child: const Text('Xem tất cả'),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Recent Transactions List
                  if (_recentTransactions.isEmpty)
                    _buildEmptyState()
                  else
                    ..._recentTransactions.map(
                      (transaction) => _buildTransactionItem(transaction),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseFormScreen(prefs: widget.prefs),
            ),
          );
          if (result == true) _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm giao dịch'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSummaryCard(double balance) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.primaryGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng Số Dư',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Thu Nhập',
                  _formatCurrency(_totalIncome),
                  Icons.arrow_upward,
                  Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  'Chi Tiêu',
                  _formatCurrency(_totalExpense),
                  Icons.arrow_downward,
                  Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    // Chỉ hiển thị thẻ số lượng giao dịch; bỏ thẻ "Trung Bình"
    return _buildStatCard(
      'Giao Dịch',
      _recentTransactions.length.toString(),
      Icons.receipt_long,
      Colors.blue,
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Expense transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(transaction.type).withOpacity(0.1),
          child: Icon(
            _getCategoryIcon(transaction.categoryId),
            color: _getTypeColor(transaction.type),
          ),
        ),
        title: Text(
          transaction.description ?? 'Giao dịch',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(DateFormat('dd/MM/yyyy').format(transaction.date)),
        trailing: Text(
          '${transaction.type == 'income' ? '+' : '-'}${_formatCurrency(transaction.amount)}',
          style: TextStyle(
            color: _getTypeColor(transaction.type),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseDetailScreen(
                expense: transaction,
                prefs: widget.prefs,
                onDelete: () async {
                  try {
                    await _expensesService
                        .deleteExpense(transaction.id.toString());
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi xóa: $e')),
                    );
                  }
                },
                onUpdate: (updatedExpense) {
                  // _loadData() will be called when returning from detail screen if we handle it there
                  // But here we pass a callback, or we can just reload when returning.
                },
              ),
            ),
          );

          if (result == true) {
            _loadData();
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có giao dịch nào',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhấn nút + để thêm giao dịch đầu tiên',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
