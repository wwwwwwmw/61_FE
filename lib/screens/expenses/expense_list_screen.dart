import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';

class ExpenseListScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const ExpenseListScreen({super.key, required this.prefs});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _expenses = [];
  final Map<int, String> _categoryNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ApiClient(widget.prefs);
      // Categories (for names)
      try {
        final cats =
            await api.get('${AppConstants.categoriesEndpoint}?type=expense');
        final data = (cats.data is Map && cats.data['data'] != null)
            ? cats.data['data']
            : cats.data;
        if (data is List) {
          for (final c in data) {
            if (c is Map && c['id'] != null) {
              _categoryNames[c['id']] = c['name'] ?? 'Danh mục';
            }
          }
        }
      } catch (_) {}

      // Expenses
      final res = await api.get(AppConstants.expensesEndpoint);
      final list = (res.data is Map && res.data['data'] != null)
          ? res.data['data']
          : res.data;
      if (list is List) {
        _expenses = List<Map<String, dynamic>>.from(list);
        // sort desc by date
        _expenses.sort((a, b) =>
            DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
      }
    } catch (e) {
      _error = 'Không thể tải danh sách giao dịch: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(num amount) {
    final fmt =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return fmt.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tất Cả Giao Dịch')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (ctx, index) {
                      // Group by day headers
                      final item = _expenses[index];
                      final currentDate = DateTime.parse(item['date']);
                      final currentKey =
                          DateFormat('dd/MM/yyyy').format(currentDate);

                      String? header;
                      if (index == 0) {
                        header = currentKey;
                      } else {
                        final prev =
                            DateTime.parse(_expenses[index - 1]['date']);
                        final prevKey = DateFormat('dd/MM/yyyy').format(prev);
                        if (prevKey != currentKey) header = currentKey;
                      }

                      final isIncome = (item['type'] == 'income');
                      final amountRaw = item['amount'];
                      final amount = amountRaw is num
                          ? amountRaw
                          : num.tryParse(amountRaw.toString()) ?? 0;
                      final catId = item['category_id'];
                      final catName = catId is int
                          ? (_categoryNames[catId] ?? 'Khác')
                          : 'Khác';

                      final tiles = <Widget>[];
                      if (header != null) {
                        tiles.add(Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(header,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ));
                      }

                      tiles.add(Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                (isIncome ? AppColors.success : AppColors.error)
                                    .withOpacity(0.1),
                            child: Icon(
                                isIncome
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: isIncome
                                    ? AppColors.success
                                    : AppColors.error),
                          ),
                          title: Text(item['description'] ?? 'Giao dịch',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Danh mục: $catName'),
                          trailing: Text(
                            '${isIncome ? '+' : '-'}${_formatCurrency(amount)}',
                            style: TextStyle(
                              color: isIncome
                                  ? AppColors.success
                                  : AppColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ));

                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: tiles);
                    },
                    itemCount: _expenses.length,
                  ),
                ),
    );
  }
}
