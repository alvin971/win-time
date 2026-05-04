enum ProductLabel {
  bio,
  vegan,
  vegetarian,
  glutenFree,
  lactoseFree,
  homemade,
  spicy,
  newItem,
  bestseller,
  chefRecommendation,
}

extension ProductLabelX on ProductLabel {
  String get displayName {
    switch (this) {
      case ProductLabel.bio:
        return 'Bio';
      case ProductLabel.vegan:
        return 'Végan';
      case ProductLabel.vegetarian:
        return 'Végétarien';
      case ProductLabel.glutenFree:
        return 'Sans gluten';
      case ProductLabel.lactoseFree:
        return 'Sans lactose';
      case ProductLabel.homemade:
        return 'Fait maison';
      case ProductLabel.spicy:
        return 'Épicé';
      case ProductLabel.newItem:
        return 'Nouveau';
      case ProductLabel.bestseller:
        return 'Best-seller';
      case ProductLabel.chefRecommendation:
        return 'Recommandation chef';
    }
  }

  static ProductLabel fromString(String? raw) {
    if (raw == null) return ProductLabel.homemade;
    // Compat: ancien nom 'new_' (Pro app) → 'newItem'
    final mapped = raw == 'new_' ? 'newItem' : raw;
    return ProductLabel.values.firstWhere(
      (e) => e.name == mapped,
      orElse: () => ProductLabel.homemade,
    );
  }
}
