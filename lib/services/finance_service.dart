import '../config/api_config.dart';
import '../models/transaction.dart';
import 'api_service.dart';

class FinanceService {
  /// Get finance data (revenue summary + transactions)
  static Future<Map<String, dynamic>> getFinanceData({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) params['status'] = status;

    final response =
        await ApiService.get(ApiConfig.finance, queryParams: params);
    if (response.success) {
      return response.dataMap;
    }
    return {};
  }

  /// Get transactions list
  static Future<List<Transaction>> getTransactions({
    int page = 1,
    int limit = 10,
  }) async {
    final response = await ApiService.get(
      ApiConfig.finance,
      queryParams: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    if (response.success) {
      final list =
          response.data['transactions'] ?? response.data['data'] ?? [];
      return (list as List).map((e) => Transaction.fromJson(e)).toList();
    }
    return [];
  }

  /// Create transaction
  static Future<ApiResponse> createTransaction(
      Map<String, dynamic> data) async {
    return await ApiService.post(ApiConfig.finance, body: data);
  }

  /// Update payment status
  static Future<ApiResponse> updatePayment(
      int id, Map<String, dynamic> data) async {
    data['id'] = id;
    return await ApiService.put(ApiConfig.finance, body: data);
  }
}
