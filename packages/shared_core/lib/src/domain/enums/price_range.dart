enum PriceRange {
  budget,
  moderate,
  expensive,
  luxury,
}

extension PriceRangeX on PriceRange {
  /// Affichage stylisé "€", "€€", "€€€", "€€€€".
  String get symbol {
    switch (this) {
      case PriceRange.budget:
        return '€';
      case PriceRange.moderate:
        return '€€';
      case PriceRange.expensive:
        return '€€€';
      case PriceRange.luxury:
        return '€€€€';
    }
  }

  /// Échelle 1-4 pour requêtes / tri / filtres.
  int get level {
    switch (this) {
      case PriceRange.budget:
        return 1;
      case PriceRange.moderate:
        return 2;
      case PriceRange.expensive:
        return 3;
      case PriceRange.luxury:
        return 4;
    }
  }

  static PriceRange fromString(String? raw) {
    if (raw == null) return PriceRange.moderate;
    return PriceRange.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => PriceRange.moderate,
    );
  }

  static PriceRange fromLevel(int level) {
    switch (level) {
      case 1:
        return PriceRange.budget;
      case 3:
        return PriceRange.expensive;
      case 4:
        return PriceRange.luxury;
      default:
        return PriceRange.moderate;
    }
  }
}
