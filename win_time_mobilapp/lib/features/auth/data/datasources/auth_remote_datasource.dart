import 'package:injectable/injectable.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<({UserModel user, String accessToken, String refreshToken})> login({
    required String email,
    required String password,
  });

  Future<({UserModel user, String accessToken, String refreshToken})> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  });

  Future<void> logout({required String refreshToken});

  Future<String> refreshAccessToken({required String refreshToken});

  Future<void> forgotPassword({required String email});
}

@LazySingleton(as: AuthRemoteDataSource)
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl(this._apiClient);

  @override
  Future<({UserModel user, String accessToken, String refreshToken})> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return _parseAuthResponse(response.data as Map<String, dynamic>);
  }

  @override
  Future<({UserModel user, String accessToken, String refreshToken})> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        if (phone != null) 'phone': phone,
      },
    );
    return _parseAuthResponse(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    await _apiClient.dio.post(
      '/auth/logout',
      data: {'refresh_token': refreshToken},
    );
  }

  @override
  Future<String> refreshAccessToken({required String refreshToken}) async {
    final response = await _apiClient.dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    final data = response.data as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    if (token == null) throw ServerException(message: 'Token manquant dans la réponse');
    return token;
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    await _apiClient.dio.post(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ({UserModel user, String accessToken, String refreshToken}) _parseAuthResponse(
    Map<String, dynamic> data,
  ) {
    final userData = data['user'] as Map<String, dynamic>?;
    if (userData == null) {
      throw ServerException(message: 'Données utilisateur manquantes');
    }
    return (
      user: UserModel.fromJson(userData),
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }
}
