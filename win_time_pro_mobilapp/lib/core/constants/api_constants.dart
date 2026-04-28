class ApiConstants {
  ApiConstants._();

  // API unifiée pour client et restaurateur
  static const String baseUrl = 'https://api.wintime.com/v1';
  static const String wsBaseUrl = 'wss://ws.wintime.com';

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String authHeader = 'Authorization';
  static const String contentType = 'Content-Type';
  static const String accept = 'Accept';
  static const String applicationJson = 'application/json';

  static const String auth = '/auth';
  static const String login = '$auth/login';
  static const String register = '$auth/register';
  static const String logout = '$auth/logout';
  static const String refreshToken = '$auth/refresh';
  static const String forgotPassword = '$auth/forgot-password';
  static const String resetPassword = '$auth/reset-password';
  static const String verifyEmail = '$auth/verify-email';

  static const String restaurants = '/restaurants';
  static String restaurantById(String id) => '$restaurants/$id';
  static String updateRestaurant(String id) => '$restaurants/$id';
  static const String toggleAvailability = '/toggle-availability';

  static const String menu = '/menu';
  static const String categories = '$menu/categories';
  static String categoryById(String id) => '$categories/$id';
  static const String products = '$menu/products';
  static String productById(String id) => '$products/$id';
  static String toggleProductAvailability(String id) =>
      '$products/$id/toggle-availability';

  static const String orders = '/orders';
  static String orderById(String id) => '$orders/$id';
  static String acceptOrder(String id) => '$orders/$id/accept';
  static String rejectOrder(String id) => '$orders/$id/reject';
  static String markOrderReady(String id) => '$orders/$id/ready';
  static String completeOrder(String id) => '$orders/$id/complete';
  static const String activeOrders = '$orders/active';
  static const String orderHistory = '$orders/history';

  static const String statistics = '/statistics';
  static const String dashboardStats = '$statistics/dashboard';
  static const String salesStats = '$statistics/sales';
  static const String performanceStats = '$statistics/performance';

  static const String notifications = '/notifications';
  static const String updateFcmToken = '$notifications/fcm-token';

  static const String upload = '/upload';
  static const String uploadImage = '$upload/image';
  static const String uploadMultiple = '$upload/multiple';

  static const String reviews = '/reviews';
  static String restaurantReviews(String restaurantId) =>
      '$reviews/restaurant/$restaurantId';
  static String respondToReview(String reviewId) =>
      '$reviews/$reviewId/respond';
}
