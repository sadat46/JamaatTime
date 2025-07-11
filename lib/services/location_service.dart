import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  /// Requests location permission from the user.
  /// Returns true if permission is granted, false otherwise.
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  /// Gets the current position of the user.
  /// Throws an exception if permission is not granted or location is unavailable.
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }
    bool hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Location permission denied.');
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Gets the place name (locality) from latitude and longitude.
  Future<String?> getPlaceName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Build a more complete address string
        return [
          place.name,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Opens the device's location settings page.
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
} 