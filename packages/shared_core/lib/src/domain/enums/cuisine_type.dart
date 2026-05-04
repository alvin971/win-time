enum CuisineType {
  french,
  italian,
  asian,
  japanese,
  chinese,
  indian,
  mexican,
  american,
  mediterranean,
  african,
  lebanese,
  vegetarian,
  vegan,
  fastFood,
  seafood,
  grill,
  bakery,
  desserts,
  other,
}

extension CuisineTypeX on CuisineType {
  String get displayName {
    switch (this) {
      case CuisineType.french:
        return 'Française';
      case CuisineType.italian:
        return 'Italienne';
      case CuisineType.asian:
        return 'Asiatique';
      case CuisineType.japanese:
        return 'Japonaise';
      case CuisineType.chinese:
        return 'Chinoise';
      case CuisineType.indian:
        return 'Indienne';
      case CuisineType.mexican:
        return 'Mexicaine';
      case CuisineType.american:
        return 'Américaine';
      case CuisineType.mediterranean:
        return 'Méditerranéenne';
      case CuisineType.african:
        return 'Africaine';
      case CuisineType.lebanese:
        return 'Libanaise';
      case CuisineType.vegetarian:
        return 'Végétarienne';
      case CuisineType.vegan:
        return 'Végane';
      case CuisineType.fastFood:
        return 'Fast-food';
      case CuisineType.seafood:
        return 'Fruits de mer';
      case CuisineType.grill:
        return 'Grill';
      case CuisineType.bakery:
        return 'Boulangerie';
      case CuisineType.desserts:
        return 'Desserts';
      case CuisineType.other:
        return 'Autre';
    }
  }

  static CuisineType fromString(String? raw) {
    if (raw == null) return CuisineType.other;
    return CuisineType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => CuisineType.other,
    );
  }
}
