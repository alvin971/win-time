/// Exceptions pour la couche data
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  ServerException({
    required this.message,
    this.statusCode,
  });
}

class NetworkException implements Exception {
  final String message;

  NetworkException({this.message = 'No internet connection'});
}

class CacheException implements Exception {
  final String message;

  CacheException({this.message = 'Cache error'});
}

class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException({this.message = 'Unauthorized'});
}
