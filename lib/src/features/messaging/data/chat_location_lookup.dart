import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'chat_location.dart';

abstract class ChatLocationLookup {
  Future<ChatLocation> current();
  Future<List<ChatLocation>> search(String query);
}

class NativeChatLocationLookup implements ChatLocationLookup {
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
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('请先开启手机定位服务');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('未获得定位权限，请在系统设置中允许定位');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              forceLocationManager: true,
              accuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 15),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            ),
    ).timeout(const Duration(seconds: 17));
    if (!position.accuracy.isFinite || position.accuracy > 1000) {
      throw StateError('当前定位精度不足，请重试或搜索地点');
    }
    String name = '当前位置', address = '';
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
        final candidate = places.first.name?.trim() ?? '';
        if (candidate.isNotEmpty && candidate.length <= 100) name = candidate;
        if (address.length > 300) address = '';
      }
    } catch (_) {
      /* Coordinates remain usable when the system has no geocoder. */
    }
    return _location(position.latitude, position.longitude, name, address);
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
