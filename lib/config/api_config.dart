class ApiConfig {
  // Ganti dengan IP server Anda
  // Untuk emulator Android: 10.0.2.2
  // Untuk device fisik: gunakan IP LAN komputer
  static const String baseUrl = 'http://10.0.2.2/DGSC/api';

  // Endpoints
  static const String auth = '$baseUrl/auth.php';
  static const String bookings = '$baseUrl/bookings.php';
  static const String customers = '$baseUrl/customers.php';
  static const String dashboard = '$baseUrl/dashboard.php';
  static const String diagnosis = '$baseUrl/diagnosis.php';
  static const String services = '$baseUrl/services.php';
  static const String finance = '$baseUrl/finance.php';
  static const String spareParts = '$baseUrl/spare-parts.php';
  static const String counter = '$baseUrl/counter.php';
  static const String notifications = '$baseUrl/notifications.php';
  static const String storeSettings = '$baseUrl/store-settings.php';
  static const String upload = '$baseUrl/upload.php';
  static const String googleAuth = '$baseUrl/google-auth.php';
}
