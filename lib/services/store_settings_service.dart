import '../config/api_config.dart';
import 'api_service.dart';

class StoreSettingsService {
  /// Get all store settings
  static Future<Map<String, dynamic>> getSettings() async {
    final response = await ApiService.get(ApiConfig.storeSettings);
    if (response.success) {
      return response.dataMap;
    }
    return {};
  }

  /// Update store settings
  static Future<ApiResponse> updateSettings(
      Map<String, dynamic> data) async {
    return await ApiService.post(ApiConfig.storeSettings, body: data);
  }
}
