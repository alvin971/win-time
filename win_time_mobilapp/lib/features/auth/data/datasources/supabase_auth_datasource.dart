import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/wintime_supabase_config.dart';

/// Wrapper minimal pour les appels Supabase Auth côté Client.
///
/// Pour ce checkpoint Phase 5, on expose directement les méthodes utilisées
/// par les pages (login, signOut, currentUser). Le pattern complet
/// AuthRepository / Either<Failure, ...> sera réintroduit plus tard si besoin.
class SupabaseAuthDataSource {
  final SupabaseClient _client;
  SupabaseAuthDataSource(this._client);

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Connexion par email/password. Throw [AuthException] en cas d'échec.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Inscription. Crée également un row `wintime.user_profiles` avec rôle
  /// `client` (déclenché côté serveur ou ici en best-effort).
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'app': 'wintime',
      },
    );
    final user = res.user;
    if (user != null) {
      await _client
          .schema(WintimeSupabaseConfig.schema)
          .from('user_profiles')
          .upsert({
        'id': user.id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': 'client',
        'is_active': true,
        'is_email_verified': false,
      });
    }
    return res;
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Récupère le profil métier (`wintime.user_profiles`) du user connecté.
  /// Retourne null si pas connecté ou pas de profil.
  Future<Map<String, dynamic>?> getMyProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    return _client
        .schema(WintimeSupabaseConfig.schema)
        .from('user_profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
  }
}
