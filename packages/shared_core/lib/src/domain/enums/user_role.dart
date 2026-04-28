/// Énumération des rôles utilisateur dans la plateforme Win Time
enum UserRole {
  /// Client qui commande dans les restaurants
  client,

  /// Propriétaire de restaurant
  restaurantOwner,

  /// Manager de restaurant
  restaurantManager,

  /// Personnel de restaurant
  restaurantStaff,

  /// Administrateur de la plateforme
  admin,
}

extension UserRoleExtension on UserRole {
  /// Vérifie si l'utilisateur est un membre de restaurant
  bool get isRestaurantUser =>
      this == UserRole.restaurantOwner ||
      this == UserRole.restaurantManager ||
      this == UserRole.restaurantStaff;

  /// Vérifie si l'utilisateur est un client
  bool get isClient => this == UserRole.client;

  /// Vérifie si l'utilisateur est un admin
  bool get isAdmin => this == UserRole.admin;

  /// Retourne le nom d'affichage du rôle
  String get displayName {
    switch (this) {
      case UserRole.client:
        return 'Client';
      case UserRole.restaurantOwner:
        return 'Propriétaire';
      case UserRole.restaurantManager:
        return 'Manager';
      case UserRole.restaurantStaff:
        return 'Personnel';
      case UserRole.admin:
        return 'Administrateur';
    }
  }
}
