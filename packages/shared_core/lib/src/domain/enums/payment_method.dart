/// Méthode de paiement utilisée pour une commande
enum PaymentMethod {
  /// Carte de crédit/débit
  creditCard,

  /// Paiement en espèces
  cash,

  /// PayPal
  paypal,

  /// Apple Pay
  applePay,

  /// Google Pay
  googlePay,

  /// Autre méthode
  other,
}

extension PaymentMethodExtension on PaymentMethod {
  /// Retourne le nom d'affichage de la méthode
  String get displayName {
    switch (this) {
      case PaymentMethod.creditCard:
        return 'Carte bancaire';
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.paypal:
        return 'PayPal';
      case PaymentMethod.applePay:
        return 'Apple Pay';
      case PaymentMethod.googlePay:
        return 'Google Pay';
      case PaymentMethod.other:
        return 'Autre';
    }
  }

  /// Vérifie si c'est un paiement numérique
  bool get isDigital =>
      this == PaymentMethod.creditCard ||
      this == PaymentMethod.paypal ||
      this == PaymentMethod.applePay ||
      this == PaymentMethod.googlePay;

  /// Vérifie si c'est un paiement en espèces
  bool get isCash => this == PaymentMethod.cash;
}
