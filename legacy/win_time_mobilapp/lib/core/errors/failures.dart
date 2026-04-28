import 'package:equatable/equatable.dart';

/// Classe de base pour les erreurs métier
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({
    required this.message,
    this.statusCode,
  });

  @override
  List<Object?> get props => [message, statusCode];
}

class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.statusCode,
  });
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Aucune connexion internet',
  });
}

class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Erreur de cache local',
  });
}

class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
  });
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    super.message = 'Session expirée, veuillez vous reconnecter',
  });
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    super.message = 'Vous n\'êtes pas autorisé à effectuer cette action',
  });
}
