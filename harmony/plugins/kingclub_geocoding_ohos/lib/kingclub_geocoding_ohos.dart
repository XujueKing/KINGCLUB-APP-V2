import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart';

class KingclubGeocodingFactory extends GeocodingPlatformFactory {
  static void registerWith() {
    GeocodingPlatformFactory.instance = KingclubGeocodingFactory();
  }

  @override
  Geocoding createGeocoding(GeocodingCreationParams params) =>
      KingclubGeocoding(params);
}

class KingclubGeocoding extends Geocoding {
  KingclubGeocoding(GeocodingCreationParams params)
    : super.implementation(params);
  static const channel = MethodChannel('com.lingmei.kingclub/geocoding');
  static const timeout = Duration(seconds: 8);

  @override
  Future<bool> isPresent() async =>
      await channel.invokeMethod<bool>('isPresent').timeout(timeout) ?? false;

  Future<List<Map<String, dynamic>>> _query(
    String method,
    Map<String, Object> arguments,
    Locale? locale,
  ) async {
    final result = await channel
        .invokeListMethod<dynamic>(method, {
          ...arguments,
          if (locale != null) 'locale': locale.toLanguageTag(),
        })
        .timeout(timeout);
    return (result ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    Locale? locale,
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Invalid coordinates');
    }
    return (await _query('placemarkFromCoordinates', {
      'latitude': latitude,
      'longitude': longitude,
    }, locale)).map(_place).toList();
  }

  @override
  Future<List<Placemark>> placemarkFromAddress(
    String address, {
    Locale? locale,
  }) async {
    if (address.trim().isEmpty) throw ArgumentError('Empty address');
    return (await _query('placemarkFromAddress', {
      'address': address,
    }, locale)).map(_place).toList();
  }

  @override
  Future<List<Location>> locationFromAddress(
    String address, {
    Locale? locale,
  }) async {
    if (address.trim().isEmpty) throw ArgumentError('Empty address');
    return (await _query('locationFromAddress', {'address': address}, locale))
        .map(
          (v) => Location(
            latitude: (v['latitude'] as num).toDouble(),
            longitude: (v['longitude'] as num).toDouble(),
          ),
        )
        .toList();
  }

  static Placemark _place(Map<String, dynamic> v) => Placemark(
    name: v['name'] as String?,
    street: v['street'] as String?,
    isoCountryCode: v['isoCountryCode'] as String?,
    country: v['country'] as String?,
    postalCode: v['postalCode'] as String?,
    administrativeArea: v['administrativeArea'] as String?,
    subAdministrativeArea: v['subAdministrativeArea'] as String?,
    locality: v['locality'] as String?,
    subLocality: v['subLocality'] as String?,
    thoroughfare: v['thoroughfare'] as String?,
    subThoroughfare: v['subThoroughfare'] as String?,
  );
}
