/// Statut d'une commande dans le système
enum OrderStatus {
  /// Commande en attente d'acceptation par le restaurant
  pending,

  /// Commande acceptée par le restaurant
  accepted,

  /// Commande en cours de préparation
  preparing,

  /// Commande prête pour le retrait
  ready,

  /// Commande terminée (récupérée par le client)
  completed,

  /// Commande annulée
  cancelled,

  /// Commande rejetée par le restaurant
  rejected,
}

extension OrderStatusExtension on OrderStatus {
  /// Retourne le nom d'affichage du statut
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.accepted:
        return 'Acceptée';
      case OrderStatus.preparing:
        return 'En préparation';
      case OrderStatus.ready:
        return 'Prête';
      case OrderStatus.completed:
        return 'Terminée';
      case OrderStatus.cancelled:
        return 'Annulée';
      case OrderStatus.rejected:
        return 'Rejetée';
    }
  }

  /// Vérifie si la commande est active (pas terminée/annulée/rejetée)
  bool get isActive =>
      this == OrderStatus.pending ||
      this == OrderStatus.accepted ||
      this == OrderStatus.preparing ||
      this == OrderStatus.ready;

  /// Vérifie si la commande est terminée
  bool get isFinished =>
      this == OrderStatus.completed ||
      this == OrderStatus.cancelled ||
      this == OrderStatus.rejected;
}
