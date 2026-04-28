import 'package:equatable/equatable.dart';

enum UserRole { client, restaurant, admin }

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? phone;
  final String firstName;
  final String lastName;
  final UserRole role;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? lastLogin;

  const UserEntity({
    required this.id,
    required this.email,
    this.phone,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    this.lastLogin,
  });

  String get fullName => '$firstName $lastName';

  bool get isClient => role == UserRole.client;
  bool get isRestaurant => role == UserRole.restaurant;
  bool get isAdmin => role == UserRole.admin;

  @override
  List<Object?> get props => [
        id,
        email,
        phone,
        firstName,
        lastName,
        role,
        isActive,
        isVerified,
        createdAt,
        lastLogin,
      ];
}
