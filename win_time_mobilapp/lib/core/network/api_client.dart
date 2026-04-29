import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../config/app_config.dart';
import '../errors/exceptions.dart';

@singleton
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectionTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Intercepteurs
    _dio.interceptors.addAll([
      _AuthInterceptor(),
      _ErrorInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  /// Setter pour le token d'authentification
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear le token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

/// Intercepteur pour gérer l'authentification
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Ajouter le token depuis le storage si nécessaire
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Gérer le refresh token ou logout
    }
    super.onError(err, handler);
  }
}

/// Intercepteur pour transformer les erreurs Dio en exceptions custom
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    Exception exception;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        exception = NetworkException(message: 'Délai de connexion dépassé');
        break;

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final message = err.response?.data?['message']?.toString() ?? 'Erreur serveur';

        if (statusCode == 401) {
          exception = UnauthorizedException(message: message);
        } else {
          exception = ServerException(
            message: message,
            statusCode: statusCode,
          );
        }
        break;

      case DioExceptionType.cancel:
        exception = ServerException(message: 'Requête annulée');
        break;

      default:
        exception = NetworkException(
          message: 'Vérifiez votre connexion internet',
        );
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
      ),
    );
  }
}
