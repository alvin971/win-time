import 'package:equatable/equatable.dart';
import '../enums/user_role.dart';

/// Entité représentant un utilisateur de la plateforme Win Time
class UserEntity extends Equatable {
  /// Identifiant unique de l'utilisateur
  final String id;

  /// Adresse email de l'utilisateur
  final String email;

  /// Prénom de l'utilisateur
  final String firstName;

  /// Nom de famille de l'utilisateur
  final String lastName;

  /// Numéro de téléphone (optionnel)
  final String? phoneNumber;

  /// URL de l'image de profil (optionnel)
  final String? profileImageUrl;

  /// Rôle de l'utilisateur dans la plateforme
  final UserRole role;

  /// Indique si le compte est actif
  final bool isActive;

  /// Indique si l'email est vérifié
  final bool isEmailVerified;

  /// Date de création du compte
  final DateTime createdAt;

  /// Date de la dernière connexion (optionnel)
  final DateTime? lastLoginAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.profileImageUrl,
    required this.role,
    this.isActive = true,
    this.isEmailVerified = false,
    required this.createdAt,
    this.lastLoginAt,
  });

  /// Retourne le nom complet de l'utilisateur
  String get fullName => '$firstName $lastName';

  /// Retourne les initiales de l'utilisateur
  String get initials {
    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$firstInitial$lastInitial';
  }

  /// Vérifie si l'utilisateur est un client
  bool get isClient => role == UserRole.client;

  /// Vérifie si l'utilisateur est un membre de restaurant
  bool get isRestaurantUser => role.isRestaurantUser;

  /// Vérifie si l'utilisateur est un admin
  bool get isAdmin => role == UserRole.admin;

  /// Crée une copie de l'entité avec des valeurs modifiées
  UserEntity copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? profileImageUrl,
    UserRole? role,
    bool? isActive,
    bool? isEmailVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        firstName,
        lastName,
        phoneNumber,
        profileImageUrl,
        role,
        isActive,
        isEmailVerified,
        createdAt,
        lastLoginAt,
      ];
}
