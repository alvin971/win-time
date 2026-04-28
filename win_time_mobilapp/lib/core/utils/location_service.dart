import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

@singleton
class LocationService {
  /// Vérifie et demande les permissions de localisation
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Récupère la position actuelle de l'utilisateur
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      print('Erreur lors de la récupération de la position: $e');
      return null;
    }
  }

  /// Calcule la distance entre deux points (en kilomètres)
  double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
          startLatitude,
          startLongitude,
          endLatitude,
          endLongitude,
        ) /
        1000; // Conversion en kilomètres
  }

  /// Récupère l'adresse à partir de coordonnées
  Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      return '${place.street}, ${place.postalCode} ${place.locality}';
    } catch (e) {
      print('Erreur lors de la récupération de l\'adresse: $e');
      return null;
    }
  }

  /// Récupère les coordonnées à partir d'une adresse
  Future<Location?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isEmpty) return null;

      return locations.first;
    } catch (e) {
      print('Erreur lors de la récupération des coordonnées: $e');
      return null;
    }
  }

  /// Vérifie si le service de localisation est activé
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
