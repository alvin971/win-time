import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/geo/geohash.dart';
import '../../domain/entities/address_entity.dart';
import '../../domain/entities/business_hours.dart';
import '../../domain/entities/contact_info.dart';
import '../../domain/entities/restaurant_entity.dart';
import '../../domain/entities/social_links.dart';
import '../../domain/enums/cuisine_type.dart';
import '../../domain/enums/day_of_week.dart';
import '../../domain/enums/price_range.dart';
import '_helpers.dart';

/// Mapper Firestore ↔ [RestaurantEntity].
///
/// Stocké à `/restaurants/{rid}`.
///
/// IMPORTANT: `geohash` est calculé automatiquement depuis
/// `address.latitude/longitude` dans [toFirestore] pour garantir la
/// cohérence avec les queries de proximité côté Client.
class RestaurantModel {
  static RestaurantEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return RestaurantEntity(
      id: snap.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      description: data['description'] as String?,
      slogan: data['slogan'] as String?,
      cuisineType: CuisineTypeX.fromString(data['cuisineType'] as String?),
      priceRange: PriceRangeX.fromString(data['priceRange'] as String?),
      address: _addressFromMap(data['address']),
      contactInfo: _contactInfoFromMap(data['contactInfo']),
      socialLinks: data['socialLinks'] != null
          ? _socialLinksFromMap(data['socialLinks'])
          : null,
      logoUrl: data['logoUrl'] as String?,
      bannerUrl: data['bannerUrl'] as String?,
      galleryImages: asList<String>(data['galleryImages']),
      businessHours: _businessHoursFromMap(data['businessHours']),
      closedDates: asList<dynamic>(data['closedDates'])
          .map((e) => ts(e))
          .whereType<DateTime>()
          .toList(),
      isActive: (data['isActive'] as bool?) ?? true,
      isApproved: (data['isApproved'] as bool?) ?? false,
      acceptingOrders: (data['acceptingOrders'] as bool?) ?? true,
      averagePreparationTime: (data['averagePreparationTime'] as int?) ?? 30,
      maxConcurrentOrders: data['maxConcurrentOrders'] as int?,
      rating: asDouble(data['rating']),
      totalReviews: (data['totalReviews'] as int?) ?? 0,
      geohash: (data['geohash'] as String?) ?? '',
      menuCategoryIds: asList<String>(data['menuCategoryIds']),
      createdAt: ts(data['createdAt']) ?? DateTime.now(),
      updatedAt: ts(data['updatedAt']) ?? DateTime.now(),
    );
  }

  /// Sérialise le restaurant pour Firestore.
  ///
  /// Recalcule systématiquement `geohash` depuis `address.latitude/longitude`
  /// pour garantir la cohérence — le caller n'a pas à se soucier de le faire
  /// manuellement.
  static Map<String, dynamic> toFirestore(RestaurantEntity r) {
    final geohash = Geohash.encode(
      r.address.latitude,
      r.address.longitude,
      precision: 9,
    );
    return {
      'ownerId': r.ownerId,
      'name': r.name,
      'description': r.description,
      'slogan': r.slogan,
      'cuisineType': r.cuisineType.name,
      'priceRange': r.priceRange.name,
      'priceLevel': r.priceRange.level, // pour filtrage rapide côté client
      'address': _addressToMap(r.address),
      'contactInfo': _contactInfoToMap(r.contactInfo),
      'socialLinks':
          r.socialLinks != null ? _socialLinksToMap(r.socialLinks!) : null,
      'logoUrl': r.logoUrl,
      'bannerUrl': r.bannerUrl,
      'galleryImages': r.galleryImages,
      'businessHours': _businessHoursToMap(r.businessHours),
      'closedDates': r.closedDates.map((d) => Timestamp.fromDate(d)).toList(),
      'isActive': r.isActive,
      'isApproved': r.isApproved,
      'acceptingOrders': r.acceptingOrders,
      'averagePreparationTime': r.averagePreparationTime,
      'maxConcurrentOrders': r.maxConcurrentOrders,
      'rating': r.rating,
      'totalReviews': r.totalReviews,
      'geohash': geohash,
      'latitude': r.address.latitude,
      'longitude': r.address.longitude,
      'menuCategoryIds': r.menuCategoryIds,
      'createdAt': Timestamp.fromDate(r.createdAt),
      'updatedAt': Timestamp.fromDate(r.updatedAt),
    };
  }

  // ─── AddressEntity ───────────────────────────────────────────────────────
  static AddressEntity _addressFromMap(dynamic raw) {
    if (raw is! Map) {
      return const AddressEntity(
        street: '',
        city: '',
        postalCode: '',
        country: 'France',
        latitude: 0,
        longitude: 0,
      );
    }
    return AddressEntity(
      street: (raw['street'] as String?) ?? '',
      city: (raw['city'] as String?) ?? '',
      postalCode: (raw['postalCode'] as String?) ?? '',
      country: (raw['country'] as String?) ?? 'France',
      latitude: asDouble(raw['latitude']) ?? 0.0,
      longitude: asDouble(raw['longitude']) ?? 0.0,
    );
  }

  static Map<String, dynamic> _addressToMap(AddressEntity a) {
    return {
      'street': a.street,
      'city': a.city,
      'postalCode': a.postalCode,
      'country': a.country,
      'latitude': a.latitude,
      'longitude': a.longitude,
    };
  }

  // ─── ContactInfo ─────────────────────────────────────────────────────────
  static ContactInfo _contactInfoFromMap(dynamic raw) {
    if (raw is! Map) {
      return const ContactInfo(email: '', phoneNumber: '');
    }
    return ContactInfo(
      email: (raw['email'] as String?) ?? '',
      phoneNumber: (raw['phoneNumber'] as String?) ?? '',
      websiteUrl: raw['websiteUrl'] as String?,
    );
  }

  static Map<String, dynamic> _contactInfoToMap(ContactInfo c) {
    return {
      'email': c.email,
      'phoneNumber': c.phoneNumber,
      'websiteUrl': c.websiteUrl,
    };
  }

  // ─── SocialLinks ─────────────────────────────────────────────────────────
  static SocialLinks _socialLinksFromMap(dynamic raw) {
    if (raw is! Map) return const SocialLinks();
    return SocialLinks(
      facebook: raw['facebook'] as String?,
      instagram: raw['instagram'] as String?,
      twitter: raw['twitter'] as String?,
      tiktok: raw['tiktok'] as String?,
    );
  }

  static Map<String, dynamic> _socialLinksToMap(SocialLinks s) {
    return {
      'facebook': s.facebook,
      'instagram': s.instagram,
      'twitter': s.twitter,
      'tiktok': s.tiktok,
    };
  }

  // ─── BusinessHours ───────────────────────────────────────────────────────
  static BusinessHours _businessHoursFromMap(dynamic raw) {
    if (raw is! Map) return BusinessHours.allClosed();
    final schedule = <DayOfWeek, DaySchedule>{};
    for (final day in DayOfWeek.values) {
      final daily = raw[day.name];
      if (daily is Map) {
        schedule[day] = DaySchedule(
          isOpen: (daily['isOpen'] as bool?) ?? false,
          morning: _timeSlotFromMap(daily['morning']),
          afternoon: _timeSlotFromMap(daily['afternoon']),
        );
      } else {
        schedule[day] = DaySchedule.closed();
      }
    }
    return BusinessHours(schedule: schedule);
  }

  static Map<String, dynamic> _businessHoursToMap(BusinessHours bh) {
    return {
      for (final day in DayOfWeek.values)
        day.name: _dayScheduleToMap(bh.schedule[day] ?? DaySchedule.closed()),
    };
  }

  static Map<String, dynamic> _dayScheduleToMap(DaySchedule d) {
    return {
      'isOpen': d.isOpen,
      'morning': d.morning != null ? _timeSlotToMap(d.morning!) : null,
      'afternoon': d.afternoon != null ? _timeSlotToMap(d.afternoon!) : null,
    };
  }

  static TimeSlot? _timeSlotFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final open = raw['openTime'] as String?;
    final close = raw['closeTime'] as String?;
    if (open == null || close == null) return null;
    return TimeSlot(openTime: open, closeTime: close);
  }

  static Map<String, dynamic> _timeSlotToMap(TimeSlot t) {
    return {'openTime': t.openTime, 'closeTime': t.closeTime};
  }
}
