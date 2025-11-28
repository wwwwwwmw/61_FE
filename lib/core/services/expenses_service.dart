import '../constants/app_constants.dart';
import '../network/api_client.dart';

class ExpensesService {
  final ApiClient _apiClient;
  ExpensesService(this._apiClient);

  Future<Map<String, dynamic>> getExpenses({
    String? type,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    bool includeDeleted = false,
  }) async {
    final query = <String, dynamic>{};
    if (type != null) query['type'] = type;
    if (categoryId != null) query['category_id'] = categoryId;
    if (startDate != null) query['start_date'] = startDate.toIso8601String();
    if (endDate != null) query['end_date'] = endDate.toIso8601String();
    if (includeDeleted) query['includeDeleted'] = 'true';
    final res = await _apiClient.get(
      AppConstants.expensesEndpoint,
      queryParameters: query,
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    final res = await _apiClient.post(
      AppConstants.expensesEndpoint,
      data: data,
    );
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<Map<String, dynamic>> updateExpense(
    String id,
    Map<String, dynamic> data,
  ) async {
    final res = await _apiClient.put(
      '${AppConstants.expensesEndpoint}/$id',
      data: data,
    );
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<void> deleteExpense(String id, {bool permanent = false}) async {
    await _apiClient.delete(
      '${AppConstants.expensesEndpoint}/$id',
      queryParameters: {if (permanent) 'permanent': 'true'},
    );
  }

  Future<Map<String, dynamic>> getStatistics({
    String period = 'monthly',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, dynamic>{'period': period};
    if (startDate != null) query['start_date'] = startDate.toIso8601String();
    if (endDate != null) query['end_date'] = endDate.toIso8601String();
    final res = await _apiClient.get(
      '${AppConstants.expensesEndpoint}/statistics',
      queryParameters: query,
    );
    return Map<String, dynamic>.from(res.data['data']);
  }
}
