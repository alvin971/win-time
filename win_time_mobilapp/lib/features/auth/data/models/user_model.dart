import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    super.phone,
    required super.firstName,
    required super.lastName,
    required super.role,
    required super.isActive,
    required super.isVerified,
    required super.createdAt,
    super.lastLogin,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      role: _parseRole(json['role'] as String? ?? 'client'),
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        'role': role.name,
        'is_active': isActive,
        'is_verified': isVerified,
        'created_at': createdAt.toIso8601String(),
        'last_login': lastLogin?.toIso8601String(),
      };

  static UserRole _parseRole(String value) {
    switch (value) {
      case 'restaurant':
        return UserRole.restaurant;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.client;
    }
  }
}
