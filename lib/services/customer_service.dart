import '../config/api_config.dart';
import '../models/customer.dart';
import 'api_service.dart';

class CustomerService {
  /// Get customers list (admin) or own profile (customer)
  static Future<List<Customer>> getCustomers({
    String? search,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response =
        await ApiService.get(ApiConfig.customers, queryParams: params);
    if (response.success) {
      final data = response.data['data'] ?? response.data['customers'];
      if (data is List) {
        return data.map((e) => Customer.fromJson(e)).toList();
      }
      if (data is Map) {
        return [Customer.fromJson(Map<String, dynamic>.from(data))];
      }
    }
    return [];
  }

  /// Get single customer by ID
  static Future<Customer?> getCustomer(int id) async {
    final response = await ApiService.get(
      ApiConfig.customers,
      queryParams: {'id': id.toString()},
    );
    if (response.success && response.data['data'] != null) {
      return Customer.fromJson(response.data['data']);
    }
    return null;
  }

  /// Get own profile (customer)
  static Future<Customer?> getOwnProfile() async {
    final response = await ApiService.get(ApiConfig.customers);
    if (response.success) {
      final data = response.data['data'] ?? response.data;
      if (data is Map) {
        return Customer.fromJson(Map<String, dynamic>.from(data));
      }
    }
    return null;
  }

  /// Create customer (admin)
  static Future<ApiResponse> createCustomer(Map<String, dynamic> data) async {
    return await ApiService.post(ApiConfig.customers, body: data);
  }

  /// Update customer profile
  static Future<ApiResponse> updateCustomer(
      int id, Map<String, dynamic> data) async {
    data['id'] = id;
    return await ApiService.put(ApiConfig.customers, body: data);
  }

  /// Update own profile (customer)
  static Future<ApiResponse> updateOwnProfile(
      Map<String, dynamic> data) async {
    return await ApiService.put(ApiConfig.customers, body: data);
  }

  /// Request password change (customer)
  static Future<ApiResponse> requestPasswordChange(
      String newPassword) async {
    return await ApiService.post(
      '${ApiConfig.customers}?action=request_password_change',
      body: {'new_password': newPassword},
    );
  }

  /// Check pending password request
  static Future<Map<String, dynamic>?> checkPasswordRequest() async {
    final response = await ApiService.get(
      ApiConfig.customers,
      queryParams: {'action': 'check_password_request'},
    );
    if (response.success && response.data['data'] != null) {
      return Map<String, dynamic>.from(response.data['data']);
    }
    return null;
  }

  /// Delete customer (admin)
  static Future<ApiResponse> deleteCustomer(int id) async {
    return await ApiService.delete(ApiConfig.customers, body: {'id': id});
  }
}
