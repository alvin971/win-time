enum Allergen {
  gluten,
  crustaceans,
  eggs,
  fish,
  peanuts,
  soy,
  milk,
  nuts,
  celery,
  mustard,
  sesame,
  sulfites,
  lupin,
  molluscs,
}

extension AllergenX on Allergen {
  String get displayName {
    switch (this) {
      case Allergen.gluten:
        return 'Gluten';
      case Allergen.crustaceans:
        return 'Crustacés';
      case Allergen.eggs:
        return 'Œufs';
      case Allergen.fish:
        return 'Poisson';
      case Allergen.peanuts:
        return 'Arachides';
      case Allergen.soy:
        return 'Soja';
      case Allergen.milk:
        return 'Lait';
      case Allergen.nuts:
        return 'Fruits à coque';
      case Allergen.celery:
        return 'Céleri';
      case Allergen.mustard:
        return 'Moutarde';
      case Allergen.sesame:
        return 'Sésame';
      case Allergen.sulfites:
        return 'Sulfites';
      case Allergen.lupin:
        return 'Lupin';
      case Allergen.molluscs:
        return 'Mollusques';
    }
  }

  static Allergen fromString(String? raw) {
    if (raw == null) return Allergen.gluten;
    return Allergen.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => Allergen.gluten,
    );
  }
}
