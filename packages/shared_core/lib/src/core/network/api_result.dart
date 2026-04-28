import '../errors/failures.dart';

/// Classe représentant le résultat d'un appel API
/// Inspirée du pattern Either/Result de la programmation fonctionnelle
sealed class ApiResult<T> {
  const ApiResult();

  /// Crée un résultat de succès
  factory ApiResult.success(T data) = Success<T>;

  /// Crée un résultat d'échec
  factory ApiResult.failure(Failure failure) = Failed<T>;

  /// Vérifie si le résultat est un succès
  bool get isSuccess => this is Success<T>;

  /// Vérifie si le résultat est un échec
  bool get isFailure => this is Failed<T>;

  /// Récupère les données (null si échec)
  T? get data => switch (this) {
        Success(data: final d) => d,
        Failed() => null,
      };

  /// Récupère l'échec (null si succès)
  Failure? get failure => switch (this) {
        Success() => null,
        Failed(failure: final f) => f,
      };

  /// Transforme les données de succès
  ApiResult<R> map<R>(R Function(T) transform) {
    return switch (this) {
      Success(data: final d) => ApiResult.success(transform(d)),
      Failed(failure: final f) => ApiResult.failure(f),
    };
  }

  /// Exécute une fonction selon le résultat
  R fold<R>(
    R Function(Failure failure) onFailure,
    R Function(T data) onSuccess,
  ) {
    return switch (this) {
      Success(data: final d) => onSuccess(d),
      Failed(failure: final f) => onFailure(f),
    };
  }

  /// Exécute une action selon le résultat
  void when({
    required void Function(T data) onSuccess,
    required void Function(Failure failure) onFailure,
  }) {
    switch (this) {
      case Success(data: final d):
        onSuccess(d);
      case Failed(failure: final f):
        onFailure(f);
    }
  }
}

/// Résultat de succès
final class Success<T> extends ApiResult<T> {
  final T data;
  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;
}

/// Résultat d'échec
final class Failed<T> extends ApiResult<T> {
  final Failure failure;
  const Failed(this.failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failed<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => failure.hashCode;
}
