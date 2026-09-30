import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

import 'chat_location.dart';
import 'chat_current_position.dart';

abstract class ChatLocationLookup {
  Future<ChatLocation> current();
  Future<List<ChatLocation>> search(String query);
}

class NativeChatLocationLookup implements ChatLocationLookup {
  int? currentAccuracyMeters;
  ChatLocation _location(
    double latitude,
    double longitude,
    String name,
    String address,
  ) {
    if (!latitude.isFinite || !longitude.isFinite) throw StateError('无法识别地点坐标');
    return ChatLocation.fromJson({
      'latitudeE6': (latitude * 1000000).round(),
      'longitudeE6': (longitude * 1000000).round(),
      'coordinateSystem': 'wgs84',
      'name': name,
      'address': address,
    });
  }

  String _address(Placemark place) => [
    place.administrativeArea,
    place.locality,
    place.subLocality,
    place.thoroughfare,
    place.subThoroughfare,
  ].whereType<String>().where((v) => v.trim().isNotEmpty).toSet().join(' ');
  @override
  Future<ChatLocation> current() async {
    currentAccuracyMeters = null;
    final position = await const ChatCurrentPosition().current();
    currentAccuracyMeters = position.accuracy.ceil();
    var address = '';
    try {
      final places = await Geocoding()
          .placemarkFromCoordinates(
            position.latitude,
            position.longitude,
            locale: const Locale('zh'),
          )
          .timeout(const Duration(seconds: 6));
      if (places.isNotEmpty) {
        address = _address(places.first);
        if (address.length > 300) address = '';
      }
    } catch (_) {
      /* Coordinates remain usable when the system has no geocoder. */
    }
    // A reverse-geocoder's nearest building is not an explicitly selected POI.
    return _location(position.latitude, position.longitude, '当前位置', address);
  }

  @override
  Future<List<ChatLocation>> search(String query) async {
    final text = query.trim();
    if (text.isEmpty || text.length > 100) {
      throw StateError('请输入100字以内的地点名称或地址');
    }
    final results = await Geocoding()
        .locationFromAddress(text, locale: const Locale('zh'))
        .timeout(const Duration(seconds: 12));
    final unique = <String, ChatLocation>{};
    for (final result in results.take(10)) {
      final location = _location(result.latitude, result.longitude, text, '');
      unique['${location.latitudeE6}:${location.longitudeE6}'] = location;
    }
    return unique.values.toList();
  }
}
