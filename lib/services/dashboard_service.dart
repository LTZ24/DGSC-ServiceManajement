import '../config/api_config.dart';
import '../models/dashboard.dart';
import 'api_service.dart';

class DashboardService {
  /// Get admin dashboard data
  static Future<AdminDashboard> getAdminDashboard() async {
    final response = await ApiService.get(ApiConfig.dashboard);
    if (response.success) {
      return AdminDashboard.fromJson(response.dataMap);
    }
    return AdminDashboard();
  }

  /// Get customer dashboard data
  static Future<CustomerDashboard> getCustomerDashboard() async {
    final response = await ApiService.get(ApiConfig.dashboard);
    if (response.success) {
      return CustomerDashboard.fromJson(response.dataMap);
    }
    return CustomerDashboard();
  }
}
