import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.code,
  });
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Pas de connexion Internet',
    super.code = 'NETWORK_ERROR',
  });
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    required super.message,
    super.code,
  });
}

class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code = 'VALIDATION_ERROR',
  });
}

class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Erreur de cache',
    super.code = 'CACHE_ERROR',
  });
}

class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Une erreur inconnue s\'est produite',
    super.code = 'UNKNOWN_ERROR',
  });
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({
    required super.message,
    super.code = 'NOT_FOUND',
  });
}

class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'Permission refusée',
    super.code = 'PERMISSION_DENIED',
  });
}
