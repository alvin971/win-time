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
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  CategoryEntity copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? description,
    String? iconUrl,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
