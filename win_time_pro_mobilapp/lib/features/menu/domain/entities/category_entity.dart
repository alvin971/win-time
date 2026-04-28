import 'package:equatable/equatable.dart';

class CategoryEntity extends Equatable {
  final String id;
  final String restaurantId;
  final String name;
  final String? description;
  final String? iconUrl;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryEntity({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description,
    this.iconUrl,
    required this.displayOrder,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        restaurantId,
        name,
        description,
        iconUrl,
        displayOrder,
        isActive,
        createdAt,
        updatedAt,
      ];
}
