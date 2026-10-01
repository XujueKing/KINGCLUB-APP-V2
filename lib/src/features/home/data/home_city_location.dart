import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// City-level foreground lookup; no hard-coded default or continuous tracking.
Future<String?> locateHomeCity({bool requestPermission = false}) async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied && requestPermission) {
    permission = await Geolocator.requestPermission();
  }
  if (permission != LocationPermission.always &&
      permission != LocationPermission.whileInUse) {
    return null;
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: Duration(seconds: 12),
    ),
  );
  final places = await Geocoding()
      .placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        locale: const Locale('zh'),
      )
      .timeout(const Duration(seconds: 8));
  if (places.isEmpty) return null;
  final place = places.first;
  for (final name in [
    place.locality,
    place.subAdministrativeArea,
    place.administrativeArea,
  ]) {
    if (name != null && name.trim().isNotEmpty) return name.trim();
  }
  return null;
}
