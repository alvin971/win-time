import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
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
    required String phoneNumber,
    required Map<String, dynamic> restaurantData,
  });

  Future<void> logout({required String refreshToken});

  Future<String> refreshAccessToken({required String refreshToken});

  Future<void> forgotPassword({required String email});

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<void> verifyEmail({required String token});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient _dioClient;

  AuthRemoteDataSourceImpl(this._dioClient);

  @override
  Future<({UserModel user, String accessToken, String refreshToken})> login({
    required String email,
    required String password,
  }) async {
    final response = await _dioClient.dio.post(
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
    required String phoneNumber,
    required Map<String, dynamic> restaurantData,
  }) async {
    final response = await _dioClient.dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'restaurant': restaurantData,
      },
    );
    return _parseAuthResponse(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    await _dioClient.dio.post(
      '/auth/logout',
      data: {'refresh_token': refreshToken},
    );
  }

  @override
  Future<String> refreshAccessToken({required String refreshToken}) async {
    final response = await _dioClient.dio.post(
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
    await _dioClient.dio.post(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _dioClient.dio.post(
      '/auth/reset-password',
      data: {'token': token, 'new_password': newPassword},
    );
  }

  @override
  Future<void> verifyEmail({required String token}) async {
    await _dioClient.dio.post(
      '/auth/verify-email',
      data: {'token': token},
    );
  }

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
