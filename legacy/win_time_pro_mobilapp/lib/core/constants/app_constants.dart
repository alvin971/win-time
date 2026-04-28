class AppConstants {
  AppConstants._();

  static const String appName = 'Win Time Pro';
  static const String appVersion = '1.0.0';

  static const String cachedUser = 'CACHED_USER';
  static const String cachedRestaurant = 'CACHED_RESTAURANT';
  static const String accessToken = 'ACCESS_TOKEN';
  static const String refreshToken = 'REFRESH_TOKEN';
  static const String isLoggedIn = 'IS_LOGGED_IN';
  static const String themeMode = 'THEME_MODE';
  static const String language = 'LANGUAGE';
  static const String notificationsEnabled = 'NOTIFICATIONS_ENABLED';

  static const int ordersRefreshInterval = 10;
  static const int maxImageSize = 5 * 1024 * 1024;
  static const int maxGalleryImages = 10;
  static const int minPasswordLength = 8;

  static const List<String> supportedLanguages = ['fr', 'en'];
  static const String defaultLanguage = 'fr';

  static const String currencySymbol = '€';
  static const String currencyCode = 'EUR';

  static const String supportEmail = 'support@wintimepro.com';
  static const String supportPhone = '+33 1 23 45 67 89';

  static const String privacyPolicyUrl = 'https://wintimepro.com/privacy';
  static const String termsOfServiceUrl = 'https://wintimepro.com/terms';
  static const String helpCenterUrl = 'https://wintimepro.com/help';
}
