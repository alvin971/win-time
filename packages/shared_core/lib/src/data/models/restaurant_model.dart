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

/// Mapper Postgres ↔ [RestaurantEntity].
///
/// Table : `wintime.restaurants`. Adresse aplatie (colonnes
/// `address_*`/`latitude`/`longitude` côté Postgres pour permettre les
/// requêtes par bbox geohash et order-by-distance), mais reconstituée
/// en `AddressEntity` côté Dart.
///
/// Le `geohash` est recalculé automatiquement dans [toRow] pour garantir
/// la cohérence avec les queries de proximité côté Client (le caller n'a
/// pas à le faire manuellement).
class RestaurantModel {
  static RestaurantEntity fromRow(Map<String, dynamic> row) {
    return RestaurantEntity(
      id: row['id'] as String,
      ownerId: (row['owner_id'] as String?) ?? '',
      name: (row['name'] as String?) ?? '',
      description: row['description'] as String?,
      slogan: row['slogan'] as String?,
      cuisineType: CuisineTypeX.fromString(row['cuisine_type'] as String?),
      priceRange: PriceRangeX.fromString(row['price_range'] as String?),
      address: AddressEntity(
        street: (row['address_street'] as String?) ?? '',
        city: (row['address_city'] as String?) ?? '',
        postalCode: (row['address_postal_code'] as String?) ?? '',
        country: (row['address_country'] as String?) ?? 'France',
        latitude: asDouble(row['latitude']) ?? 0.0,
        longitude: asDouble(row['longitude']) ?? 0.0,
      ),
      contactInfo: ContactInfo(
        email: (row['contact_email'] as String?) ?? '',
        phoneNumber: (row['contact_phone'] as String?) ?? '',
        websiteUrl: row['contact_website'] as String?,
      ),
      socialLinks: row['social_links'] != null
          ? _socialLinksFromMap(row['social_links'])
          : null,
      logoUrl: row['logo_url'] as String?,
      bannerUrl: row['banner_url'] as String?,
      galleryImages: asList<String>(row['gallery_images']),
      businessHours: _businessHoursFromMap(row['business_hours']),
      closedDates: asList<dynamic>(row['closed_dates'])
          .map(ts)
          .whereType<DateTime>()
          .toList(),
      isActive: (row['is_active'] as bool?) ?? true,
      isApproved: (row['is_approved'] as bool?) ?? false,
      acceptingOrders: (row['accepting_orders'] as bool?) ?? true,
      averagePreparationTime: asInt(row['average_preparation_time']) ?? 30,
      maxConcurrentOrders: asInt(row['max_concurrent_orders']),
      rating: asDouble(row['rating']),
      totalReviews: asInt(row['total_reviews']) ?? 0,
      geohash: (row['geohash'] as String?) ?? '',
      menuCategoryIds: asList<String>(row['menu_category_ids']),
      createdAt: ts(row['created_at']) ?? DateTime.now(),
      updatedAt: ts(row['updated_at']) ?? DateTime.now(),
    );
  }

  /// Sérialise pour insert/update. Recalcule systématiquement le `geohash`
  /// depuis lat/lng — le caller n'a pas à le faire manuellement.
  static Map<String, dynamic> toRow(RestaurantEntity r) {
    final geohash = Geohash.encode(
      r.address.latitude,
      r.address.longitude,
      precision: 9,
    );
    return {
      if (r.id.isNotEmpty) 'id': r.id,
      'owner_id': r.ownerId,
      'name': r.name,
      'description': r.description,
      'slogan': r.slogan,
      'cuisine_type': r.cuisineType.name,
      'price_range': r.priceRange.name,
      'price_level': r.priceRange.level,
      'address_street': r.address.street,
      'address_city': r.address.city,
      'address_postal_code': r.address.postalCode,
      'address_country': r.address.country,
      'latitude': r.address.latitude,
      'longitude': r.address.longitude,
      'geohash': geohash,
      'contact_email': r.contactInfo.email,
      'contact_phone': r.contactInfo.phoneNumber,
      'contact_website': r.contactInfo.websiteUrl,
      'social_links':
          r.socialLinks != null ? _socialLinksToMap(r.socialLinks!) : null,
      'logo_url': r.logoUrl,
      'banner_url': r.bannerUrl,
      'gallery_images': r.galleryImages,
      'business_hours': _businessHoursToMap(r.businessHours),
      'closed_dates': r.closedDates
          .map((d) => d.toUtc().toIso8601String().substring(0, 10))
          .toList(),
      'is_active': r.isActive,
      'is_approved': r.isApproved,
      'accepting_orders': r.acceptingOrders,
      'average_preparation_time': r.averagePreparationTime,
      'max_concurrent_orders': r.maxConcurrentOrders,
      'rating': r.rating,
      'total_reviews': r.totalReviews,
      'menu_category_ids': r.menuCategoryIds,
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

  static Map<String, dynamic> _socialLinksToMap(SocialLinks s) => {
        'facebook': s.facebook,
        'instagram': s.instagram,
        'twitter': s.twitter,
        'tiktok': s.tiktok,
      };

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

  static Map<String, dynamic> _dayScheduleToMap(DaySchedule d) => {
        'isOpen': d.isOpen,
        'morning': d.morning != null ? _timeSlotToMap(d.morning!) : null,
        'afternoon': d.afternoon != null ? _timeSlotToMap(d.afternoon!) : null,
      };

  static TimeSlot? _timeSlotFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final open = raw['openTime'] as String?;
    final close = raw['closeTime'] as String?;
    if (open == null || close == null) return null;
    return TimeSlot(openTime: open, closeTime: close);
  }

  static Map<String, dynamic> _timeSlotToMap(TimeSlot t) => {
        'openTime': t.openTime,
        'closeTime': t.closeTime,
      };
}
