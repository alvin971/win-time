import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/enums/user_role.dart';
import '_helpers.dart';

/// Mapper Firestore ↔ [UserEntity].
///
/// Le doc est stocké à `/users/{uid}` où `uid == FirebaseAuth.uid`.
class UserModel {
  static UserEntity fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    return UserEntity(
      id: snap.id,
      email: (data['email'] as String?) ?? '',
      firstName: (data['firstName'] as String?) ?? '',
      lastName: (data['lastName'] as String?) ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?,
      role: _roleFromString(data['role'] as String?),
      isActive: (data['isActive'] as bool?) ?? true,
      isEmailVerified: (data['isEmailVerified'] as bool?) ?? false,
      createdAt: ts(data['createdAt']) ?? DateTime.now(),
      lastLoginAt: ts(data['lastLoginAt']),
    );
  }

  static Map<String, dynamic> toFirestore(UserEntity user) {
    return {
      'email': user.email,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'phoneNumber': user.phoneNumber,
      'profileImageUrl': user.profileImageUrl,
      'role': user.role.name,
      'isActive': user.isActive,
      'isEmailVerified': user.isEmailVerified,
      'createdAt': Timestamp.fromDate(user.createdAt),
      'lastLoginAt': user.lastLoginAt != null
          ? Timestamp.fromDate(user.lastLoginAt!)
          : null,
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
