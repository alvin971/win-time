import 'package:equatable/equatable.dart';

class RestaurantEntity extends Equatable {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String address;
  final String city;
  final String postalCode;
  final double latitude;
  final double longitude;
  final String phone;
  final String email;
  final String cuisineType;
  final int priceRange; // 1-4 (€ à €€€€)
  final double commissionRate;
  final bool isActive;
  final bool isApproved;
  final double averageRating;
  final int totalReviews;
  final Map<String, dynamic> openingHours;
  final List<String> photos;
  final int? estimatedPreparationTime; // en minutes

  const RestaurantEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.email,
    required this.cuisineType,
    required this.priceRange,
    required this.commissionRate,
    required this.isActive,
    required this.isApproved,
    required this.averageRating,
    required this.totalReviews,
    required this.openingHours,
    required this.photos,
    this.estimatedPreparationTime,
  });

  String get fullAddress => '$address, $postalCode $city';

  String get priceRangeDisplay => '€' * priceRange;

  bool get isOpen {
    // Logique pour déterminer si le restaurant est ouvert
    // basé sur openingHours et l'heure actuelle
    return isActive && isApproved;
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        name,
        description,
        address,
        city,
        postalCode,
        latitude,
        longitude,
        phone,
        email,
        cuisineType,
        priceRange,
        commissionRate,
        isActive,
        isApproved,
        averageRating,
        totalReviews,
        openingHours,
        photos,
        estimatedPreparationTime,
      ];
}
