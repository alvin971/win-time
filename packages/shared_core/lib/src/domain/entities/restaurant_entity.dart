import 'package:equatable/equatable.dart';

import '../enums/cuisine_type.dart';
import '../enums/price_range.dart';
import 'address_entity.dart';
import 'business_hours.dart';
import 'contact_info.dart';
import 'social_links.dart';

/// Entité Restaurant — schéma riche unifié pour Win Time Pro (writer)
/// et Win Time Client (reader).
///
/// `geohash` est calculé à partir de [AddressEntity.latitude]/[AddressEntity.longitude]
/// au moment du write côté Pro, pour permettre les queries Firestore par
/// proximité géographique côté Client.
///
/// `menuCategoryIds` est dénormalisé pour permettre au Client d'afficher
/// la liste des sections du menu sans charger toute la sub-collection
/// `categories`.
class RestaurantEntity extends Equatable {
  final String id;
  final String ownerId;

  final String name;
  final String? description;
  final String? slogan;

  final CuisineType cuisineType;
  final PriceRange priceRange;

  final AddressEntity address;
  final ContactInfo contactInfo;
  final SocialLinks? socialLinks;

  final String? logoUrl;
  final String? bannerUrl;
  final List<String> galleryImages;

  final BusinessHours businessHours;
  final List<DateTime> closedDates;

  final bool isActive;
  final bool isApproved;
  final bool acceptingOrders;
  final int averagePreparationTime; // minutes
  final int? maxConcurrentOrders;

  final double? rating;
  final int totalReviews;

  /// Champ critique pour les requêtes Firestore par proximité
  /// (préfixe geohash + post-filtre Geolocator.distanceBetween côté client).
  final String geohash;

  /// IDs des catégories du menu, dénormalisés pour rendu rapide.
  final List<String> menuCategoryIds;

  final DateTime createdAt;
  final DateTime updatedAt;

  const RestaurantEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.slogan,
    required this.cuisineType,
    required this.priceRange,
    required this.address,
    required this.contactInfo,
    this.socialLinks,
    this.logoUrl,
    this.bannerUrl,
    this.galleryImages = const [],
    required this.businessHours,
    this.closedDates = const [],
    this.isActive = true,
    this.isApproved = false,
    this.acceptingOrders = true,
    this.averagePreparationTime = 30,
    this.maxConcurrentOrders,
    this.rating,
    this.totalReviews = 0,
    required this.geohash,
    this.menuCategoryIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Le restaurant est-il ouvert maintenant ET prêt à accepter des commandes ?
  bool get isOpenForOrders =>
      isActive && isApproved && acceptingOrders && businessHours.isOpenNow();

  RestaurantEntity copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? slogan,
    CuisineType? cuisineType,
    PriceRange? priceRange,
    AddressEntity? address,
    ContactInfo? contactInfo,
    SocialLinks? socialLinks,
    String? logoUrl,
    String? bannerUrl,
    List<String>? galleryImages,
    BusinessHours? businessHours,
    List<DateTime>? closedDates,
    bool? isActive,
    bool? isApproved,
    bool? acceptingOrders,
    int? averagePreparationTime,
    int? maxConcurrentOrders,
    double? rating,
    int? totalReviews,
    String? geohash,
    List<String>? menuCategoryIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RestaurantEntity(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      slogan: slogan ?? this.slogan,
      cuisineType: cuisineType ?? this.cuisineType,
      priceRange: priceRange ?? this.priceRange,
      address: address ?? this.address,
      contactInfo: contactInfo ?? this.contactInfo,
      socialLinks: socialLinks ?? this.socialLinks,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      galleryImages: galleryImages ?? this.galleryImages,
      businessHours: businessHours ?? this.businessHours,
      closedDates: closedDates ?? this.closedDates,
      isActive: isActive ?? this.isActive,
      isApproved: isApproved ?? this.isApproved,
      acceptingOrders: acceptingOrders ?? this.acceptingOrders,
      averagePreparationTime:
          averagePreparationTime ?? this.averagePreparationTime,
      maxConcurrentOrders: maxConcurrentOrders ?? this.maxConcurrentOrders,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      geohash: geohash ?? this.geohash,
      menuCategoryIds: menuCategoryIds ?? this.menuCategoryIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        name,
        description,
        slogan,
        cuisineType,
        priceRange,
        address,
        contactInfo,
        socialLinks,
        logoUrl,
        bannerUrl,
        galleryImages,
        businessHours,
        closedDates,
        isActive,
        isApproved,
        acceptingOrders,
        averagePreparationTime,
        maxConcurrentOrders,
        rating,
        totalReviews,
        geohash,
        menuCategoryIds,
        createdAt,
        updatedAt,
      ];
}
