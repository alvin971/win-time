import 'package:equatable/equatable.dart';

class AddressEntity extends Equatable {
  final String street;
  final String city;
  final String postalCode;
  final String country;
  final double latitude;
  final double longitude;

  const AddressEntity({
    required this.street,
    required this.city,
    required this.postalCode,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  String get fullAddress => '$street, $postalCode $city, $country';

  AddressEntity copyWith({
    String? street,
    String? city,
    String? postalCode,
    String? country,
    double? latitude,
    double? longitude,
  }) {
    return AddressEntity(
      street: street ?? this.street,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  List<Object?> get props => [street, city, postalCode, country, latitude, longitude];
}
