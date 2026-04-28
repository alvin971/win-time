/// Configuration globale de l'application
class AppConfig {
  static const String appName = 'Win Time';
  static const String apiBaseUrl = 'https://api.wintime.com/v1';
  static const String wsBaseUrl = 'wss://ws.wintime.com';

  // API Keys (à stocker dans .env en production)
  static const String stripePublishableKey = 'pk_test_YOUR_KEY';
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_KEY';

  // Configuration métier
  static const double subscriptionFee = 100.0;
  static const double commissionPerOrder = 0.10;
  static const int maxOrdersIncluded = 1000;

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 20;

  // Cache
  static const Duration cacheValidity = Duration(hours: 1);
}
