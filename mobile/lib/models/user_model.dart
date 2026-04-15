class User {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatar;
  final String? address;
  final DateTime createdAt;
  final bool isVerified;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatar,
    this.address,
    required this.createdAt,
    this.isVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      address: json['address'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'avatar': avatar,
      'address': address,
      'created_at': createdAt.toIso8601String(),
      'is_verified': isVerified,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? avatar,
    String? address,
    DateTime? createdAt,
    bool? isVerified,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
