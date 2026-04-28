/// Statut du paiement d'une commande
enum PaymentStatus {
  /// Paiement en attente
  pending,

  /// Paiement effectué avec succès
  paid,

  /// Paiement échoué
  failed,

  /// Paiement remboursé
  refunded,
}

extension PaymentStatusExtension on PaymentStatus {
  /// Retourne le nom d'affichage du statut
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'En attente';
      case PaymentStatus.paid:
        return 'Payé';
      case PaymentStatus.failed:
        return 'Échoué';
      case PaymentStatus.refunded:
        return 'Remboursé';
    }
  }

  /// Vérifie si le paiement est réussi
  bool get isSuccessful => this == PaymentStatus.paid;

  /// Vérifie si le paiement a échoué
  bool get hasFailed => this == PaymentStatus.failed;
}
