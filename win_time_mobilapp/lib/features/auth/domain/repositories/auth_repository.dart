import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  /// Connexion par email/mot de passe
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });

  /// Inscription
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  });

  /// Déconnexion (révoque le token côté serveur + efface le local)
  Future<Either<Failure, void>> logout();

  /// Vérifie si un token valide existe en local
  Future<Either<Failure, UserEntity>> getCurrentUser();

  /// Rafraîchit le token d'accès
  Future<Either<Failure, String>> refreshToken();

  /// Demande de réinitialisation de mot de passe
  Future<Either<Failure, void>> forgotPassword({required String email});
}
