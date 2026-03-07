class AdminDashboard {
  final int totalServices;
  final int completedServices;
  final int inProgressServices;
  final int pendingServices;
  final int totalCustomers;
  final int pendingBookings;
  final double totalRevenue;
  final double paidRevenue;
  final List<dynamic> recentServices;
  final List<dynamic> lowStockParts;

  AdminDashboard({
    this.totalServices = 0,
    this.completedServices = 0,
    this.inProgressServices = 0,
    this.pendingServices = 0,
    this.totalCustomers = 0,
    this.pendingBookings = 0,
    this.totalRevenue = 0,
    this.paidRevenue = 0,
    this.recentServices = const [],
    this.lowStockParts = const [],
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    return AdminDashboard(
      totalServices:
          int.tryParse(json['total_services']?.toString() ?? '0') ?? 0,
      completedServices:
          int.tryParse(json['completed_services']?.toString() ?? '0') ?? 0,
      inProgressServices:
          int.tryParse(json['in_progress_services']?.toString() ?? '0') ?? 0,
      pendingServices:
          int.tryParse(json['pending_services']?.toString() ?? '0') ?? 0,
      totalCustomers:
          int.tryParse(json['total_customers']?.toString() ?? '0') ?? 0,
      pendingBookings:
          int.tryParse(json['pending_bookings']?.toString() ?? '0') ?? 0,
      totalRevenue:
          double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0,
      paidRevenue:
          double.tryParse(json['paid_revenue']?.toString() ?? '0') ?? 0,
      recentServices: json['recent_services'] ?? [],
      lowStockParts: json['low_stock_parts'] ?? [],
    );
  }
}

class CustomerDashboard {
  final int totalBookings;
  final int totalServices;
  final int pendingCount;
  final int completedCount;
  final List<dynamic> recentServices;

  CustomerDashboard({
    this.totalBookings = 0,
    this.totalServices = 0,
    this.pendingCount = 0,
    this.completedCount = 0,
    this.recentServices = const [],
  });

  factory CustomerDashboard.fromJson(Map<String, dynamic> json) {
    return CustomerDashboard(
      totalBookings:
          int.tryParse(json['total_bookings']?.toString() ?? '0') ?? 0,
      totalServices:
          int.tryParse(json['total_services']?.toString() ?? '0') ?? 0,
      pendingCount:
          int.tryParse(json['pending_count']?.toString() ?? '0') ?? 0,
      completedCount:
          int.tryParse(json['completed_count']?.toString() ?? '0') ?? 0,
      recentServices: json['recent_services'] ?? [],
    );
  }
}
