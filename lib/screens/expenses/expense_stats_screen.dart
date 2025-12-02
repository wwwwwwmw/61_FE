import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:ung_dung_tien_ich/core/constants/app_constants.dart';

import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/database/app_database.dart';
import '../../core/network/api_client.dart';
import '../../core/services/expenses_service.dart';

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
  List<Map<String, dynamic>> _allTransactions = [];
  Map<String, double> _categoryStats = {};
  final Map<int, String> _categoryNames = {};
  final Map<int, Color> _categoryColorsById = {};
  final Map<String, Color> _categoryColorsByName = {};
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

  // Local totals
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      // Optional: try to fetch categories for name mapping (best-effort)
      await _loadCategories();

      // Always read expenses locally for offline-first
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final expensesJson = prefs.getString('expenses') ?? '[]';
        final List<dynamic> expenses = json.decode(expensesJson);
        _allTransactions = expenses.cast<Map<String, dynamic>>();
        _processStats(_allTransactions);
      } else {
        final db = await AppDatabase().database;
        final result = await db.query(
          'expenses',
          where: 'is_deleted = ?',
          whereArgs: [0],
          orderBy: 'date DESC',
        );
        _allTransactions = result;
        _processStats(_allTransactions);
      }

      // Compute totals locally via service for the selected period
      final now = DateTime.now();
      final DateTime startDate;
      switch (_selectedPeriod) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          // Inclusive: today and 6 days before (e.g. 8/12 shows 2/12 - 8/12)
          startDate = DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 6));
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
      }
      final stats = await ExpensesService().getStatistics(
        startDate: startDate,
        endDate: now,
      );
      _totalIncome = (stats['totalIncome'] as num?)?.toDouble() ?? 0.0;
      _totalExpense = (stats['totalExpense'] as num?)?.toDouble() ?? 0.0;
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
        startDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default: // month
        startDate = DateTime(now.year, now.month, 1);
    }

    final filtered = allTransactions.where((t) {
      final date = DateTime.parse(t['date'] as String);
      final isInRange = !date.isBefore(startDate); // >= startDate
      return isInRange && t['type'] == 'expense';
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

  Future<void> _loadCategories() async {
    // Try API first; cache map id->name
    const cacheKeyNames = 'categories_cache_expense_map';
    const cacheKeyColors = 'categories_cache_expense_colors';
    try {
      final api = ApiClient(widget.prefs);
      final resp =
          await api.get('${AppConstants.categoriesEndpoint}?type=expense');
      final data = (resp.data is Map && resp.data['data'] != null)
          ? resp.data['data']
          : resp.data;
      if (data is List) {
        for (final c in data) {
          if (c is Map && c['id'] != null) {
            _categoryNames[c['id']] = c['name'] ?? 'Danh mục';
            final colorHex = (c['color'] ?? '#3498db').toString();
            final parsed = _parseColor(colorHex);
            _categoryColorsById[c['id']] = parsed;
            final name = _categoryNames[c['id']]!;
            _categoryColorsByName[name] = parsed;
          }
        }
        // Persist cache
        final namesForCache =
            _categoryNames.map((k, v) => MapEntry(k.toString(), v));
        await widget.prefs.setString(cacheKeyNames, jsonEncode(namesForCache));
        final colorsForCache = _categoryColorsById
            .map((k, v) => MapEntry(k.toString(), _colorToHex(v)));
        await widget.prefs
            .setString(cacheKeyColors, jsonEncode(colorsForCache));
        return;
      }
    } catch (_) {
      // ignore and fallback below
    }
    // Fallback to cache
    try {
      final cachedNames = widget.prefs.getString(cacheKeyNames);
      if (cachedNames != null && cachedNames.isNotEmpty) {
        final decoded = jsonDecode(cachedNames);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final id = int.tryParse(key);
            if (id != null) _categoryNames[id] = value.toString();
          });
        }
      }
      final cachedColors = widget.prefs.getString(cacheKeyColors);
      if (cachedColors != null && cachedColors.isNotEmpty) {
        final decoded = jsonDecode(cachedColors);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final id = int.tryParse(key);
            if (id != null) {
              final color = _parseColor(value.toString());
              _categoryColorsById[id] = color;
            }
          });
          // Build name->color map if names loaded
          _categoryColorsByName.clear();
          _categoryNames.forEach((id, name) {
            final color = _categoryColorsById[id];
            if (color != null) _categoryColorsByName[name] = color;
          });
        }
      }
    } catch (_) {}
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  double get _balance => _totalIncome - _totalExpense;

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

                // Summary Card
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
              // Reload to recompute local totals and filtered stats
              // ignore: discarded_futures
              _loadStats();
            });
          }
        },
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildTotalCard() {
    final balanceColor = _balance >= 0 ? AppColors.success : AppColors.error;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [balanceColor, balanceColor.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: balanceColor.withValues(alpha: 0.3),
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
            'Tổng Quan',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(_balance),
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
          // Date range display for clarity
          const SizedBox(height: 4),
          Text(
            _rangeLabel(),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thu nhập',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(_totalIncome),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Chi tiêu',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(_totalExpense),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rangeLabel() {
    final now = DateTime.now();
    DateTime start;
    switch (_selectedPeriod) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        break;
      case 'year':
        start = DateTime(now.year, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }
    final df = DateFormat('dd/MM');
    return '${df.format(start)} - ${df.format(now)}';
  }

  Widget _buildPieChart() {
    if (_categoryStats.isEmpty) return const SizedBox();

    final entries = _categoryStats.entries.toList();
    final totalForPie =
        _categoryStats.values.fold<double>(0.0, (a, b) => a + b);

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sections: entries.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final percentage =
                totalForPie == 0 ? 0 : (data.value / totalForPie * 100);

            final color = _categoryColorsByName[data.key] ??
                _chartColors[index % _chartColors.length];
            return PieChartSectionData(
              value: data.value,
              title: '${percentage.toStringAsFixed(1)}%',
              color: color,
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
    final totalForList =
        _categoryStats.values.fold<double>(0.0, (a, b) => a + b);

    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final percentage =
          totalForList == 0 ? 0 : (data.value / totalForList * 100);
      final color = _categoryColorsByName[data.key] ??
          _chartColors[index % _chartColors.length];

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

  Color _parseColor(String hex) {
    var clean = hex.replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    final value = int.tryParse(clean, radix: 16) ?? 0xFF3498DB;
    return Color(value);
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}';
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
