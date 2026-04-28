/// Exception de base pour l'application
class AppException implements Exception {
  final String message;
  final int? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => 'AppException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Exception liée au serveur
class ServerException extends AppException {
  const ServerException([String message = 'Erreur serveur', int code = 500])
      : super(message, code);
}

/// Exception liée au réseau
class NetworkException extends AppException {
  const NetworkException([String message = 'Pas de connexion Internet'])
      : super(message);
}

/// Exception liée au cache
class CacheException extends AppException {
  const CacheException([String message = 'Erreur de cache']) : super(message);
}

/// Exception liée à l'authentification
class AuthenticationException extends AppException {
  const AuthenticationException(
      [String message = 'Authentification requise', int code = 401])
      : super(message, code);
}

/// Exception liée aux autorisations
class AuthorizationException extends AppException {
  const AuthorizationException([String message = 'Accès non autorisé'])
      : super(message, 403);
}

/// Exception liée à une ressource non trouvée
class NotFoundException extends AppException {
  const NotFoundException([String message = 'Ressource non trouvée'])
      : super(message, 404);
}

/// Exception liée à une validation
class ValidationException extends AppException {
  final Map<String, List<String>>? errors;

  const ValidationException(
      [String message = 'Erreur de validation', this.errors, int code = 400])
      : super(message, code);
}

/// Exception liée au WebSocket
class WebSocketException extends AppException {
  const WebSocketException([String message = 'Erreur de connexion temps réel'])
      : super(message);
}
