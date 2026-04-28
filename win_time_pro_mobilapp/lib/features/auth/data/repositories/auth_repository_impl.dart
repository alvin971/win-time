import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final DioClient _dioClient;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
    required DioClient dioClient,
  })  : _remote = remote,
        _local = local,
        _dioClient = dioClient;

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
      _dioClient.setAuthToken(result.accessToken);
      return Right(result.user);
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
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
    required String phoneNumber,
    required Map<String, dynamic> restaurantData,
  }) async {
    try {
      final result = await _remote.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        restaurantData: restaurantData,
      );
      await _local.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      await _local.saveUser(result.user);
      _dioClient.setAuthToken(result.accessToken);
      return Right(result.user);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
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
    _dioClient.clearAuthToken();
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final user = await _local.getCachedUser();
      final token = await _local.getAccessToken();
      _dioClient.setAuthToken(token);
      return Right(user);
    } on CacheException {
      return const Left(AuthenticationFailure(message: 'Session expirée'));
    }
  }

  @override
  Future<Either<Failure, bool>> isAuthenticated() async {
    try {
      await _local.getAccessToken();
      return const Right(true);
    } on CacheException {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, String>> refreshToken() async {
    try {
      final refresh = await _local.getRefreshToken();
      final newToken = await _remote.refreshAccessToken(refreshToken: refresh);
      await _local.saveTokens(accessToken: newToken, refreshToken: refresh);
      _dioClient.setAuthToken(newToken);
      return Right(newToken);
    } on CacheException {
      return const Left(AuthenticationFailure(message: 'Session expirée'));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    }
  }

  @override
  Future<Either<Failure, void>> forgotPassword({required String email}) async {
    try {
      await _remote.forgotPassword(email: email);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _remote.resetPassword(token: token, newPassword: newPassword);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    }
  }

  @override
  Future<Either<Failure, void>> verifyEmail({required String token}) async {
    try {
      await _remote.verifyEmail(token: token);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    }
  }
}
