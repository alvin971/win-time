import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<String> getAccessToken();
  Future<String> getRefreshToken();

  Future<void> saveUser(UserModel user);
  Future<UserModel> getCachedUser();

  Future<void> clearAll();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  // Clés alignées avec DioClient._authInterceptor (lit AppConstants.accessToken)
  static const _keyAccessToken = AppConstants.accessToken;
  static const _keyRefreshToken = AppConstants.refreshToken;
  static const _keyUser = AppConstants.cachedUser;

  final FlutterSecureStorage _storage;

  AuthLocalDataSourceImpl(this._storage);

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
    ]);
  }

  @override
  Future<String> getAccessToken() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) throw CacheException(message: 'Aucun token trouvé');
    return token;
  }

  @override
  Future<String> getRefreshToken() async {
    final token = await _storage.read(key: _keyRefreshToken);
    if (token == null) throw CacheException(message: 'Aucun refresh token trouvé');
    return token;
  }

  @override
  Future<void> saveUser(UserModel user) async {
    await _storage.write(key: _keyUser, value: jsonEncode(user.toJson()));
  }

  @override
  Future<UserModel> getCachedUser() async {
    final raw = await _storage.read(key: _keyUser);
    if (raw == null) throw CacheException(message: 'Aucun utilisateur en cache');
    return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyUser),
    ]);
  }
}
