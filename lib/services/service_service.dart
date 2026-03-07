import '../config/api_config.dart';
import '../models/service_record.dart';
import 'api_service.dart';

class ServiceService {
  /// Get services list (admin only)
  static Future<List<ServiceRecord>> getServices({
    String? search,
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null) params['status'] = status;

    final response =
        await ApiService.get(ApiConfig.services, queryParams: params);
    if (response.success) {
      final list = response.data['data'] ?? response.data['services'] ?? [];
      return (list as List).map((e) => ServiceRecord.fromJson(e)).toList();
    }
    return [];
  }

  /// Get single service by ID
  static Future<ServiceRecord?> getService(int id) async {
    final response = await ApiService.get(
      ApiConfig.services,
      queryParams: {'id': id.toString()},
    );
    if (response.success && response.data['data'] != null) {
      return ServiceRecord.fromJson(response.data['data']);
    }
    return null;
  }

  /// Create new service
  static Future<ApiResponse> createService(Map<String, dynamic> data) async {
    return await ApiService.post(ApiConfig.services, body: data);
  }

  /// Update service
  static Future<ApiResponse> updateService(
      int id, Map<String, dynamic> data) async {
    data['id'] = id;
    return await ApiService.put(ApiConfig.services, body: data);
  }

  /// Complete payment for service
  static Future<ApiResponse> completePayment(
      int id, String paymentMethod) async {
    return await ApiService.put(ApiConfig.services, body: {
      'id': id,
      'action': 'complete_payment',
      'payment_method': paymentMethod,
    });
  }

  /// Delete service
  static Future<ApiResponse> deleteService(int id) async {
    return await ApiService.delete(ApiConfig.services, body: {'id': id});
  }
}
