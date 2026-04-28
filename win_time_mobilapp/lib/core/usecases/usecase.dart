import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Classe de base pour tous les use cases
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Params vide pour les use cases sans paramètres
class NoParams {
  const NoParams();
}
