import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../errors/exceptions.dart';

class DioClient {
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  DioClient({required FlutterSecureStorage secureStorage})
      : _secureStorage = secureStorage {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectionTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          ApiConstants.contentType: ApiConstants.applicationJson,
          ApiConstants.accept: ApiConstants.applicationJson,
        },
      ),
    );

    _dio.interceptors.addAll([
      _authInterceptor(),
      _errorInterceptor(),
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
      ),
    ]);
  }

  Dio get dio => _dio;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _secureStorage.read(key: AppConstants.accessToken);
        if (token != null) {
          options.headers[ApiConstants.authHeader] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          if (await _refreshToken()) {
            final request = error.requestOptions;
            final token =
                await _secureStorage.read(key: AppConstants.accessToken);
            request.headers[ApiConstants.authHeader] = 'Bearer $token';

            try {
              final response = await _dio.fetch(request);
              return handler.resolve(response);
            } catch (e) {
              return handler.reject(error);
            }
          }
        }
        handler.next(error);
      },
    );
  }

  InterceptorsWrapper _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) {
        handler.next(error);
      },
    );
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken =
          await _secureStorage.read(key: AppConstants.refreshToken);
      if (refreshToken == null) return false;

      final response = await _dio.post(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['accessToken'];
        final newRefreshToken = response.data['refreshToken'];

        await _secureStorage.write(
          key: AppConstants.accessToken,
          value: newAccessToken,
        );
        await _secureStorage.write(
          key: AppConstants.refreshToken,
          value: newRefreshToken,
        );

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<T> handleResponse<T>(
    Future<Response> Function() apiCall,
    T Function(dynamic) parser,
  ) async {
    try {
      final response = await apiCall();
      return parser(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ServerException(message: 'Erreur inattendue: ${e.toString()}');
    }
  }

  Exception _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
            message: 'Délai de connexion dépassé');

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = error.response?.data['message'] ??
            'Erreur serveur';

        if (statusCode == 401) {
          return AuthenticationException(
            message: message,
            code: statusCode.toString(),
          );
        } else if (statusCode == 404) {
          return NotFoundException(message: message);
        } else if (statusCode == 422) {
          return ValidationException(
            message: message,
            errors: error.response?.data['errors'],
          );
        }
        return ServerException(
          message: message,
          code: statusCode?.toString(),
        );

      case DioExceptionType.cancel:
        return ServerException(message: 'Requête annulée');

      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const NetworkException();

      default:
        return ServerException(message: 'Erreur inattendue');
    }
  }
}
