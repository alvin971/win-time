/// Constantes liées à l'API Win Time
class ApiConstants {
  ApiConstants._();

  /// URL de base de l'API
  static const String baseUrl = 'https://api.wintime.com/v1';

  /// URL de base du WebSocket
  static const String wsBaseUrl = 'wss://ws.wintime.com';

  /// Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// En-têtes HTTP
  static const String headerContentType = 'Content-Type';
  static const String headerAuthorization = 'Authorization';
  static const String headerAccept = 'Accept';

  /// Valeurs par défaut des en-têtes
  static const String contentTypeJson = 'application/json';
  static const String acceptJson = 'application/json';

  /// Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  /// Endpoints API
  static const String authEndpoint = '/auth';
  static const String usersEndpoint = '/users';
  static const String ordersEndpoint = '/orders';
  static const String restaurantsEndpoint = '/restaurants';
  static const String productsEndpoint = '/products';
  static const String menusEndpoint = '/menus';
  static const String categoriesEndpoint = '/categories';
  static const String paymentsEndpoint = '/payments';
  static const String statisticsEndpoint = '/statistics';
}
