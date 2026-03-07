import '../config/api_config.dart';
import '../models/spare_part.dart';
import 'api_service.dart';

class SparePartService {
  /// Get spare parts list
  static Future<List<SparePart>> getSpareParts({
    String? search,
    bool? lowStock,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (lowStock == true) params['low_stock'] = '1';

    final response =
        await ApiService.get(ApiConfig.spareParts, queryParams: params);
    if (response.success) {
      final list =
          response.data['data'] ?? response.data['spare_parts'] ?? [];
      return (list as List).map((e) => SparePart.fromJson(e)).toList();
    }
    return [];
  }

  /// Create spare part
  static Future<ApiResponse> createSparePart(
      Map<String, dynamic> data) async {
    return await ApiService.post(ApiConfig.spareParts, body: data);
  }

  /// Update spare part
  static Future<ApiResponse> updateSparePart(
      int id, Map<String, dynamic> data) async {
    data['id'] = id;
    return await ApiService.put(ApiConfig.spareParts, body: data);
  }

  /// Delete spare part
  static Future<ApiResponse> deleteSparePart(int id) async {
    return await ApiService.delete(ApiConfig.spareParts, body: {'id': id});
  }
}
