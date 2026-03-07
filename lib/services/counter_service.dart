import '../config/api_config.dart';
import '../models/counter.dart';
import 'api_service.dart';

class CounterService {
  /// Get transactions for a specific date
  static Future<Map<String, dynamic>> getTransactions({
    required String date,
  }) async {
    final response = await ApiService.get(
      ApiConfig.counter,
      queryParams: {'action': 'transactions', 'date': date},
    );
    return response.success ? response.dataMap : {};
  }

  /// Get categories
  static Future<List<CounterCategory>> getCategories() async {
    final response = await ApiService.get(
      ApiConfig.counter,
      queryParams: {'action': 'categories'},
    );
    if (response.success) {
      final list = response.data['data'] ?? [];
      return (list as List).map((e) => CounterCategory.fromJson(e)).toList();
    }
    return [];
  }

  /// Get summary (daily/weekly/monthly)
  static Future<CounterSummary> getSummary({
    required String period,
    String? date,
  }) async {
    final params = <String, String>{'action': 'summary', 'period': period};
    if (date != null) params['date'] = date;

    final response =
        await ApiService.get(ApiConfig.counter, queryParams: params);
    if (response.success && response.data['data'] != null) {
      return CounterSummary.fromJson(response.data['data']);
    }
    return CounterSummary();
  }

  /// Get expenses
  static Future<List<CounterExpense>> getExpenses({String? date}) async {
    final params = <String, String>{'action': 'expenses'};
    if (date != null) params['date'] = date;

    final response =
        await ApiService.get(ApiConfig.counter, queryParams: params);
    if (response.success) {
      final list = response.data['data'] ?? [];
      return (list as List).map((e) => CounterExpense.fromJson(e)).toList();
    }
    return [];
  }

  /// Create transaction
  static Future<ApiResponse> createTransaction(
      Map<String, dynamic> data) async {
    data['action'] = 'create_transaction';
    return await ApiService.post(ApiConfig.counter, body: data);
  }

  /// Create expense
  static Future<ApiResponse> createExpense(
      Map<String, dynamic> data) async {
    data['action'] = 'create_expense';
    return await ApiService.post(ApiConfig.counter, body: data);
  }

  /// Update transaction
  static Future<ApiResponse> updateTransaction(
      int id, Map<String, dynamic> data) async {
    data['id'] = id;
    data['action'] = 'update_transaction';
    return await ApiService.put(ApiConfig.counter, body: data);
  }

  /// Update expense
  static Future<ApiResponse> updateExpense(
      int id, Map<String, dynamic> data) async {
    data['id'] = id;
    data['action'] = 'update_expense';
    return await ApiService.put(ApiConfig.counter, body: data);
  }

  /// Delete transaction or expense
  static Future<ApiResponse> delete(int id, String type) async {
    return await ApiService.delete(
      ApiConfig.counter,
      body: {'id': id, 'type': type},
    );
  }

  /// Upload receipt image
  static Future<ApiResponse> uploadReceipt(String filePath) async {
    return await ApiService.uploadFile(
      ApiConfig.upload,
      filePath,
      fieldName: 'receipt',
    );
  }
}
