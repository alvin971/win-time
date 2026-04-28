import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
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

@LazySingleton(as: AuthLocalDataSource)
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const _keyAccessToken = 'auth_access_token';
  static const _keyRefreshToken = 'auth_refresh_token';
  static const _keyUser = 'auth_user';

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
