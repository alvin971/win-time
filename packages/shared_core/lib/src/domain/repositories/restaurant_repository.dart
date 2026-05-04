import '../entities/restaurant_entity.dart';

/// Contrat read/write pour la collection `/restaurants`.
///
/// - Côté **Win Time Pro**, l'implémentation Firestore appelle `upsert()`
///   après avoir calculé le geohash.
/// - Côté **Win Time Client**, l'implémentation Firestore appelle
///   `watchNearby()` qui issue des queries par geohash bbox + post-filtre
///   distance avec [Geolocator.distanceBetween].
abstract class RestaurantRepository {
  /// Stream des restos actifs+approuvés autour de (lat, lng) dans `radiusKm`.
  /// Émet à chaque changement Firestore (real-time listener).
  Stream<List<RestaurantEntity>> watchNearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
  });

  /// Snapshot one-shot d'un restaurant par ID.
  Future<RestaurantEntity?> getById(String id);

  /// Stream temps réel d'un restaurant (pour la page détail).
  Stream<RestaurantEntity?> watchById(String id);

  /// Stream du restaurant détenu par un owner donné (utilisé par le Pro
  /// pour récupérer "Mon Restaurant").
  Stream<RestaurantEntity?> watchByOwner(String ownerId);

  /// Crée ou met à jour un doc restaurant.
  /// Le geohash est recalculé automatiquement dans le mapper Firestore.
  Future<void> upsert(RestaurantEntity restaurant);

  /// Met à jour le flag `acceptingOrders` (toggle "ouvert/fermé" rapide).
  Future<void> setAcceptingOrders(String restaurantId, bool accepting);
}
