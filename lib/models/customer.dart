class Customer {
  final int id;
  final int? userId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final int? totalServices;
  final DateTime? createdAt;

  Customer({
    required this.id,
    this.userId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.totalServices,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: json['user_id'] != null
          ? int.tryParse(json['user_id'].toString())
          : null,
      name: json['name'] ?? '',
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      totalServices: json['total_services'] != null
          ? int.tryParse(json['total_services'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      if (userId != null) 'user_id': userId,
    };
  }
}
