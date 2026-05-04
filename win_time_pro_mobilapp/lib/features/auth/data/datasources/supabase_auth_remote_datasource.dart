import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/config/wintime_supabase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/user_entity.dart' show UserRole;
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

/// Implémentation Supabase de [AuthRemoteDataSource].
///
/// Login : appelle `supabase.auth.signInWithPassword` puis fetch le profil
/// depuis `wintime.user_profiles` pour récupérer le rôle métier
/// (restaurantOwner / Manager / Staff / admin).
class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  final sb.SupabaseClient _client;

  SupabaseAuthRemoteDataSource(this._client);

  @override
  Future<({UserModel user, String accessToken, String refreshToken})> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = res.session;
      final authUser = res.user;
      if (session == null || authUser == null) {
        throw ServerException(message: 'Session Supabase vide après login');
      }
      final profile = await _fetchProfile(authUser.id);
      return (
        user: UserModel(
          id: authUser.id,
          email: authUser.email ?? email,
          firstName: (profile['first_name'] as String?) ?? '',
          lastName: (profile['last_name'] as String?) ?? '',
          phoneNumber: profile['phone_number'] as String?,
          profileImageUrl: profile['profile_image_url'] as String?,
          role: _roleFromString(profile['role'] as String?),
          isEmailVerified: authUser.emailConfirmedAt != null,
          createdAt: DateTime.parse(authUser.createdAt),
          lastLoginAt: DateTime.now(),
        ),
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
      );
    } on sb.AuthException catch (e) {
      throw AuthenticationException(message: e.message);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<({UserModel user, String accessToken, String refreshToken})> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required Map<String, dynamic> restaurantData,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phoneNumber,
          'app': 'wintime',
        },
      );
      final session = res.session;
      final authUser = res.user;
      if (authUser == null) {
        throw ServerException(message: 'Inscription échouée');
      }

      // Crée le profil métier (rôle = restaurantOwner par défaut au register)
      await _client
          .schema(WintimeSupabaseConfig.schema)
          .from('user_profiles')
          .upsert({
        'id': authUser.id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'role': UserRole.restaurantOwner.name,
        'is_active': true,
        'is_email_verified': authUser.emailConfirmedAt != null,
      });

      return (
        user: UserModel(
          id: authUser.id,
          email: email,
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
          role: UserRole.restaurantOwner,
          isEmailVerified: authUser.emailConfirmedAt != null,
          createdAt: DateTime.parse(authUser.createdAt),
          lastLoginAt: DateTime.now(),
        ),
        accessToken: session?.accessToken ?? '',
        refreshToken: session?.refreshToken ?? '',
      );
    } on sb.AuthException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    try {
      await _client.auth.signOut();
    } on sb.AuthException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  @override
  Future<String> refreshAccessToken({required String refreshToken}) async {
    // Supabase gère le refresh automatiquement en background ;
    // on retourne le current access token.
    final session = _client.auth.currentSession;
    if (session == null) {
      throw AuthenticationException(message: 'Pas de session active');
    }
    return session.accessToken;
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on sb.AuthException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _client.auth.updateUser(sb.UserAttributes(password: newPassword));
    } on sb.AuthException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  @override
  Future<void> verifyEmail({required String token}) async {
    // Supabase gère ça via deep links ; rien à faire ici côté API.
    return;
  }

  // ─── Helpers privés ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchProfile(String uid) async {
    final row = await _client
        .schema(WintimeSupabaseConfig.schema)
        .from('user_profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return row ?? <String, dynamic>{};
  }

  UserRole _roleFromString(String? raw) {
    if (raw == null) return UserRole.restaurantOwner;
    return UserRole.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => UserRole.restaurantOwner,
    );
  }
}
