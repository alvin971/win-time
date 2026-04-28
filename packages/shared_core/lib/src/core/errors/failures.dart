import 'package:equatable/equatable.dart';

/// Classe de base pour tous les échecs dans l'application
abstract class Failure extends Equatable {
  final String message;
  final int? code;

  const Failure(this.message, [this.code]);

  @override
  List<Object?> get props => [message, code];
}

/// Échec lié au serveur (erreurs 5xx)
class ServerFailure extends Failure {
  const ServerFailure([String message = 'Erreur serveur']) : super(message, 500);
}

/// Échec lié au réseau (pas de connexion)
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Pas de connexion Internet'])
      : super(message);
}

/// Échec lié aux données en cache
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Erreur de cache']) : super(message);
}

/// Échec lié à l'authentification (401)
class AuthenticationFailure extends Failure {
  const AuthenticationFailure(
      [String message = 'Authentification requise', int code = 401])
      : super(message, code);
}

/// Échec lié aux autorisations (403)
class AuthorizationFailure extends Failure {
  const AuthorizationFailure([String message = 'Accès non autorisé'])
      : super(message, 403);
}

/// Échec lié à une ressource non trouvée (404)
class NotFoundFailure extends Failure {
  const NotFoundFailure([String message = 'Ressource non trouvée'])
      : super(message, 404);
}

/// Échec lié à une validation (400)
class ValidationFailure extends Failure {
  final Map<String, List<String>>? errors;

  const ValidationFailure(
      [String message = 'Erreur de validation', this.errors])
      : super(message, 400);

  @override
  List<Object?> get props => [message, code, errors];
}

/// Échec générique de l'API
class ApiFailure extends Failure {
  const ApiFailure(String message, [int? code]) : super(message, code);
}

/// Échec lié au WebSocket
class WebSocketFailure extends Failure {
  const WebSocketFailure([String message = 'Erreur de connexion temps réel'])
      : super(message);
}

/// Échec inconnu
class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'Une erreur inconnue est survenue'])
      : super(message);
}
