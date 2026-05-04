/// Configuration Supabase pour Win Time Pro.
///
/// L'URL et la clé anon sont des valeurs publiques (RLS protège les data —
/// voir migrations/20260504_020_wintime_rls.sql). OK à committer.
///
/// La service role key, par contre, ne DOIT JAMAIS apparaître dans le code
/// client : elle bypass toute RLS et permet de tout lire/écrire.
class WintimeSupabaseConfig {
  WintimeSupabaseConfig._();

  static const String url = 'https://supabase.0for0.com';

  static const String anonKey =
      'eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9'
      '.eyJyb2xlIjogImFub24iLCAiaXNzIjogInN1cGFiYXNlIiwgIml'
      'hdCI6IDE3NzM5NjE0NTIsICJleHAiOiAyMDg5MzIxNDUyfQ'
      '.zU4lqg55i1aUG-SEIz_SeVCdMI5twUyqK4W1eyVMXYo';

  /// Schéma Postgres dédié Win Time (isolé du schéma `public` de Mentality).
  static const String schema = 'wintime';
}
