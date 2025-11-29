import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/services/expenses_service.dart';
import '../../features/expenses/domain/entities/expense.dart';
import 'expense_form_screen.dart';
import 'expense_detail_screen.dart';
import 'expense_stats_screen.dart';

class ExpenseHomeScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const ExpenseHomeScreen({super.key, required this.prefs});

  @override
  State<ExpenseHomeScreen> createState() => _ExpenseHomeScreenState();
}

class _ExpenseHomeScreenState extends State<ExpenseHomeScreen> {
  bool _isLoading = true;
  double _totalIncome = 0;
  double _totalExpense = 0;
  List<Expense> _recentTransactions = [];
  late final ExpensesService _expensesService;

  @override
  void initState() {
    super.initState();
    _expensesService = ExpensesService(ApiClient(widget.prefs));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final data = await _expensesService.getExpenses();
      final List<dynamic> expensesData = data['data'] ?? []; // Assuming API returns { data: [...] } or similar
      // Adjust based on actual API response structure. 
      // If getExpenses returns Map<String, dynamic> from response.data, and response.data['data'] is the list.
      // Let's check getExpenses implementation again. 
      // It returns Map<String, dynamic>.from(res.data).
      // So if res.data is { success: true, data: [...] }, then data['data'] is the list.
      
      final List<Expense> expenses = expensesData
          .map((e) => Expense.fromJson(e))
          .toList();

      _calculateStats(expenses);
    } catch (e) {
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

    for (var item in expenses) {
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
                            // Navigate to all transactions (ExpenseListScreen) if implemented
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
        gradient: LinearGradient(
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
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Giao Dịch',
            _recentTransactions.length.toString(),
            Icons.receipt_long,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Trung Bình',
            _formatCurrency(
              _totalExpense /
                  (_recentTransactions.isEmpty
                      ? 1
                      : _recentTransactions.length),
            ),
            Icons.trending_down,
            Colors.orange,
          ),
        ),
      ],
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
                    await _expensesService.deleteExpense(transaction.id.toString());
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
