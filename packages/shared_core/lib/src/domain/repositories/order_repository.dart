import '../entities/order_entity.dart';
import '../enums/order_status.dart';

/// Contrat read/write pour la collection `/orders`.
///
/// Streams alimentés par Firestore listeners (real-time). Côté Pro,
/// `watchActiveByRestaurant` permet d'afficher le dashboard. Côté Client,
/// `watchByCustomer` alimente l'onglet "Mes commandes" et `watchById`
/// alimente la page de tracking d'une commande spécifique.
abstract class OrderRepository {
  // ─── Reads ─────────────────────────────────────────────────────────────
  Stream<List<OrderEntity>> watchActiveByRestaurant(String restaurantId);
  Stream<List<OrderEntity>> watchHistoryByRestaurant(
    String restaurantId, {
    int limit = 50,
  });
  Stream<List<OrderEntity>> watchByCustomer(String customerId);
  Stream<OrderEntity?> watchById(String orderId);
  Future<OrderEntity?> getById(String orderId);

  // ─── Writes ────────────────────────────────────────────────────────────

  /// Crée une commande. Le doc est écrit avec `status: pending`.
  /// Retourne l'ID Firestore généré.
  Future<String> createOrder(OrderEntity order);

  /// Mise à jour générique du status par le restaurant.
  Future<void> updateStatus({
    required String orderId,
    required OrderStatus status,
    int? actualPreparationTime,
  });

  /// Annulation client (uniquement valide si status == pending).
  Future<void> cancelByCustomer({
    required String orderId,
    String? reason,
  });

  /// Note + review post-completed (Client).
  Future<void> rate({
    required String orderId,
    required double rating,
    String? review,
  });
}
