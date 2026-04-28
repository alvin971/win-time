import 'package:equatable/equatable.dart';

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
  final bool acceptingOrders;
  final int averagePreparationTime;
  final int? maxConcurrentOrders;

  final double? rating;
  final int totalReviews;

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
    this.acceptingOrders = true,
    this.averagePreparationTime = 30,
    this.maxConcurrentOrders,
    this.rating,
    this.totalReviews = 0,
    required this.createdAt,
    required this.updatedAt,
  });

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
        acceptingOrders,
        averagePreparationTime,
        maxConcurrentOrders,
        rating,
        totalReviews,
        createdAt,
        updatedAt,
      ];
}

class AddressEntity extends Equatable {
  final String street;
  final String city;
  final String postalCode;
  final String country;
  final double? latitude;
  final double? longitude;

  const AddressEntity({
    required this.street,
    required this.city,
    required this.postalCode,
    required this.country,
    this.latitude,
    this.longitude,
  });

  String get fullAddress => '$street, $postalCode $city, $country';

  @override
  List<Object?> get props => [street, city, postalCode, country, latitude, longitude];
}

class ContactInfo extends Equatable {
  final String email;
  final String phoneNumber;
  final String? websiteUrl;

  const ContactInfo({
    required this.email,
    required this.phoneNumber,
    this.websiteUrl,
  });

  @override
  List<Object?> get props => [email, phoneNumber, websiteUrl];
}

class SocialLinks extends Equatable {
  final String? facebook;
  final String? instagram;
  final String? twitter;

  const SocialLinks({
    this.facebook,
    this.instagram,
    this.twitter,
  });

  @override
  List<Object?> get props => [facebook, instagram, twitter];
}

class BusinessHours extends Equatable {
  final Map<DayOfWeek, DaySchedule?> schedule;

  const BusinessHours({required this.schedule});

  bool isOpenOn(DayOfWeek day) {
    return schedule[day]?.isOpen ?? false;
  }

  DaySchedule? getScheduleFor(DayOfWeek day) {
    return schedule[day];
  }

  @override
  List<Object?> get props => [schedule];
}

class DaySchedule extends Equatable {
  final bool isOpen;
  final TimeSlot? morning;
  final TimeSlot? afternoon;

  const DaySchedule({
    required this.isOpen,
    this.morning,
    this.afternoon,
  });

  @override
  List<Object?> get props => [isOpen, morning, afternoon];
}

class TimeSlot extends Equatable {
  final String openTime;
  final String closeTime;

  const TimeSlot({
    required this.openTime,
    required this.closeTime,
  });

  @override
  List<Object?> get props => [openTime, closeTime];
}

enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

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
  vegetarian,
  vegan,
  fastFood,
  seafood,
  grill,
  bakery,
  desserts,
  other,
}

enum PriceRange {
  budget,
  moderate,
  expensive,
  luxury,
}
