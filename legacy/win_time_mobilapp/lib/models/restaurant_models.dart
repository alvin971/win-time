class Restaurant {
  final String id;
  final String name;
  final String cuisine;
  final double rating;
  final int reviews;
  final String prepTime;
  final String distance;
  final String imageUrl;
  final String description;
  final bool isOpen;
  final List<String> specialties;

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.reviews,
    required this.prepTime,
    required this.distance,
    required this.imageUrl,
    required this.description,
    required this.isOpen,
    required this.specialties,
  });
}

class MenuItem {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final List<String> allergens;
  final bool isVegetarian;
  final bool isPopular;

  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.allergens,
    required this.isVegetarian,
    required this.isPopular,
  });
}

class CartItem {
  final MenuItem menuItem;
  int quantity;
  String? specialInstructions;

  CartItem({
    required this.menuItem,
    this.quantity = 1,
    this.specialInstructions,
  });

  double get totalPrice => menuItem.price * quantity;
}

class Order {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final List<CartItem> items;
  final double subtotal;
  final double winTimeFee; // 2% de frais Win Time
  final double total;
  final String status;
  final DateTime orderTime;
  final String? estimatedTime;

  Order({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.subtotal,
    required this.winTimeFee,
    required this.total,
    required this.status,
    required this.orderTime,
    this.estimatedTime,
  });
}
