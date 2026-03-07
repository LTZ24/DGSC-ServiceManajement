class User {
  final int id;
  final String username;
  final String email;
  final String? phone;
  final String role; // 'admin' or 'customer'
  final String? profilePicture;
  final String? googleId;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
    required this.role,
    this.profilePicture,
    this.googleId,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isCustomer => role == 'customer';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? 'customer',
      profilePicture: json['profile_picture'],
      googleId: json['google_id'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'role': role,
      'profile_picture': profilePicture,
      'google_id': googleId,
    };
  }
}
