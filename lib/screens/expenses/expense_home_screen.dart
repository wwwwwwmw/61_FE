import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/database/app_database.dart';
import 'expense_form_screen.dart';
import 'expense_stats_screen.dart';

class ExpenseHomeScreen extends StatefulWidget {
  final SharedPreferences prefs;
  
  const ExpenseHomeScreen({Key? key, required this.prefs}) : super(key: key);

  @override
  State<ExpenseHomeScreen> createState() => _ExpenseHomeScreenState();
}

class _ExpenseHomeScreenState extends State<ExpenseHomeScreen> {
  bool _isLoading = true;
  double _totalIncome = 0;
  double _totalExpense = 0;
  List<Map<String, dynamic>> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      if (kIsWeb) {
        // Load from SharedPreferences for web
        final prefs = await SharedPreferences.getInstance();
        final expensesJson = prefs.getString('expenses') ?? '[]';
        final List<dynamic> expenses = json.decode(expensesJson);
        
        _calculateStats(expenses);
      } else {
        // Load from SQLite
        final db = await AppDatabase().database;
        final result = await db.query(
          'expenses',
          where: 'is_deleted = ?',
          whereArgs: [0],
          orderBy: 'date DESC',
          limit: 10,
        );
        
        _calculateStats(result);
      }
    } catch (e) {
      print('Error loading expenses: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateStats(List<dynamic> expenses) {
    double income = 0;
    double expense = 0;
    
    for (var item in expenses) {
      final amount = (item['amount'] is int) 
          ? (item['amount'] as int).toDouble()
          : (item['amount'] as double? ?? 0.0);
      
      if (item['type'] == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }
    
    setState(() {
      _totalIncome = income;
      _totalExpense = expense;
      _recentTransactions = expenses.take(10).cast<Map<String, dynamic>>().toList();
    });
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  Color _getTypeColor(String type) {
    return type == 'income' ? AppColors.success : AppColors.error;
  }

  IconData _getCategoryIcon(String? category) {
    // Simple icon mapping
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
                            // Navigate to all transactions
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
                    ..._recentTransactions.map((transaction) => 
                      _buildTransactionItem(transaction)
                    ).toList(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ExpenseFormScreen(),
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
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
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

  Widget _buildSummaryItem(String label, String amount, IconData icon, Color color) {
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
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
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
            _formatCurrency(_totalExpense / (_recentTransactions.isEmpty ? 1 : _recentTransactions.length)),
            Icons.trending_down,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final amount = (transaction['amount'] is int)
        ? (transaction['amount'] as int).toDouble()
        : (transaction['amount'] as double? ?? 0.0);
    final description = transaction['description'] as String? ?? 'Giao dịch';
    final date = DateTime.parse(transaction['date'] as String);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(type).withOpacity(0.1),
          child: Icon(
            _getCategoryIcon(transaction['category_id']?.toString()),
            color: _getTypeColor(type),
          ),
        ),
        title: Text(
          description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(DateFormat('dd/MM/yyyy').format(date)),
        trailing: Text(
          '${type == 'income' ? '+' : '-'}${_formatCurrency(amount)}',
          style: TextStyle(
            color: _getTypeColor(type),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () {
          // Navigate to transaction detail
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
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
