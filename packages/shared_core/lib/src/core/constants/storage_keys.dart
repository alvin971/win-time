/// Clés de stockage local utilisées dans l'application
class StorageKeys {
  StorageKeys._();

  /// Clés liées à l'authentification
  static const String accessToken = 'ACCESS_TOKEN';
  static const String refreshToken = 'REFRESH_TOKEN';
  static const String isLoggedIn = 'IS_LOGGED_IN';

  /// Clés liées à l'utilisateur
  static const String cachedUser = 'CACHED_USER';
  static const String userId = 'USER_ID';

  /// Clés liées au restaurant (pour l'app Pro)
  static const String cachedRestaurant = 'CACHED_RESTAURANT';
  static const String restaurantId = 'RESTAURANT_ID';

  /// Préférences utilisateur
  static const String themeMode = 'THEME_MODE';
  static const String language = 'LANGUAGE';
  static const String notificationsEnabled = 'NOTIFICATIONS_ENABLED';

  /// Cache
  static const String lastSyncDate = 'LAST_SYNC_DATE';
  static const String cacheVersion = 'CACHE_VERSION';
}
