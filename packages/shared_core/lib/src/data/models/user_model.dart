import '../../domain/entities/user_entity.dart';
import '../../domain/enums/user_role.dart';
import '_helpers.dart';

/// Mapper Postgres ↔ [UserEntity].
///
/// Table : `wintime.user_profiles`. Colonnes en snake_case, mapping vers
/// les champs Dart en camelCase.
class UserModel {
  static UserEntity fromRow(Map<String, dynamic> row) {
    return UserEntity(
      id: row['id'] as String,
      email: (row['email'] as String?) ?? '',
      firstName: (row['first_name'] as String?) ?? '',
      lastName: (row['last_name'] as String?) ?? '',
      phoneNumber: row['phone_number'] as String?,
      profileImageUrl: row['profile_image_url'] as String?,
      role: _roleFromString(row['role'] as String?),
      isActive: (row['is_active'] as bool?) ?? true,
      isEmailVerified: (row['is_email_verified'] as bool?) ?? false,
      createdAt: ts(row['created_at']) ?? DateTime.now(),
      lastLoginAt: ts(row['last_login_at']),
    );
  }

  /// Sérialise pour `INSERT` ou `UPSERT` dans `wintime.user_profiles`.
  /// Le caller est responsable de ne PAS envoyer ce que Postgres calcule
  /// (ex : `created_at` à l'insert, mais OK à l'update).
  static Map<String, dynamic> toRow(UserEntity user) {
    return {
      'id': user.id,
      'email': user.email,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'phone_number': user.phoneNumber,
      'profile_image_url': user.profileImageUrl,
      'role': user.role.name,
      'is_active': user.isActive,
      'is_email_verified': user.isEmailVerified,
      'last_login_at': tsString(user.lastLoginAt),
    };
  }

  static UserRole _roleFromString(String? raw) {
    if (raw == null) return UserRole.client;
    return UserRole.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => UserRole.client,
    );
  }
}
