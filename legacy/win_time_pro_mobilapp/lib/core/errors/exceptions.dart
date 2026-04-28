class ServerException implements Exception {
  final String message;
  final String? code;

  const ServerException({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'ServerException: $message (Code: $code)';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException({
    this.message = 'Pas de connexion Internet',
  });

  @override
  String toString() => 'NetworkException: $message';
}

class CacheException implements Exception {
  final String message;

  const CacheException({
    this.message = 'Erreur de cache',
  });

  @override
  String toString() => 'CacheException: $message';
}

class AuthenticationException implements Exception {
  final String message;
  final String? code;

  const AuthenticationException({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'AuthenticationException: $message (Code: $code)';
}

class ValidationException implements Exception {
  final String message;
  final Map<String, String>? errors;

  const ValidationException({
    required this.message,
    this.errors,
  });

  @override
  String toString() => 'ValidationException: $message';
}

class NotFoundException implements Exception {
  final String message;

  const NotFoundException({
    this.message = 'Ressource non trouvée',
  });

  @override
  String toString() => 'NotFoundException: $message';
}
