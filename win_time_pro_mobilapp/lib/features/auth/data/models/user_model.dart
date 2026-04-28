import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.firstName,
    required super.lastName,
    super.phoneNumber,
    super.profileImageUrl,
    required super.createdAt,
    super.lastLoginAt,
    required super.isEmailVerified,
    required super.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      phoneNumber: json['phone_number'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      role: _parseRole(json['role'] as String? ?? 'restaurant_owner'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'profile_image_url': profileImageUrl,
        'created_at': createdAt.toIso8601String(),
        'last_login_at': lastLoginAt?.toIso8601String(),
        'is_email_verified': isEmailVerified,
        'role': _roleToString(role),
      };

  static UserRole _parseRole(String value) {
    switch (value) {
      case 'restaurant_manager':
        return UserRole.restaurantManager;
      case 'restaurant_staff':
        return UserRole.restaurantStaff;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.restaurantOwner;
    }
  }

  static String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.restaurantManager:
        return 'restaurant_manager';
      case UserRole.restaurantStaff:
        return 'restaurant_staff';
      case UserRole.admin:
        return 'admin';
      case UserRole.restaurantOwner:
        return 'restaurant_owner';
    }
  }
}
