/// Configuration Supabase pour Win Time Client.
///
/// L'URL et la clé anon sont des valeurs publiques (RLS protège les data).
/// La service role key, par contre, ne DOIT JAMAIS apparaître dans le code
/// client.
class WintimeSupabaseConfig {
  WintimeSupabaseConfig._();

  static const String url = 'https://supabase.0for0.com';

  static const String anonKey =
      'eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9'
      '.eyJyb2xlIjogImFub24iLCAiaXNzIjogInN1cGFiYXNlIiwgIml'
      'hdCI6IDE3NzM5NjE0NTIsICJleHAiOiAyMDg5MzIxNDUyfQ'
      '.zU4lqg55i1aUG-SEIz_SeVCdMI5twUyqK4W1eyVMXYo';

  /// Schéma Postgres dédié Win Time.
  static const String schema = 'wintime';
}
