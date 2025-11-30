import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/database/app_database.dart';
import '../../core/network/api_client.dart';

class ExpenseStatsScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const ExpenseStatsScreen({super.key, required this.prefs});

  @override
  State<ExpenseStatsScreen> createState() => _ExpenseStatsScreenState();
}

class _ExpenseStatsScreenState extends State<ExpenseStatsScreen> {
  bool _isLoading = true;
  String _selectedPeriod = 'month'; // today, week, month, year
  List<Map<String, dynamic>> _transactions = [];
  Map<String, double> _categoryStats = {};
  final Map<int, String> _categoryNames = {};
  final List<Color> _chartColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      // Ưu tiên gọi API để có dữ liệu đồng bộ (bao gồm category_id)
      final api = ApiClient(widget.prefs);
      bool remoteLoaded = false;
      try {
        // Tải categories để map tên
        final catsResp = await api.get('/categories');
        final catsData = catsResp.data;
        if (catsData is List) {
          for (final c in catsData) {
            if (c is Map<String, dynamic> && c['id'] != null) {
              _categoryNames[c['id']] = c['name'] ?? 'Danh mục';
            }
          }
        }
        // Tải expenses (có thể cần tham số thời gian sau này)
        final expensesResp = await api.get('/expenses');
        final expensesData = expensesResp.data;
        if (expensesData is List) {
          _processStats(List<Map<String, dynamic>>.from(expensesData));
          remoteLoaded = true;
        }
      } catch (_) {
        remoteLoaded = false;
      }

      if (!remoteLoaded) {
        // Fallback: local storage / sqlite
        if (kIsWeb) {
          final prefs = await SharedPreferences.getInstance();
          final expensesJson = prefs.getString('expenses') ?? '[]';
          final List<dynamic> expenses = json.decode(expensesJson);
          _processStats(expenses.cast<Map<String, dynamic>>());
        } else {
          final db = await AppDatabase().database;
          final result = await db.query(
            'expenses',
            where: 'is_deleted = ?',
            whereArgs: [0],
            orderBy: 'date DESC',
          );
          _processStats(result);
        }
      }
    } catch (e) {
      print('Error loading stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _processStats(List<Map<String, dynamic>> allTransactions) {
    // Filter by period
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default: // month
        startDate = DateTime(now.year, now.month, 1);
    }

    final filtered = allTransactions.where((t) {
      final date = DateTime.parse(t['date'] as String);
      return date.isAfter(startDate) && t['type'] == 'expense';
    }).toList();

    // Calculate category stats
    final Map<String, double> stats = {};
    for (var transaction in filtered) {
      // Đặt tên danh mục theo category_id nếu có, fallback sang description
      String categoryName;
      if (transaction.containsKey('category_id') &&
          transaction['category_id'] != null) {
        final cid = transaction['category_id'];
        categoryName = _categoryNames[cid] ?? 'Khác';
      } else {
        categoryName = transaction['description'] as String? ?? 'Khác';
      }
      final amountRaw = transaction['amount'];
      final amount = amountRaw is int
          ? amountRaw.toDouble()
          : (amountRaw is double
              ? amountRaw
              : double.tryParse(amountRaw.toString()) ?? 0.0);
      stats[categoryName] = (stats[categoryName] ?? 0) + amount;
    }

    setState(() {
      _transactions = filtered;
      _categoryStats = stats;
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

  double get _totalExpense {
    return _categoryStats.values.fold(0, (sum, amount) => sum + amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thống Kê Chi Tiêu')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Period Selector
                _buildPeriodSelector(),

                const SizedBox(height: 24),

                // Total Expense Card
                _buildTotalCard(),

                const SizedBox(height: 24),

                // Pie Chart
                if (_categoryStats.isNotEmpty) ...[
                  Text(
                    'Chi Tiêu Theo Danh Mục',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildPieChart(),
                  const SizedBox(height: 24),
                ],

                // Category Breakdown
                if (_categoryStats.isNotEmpty) ...[
                  Text(
                    'Chi Tiết',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ..._buildCategoryList(),
                ] else
                  _buildEmptyState(),
              ],
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _buildPeriodChip('Hôm nay', 'today'),
            const SizedBox(width: 8),
            _buildPeriodChip('Tuần', 'week'),
            const SizedBox(width: 8),
            _buildPeriodChip('Tháng', 'month'),
            const SizedBox(width: 8),
            _buildPeriodChip('Năm', 'year'),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedPeriod = value;
              _loadStats();
            });
          }
        },
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.error, AppColors.error.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng Chi Tiêu',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(_totalExpense),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_transactions.length} giao dịch',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    if (_categoryStats.isEmpty) return const SizedBox();

    final entries = _categoryStats.entries.toList();

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sections: entries.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final percentage = (data.value / _totalExpense * 100);

            return PieChartSectionData(
              value: data.value,
              title: '${percentage.toStringAsFixed(1)}%',
              color: _chartColors[index % _chartColors.length],
              radius: 100,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  List<Widget> _buildCategoryList() {
    final entries = _categoryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final percentage = (data.value / _totalExpense * 100);
      final color = _chartColors[index % _chartColors.length];

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.category, color: color),
          ),
          title: Text(
            data.key,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('${percentage.toStringAsFixed(1)}% tổng chi tiêu'),
          trailing: Text(
            _formatCurrency(data.value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Chưa có dữ liệu',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Thêm giao dịch để xem thống kê',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
