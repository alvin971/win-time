import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final ApiClient _apiClient;

  AuthRepositoryImpl(this._remote, this._local, this._apiClient);

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _remote.login(email: email, password: password);
      await _local.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      await _local.saveUser(result.user);
      _apiClient.setAuthToken(result.accessToken);
      return Right(result.user);
    } on UnauthorizedException catch (e) {
      return Left(AuthenticationFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    try {
      final result = await _remote.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      await _local.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      await _local.saveUser(result.user);
      _apiClient.setAuthToken(result.accessToken);
      return Right(result.user);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final refreshToken = await _local.getRefreshToken();
      await _remote.logout(refreshToken: refreshToken);
    } catch (_) {
      // Logout local même si l'appel serveur échoue
    }
    await _local.clearAll();
    _apiClient.clearAuthToken();
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final user = await _local.getCachedUser();
      final token = await _local.getAccessToken();
      _apiClient.setAuthToken(token);
      return Right(user);
    } on CacheException {
      return const Left(AuthenticationFailure());
    }
  }

  @override
  Future<Either<Failure, String>> refreshToken() async {
    try {
      final refreshToken = await _local.getRefreshToken();
      final newToken = await _remote.refreshAccessToken(refreshToken: refreshToken);
      await _local.saveTokens(
        accessToken: newToken,
        refreshToken: refreshToken,
      );
      _apiClient.setAuthToken(newToken);
      return Right(newToken);
    } on CacheException {
      return const Left(AuthenticationFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> forgotPassword({required String email}) async {
    try {
      await _remote.forgotPassword(email: email);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }
}
