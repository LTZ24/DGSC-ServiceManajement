import '../config/api_config.dart';
import '../models/booking.dart';
import 'api_service.dart';

class BookingService {
  /// Get bookings (admin: all, customer: own)
  static Future<List<Booking>> getBookings({
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) params['status'] = status;

    final response = await ApiService.get(ApiConfig.bookings, queryParams: params);
    if (response.success) {
      final list = response.data['data'] ?? response.data['bookings'] ?? [];
      return (list as List).map((e) => Booking.fromJson(e)).toList();
    }
    return [];
  }

  /// Create a new booking
  static Future<ApiResponse> createBooking(Map<String, dynamic> data) async {
    return await ApiService.post(ApiConfig.bookings, body: data);
  }

  /// Update booking status (admin)
  static Future<ApiResponse> updateBooking(int id, Map<String, dynamic> data) async {
    data['id'] = id;
    return await ApiService.put(ApiConfig.bookings, body: data);
  }

  /// Convert booking to service (admin)
  static Future<ApiResponse> convertToService(int bookingId) async {
    return await ApiService.put(ApiConfig.bookings, body: {
      'id': bookingId,
      'action': 'convert_to_service',
    });
  }

  /// Delete booking
  static Future<ApiResponse> deleteBooking(int id) async {
    return await ApiService.delete(ApiConfig.bookings, body: {'id': id});
  }
}
