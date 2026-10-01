import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/session/secure_session_store.dart';
import 'chat_location.dart';
import 'chat_map_coordinates.dart';
import 'chat_place_search.dart';

/// Small session-only image cache. No names, chat payloads or member tokens go
/// to the map provider; coordinates are converted exactly once at its boundary.
class ChatMapPreviewCache {
  static const consentKey = 'tencent-chat-map-consent-v1';
  static final androidConsent = ValueNotifier(false);
  static final _images = <String, Future<Uint8List?>>{};
  static final _ready = <String, Uint8List>{};
  static String _key(ChatLocation p) =>
      '$defaultTargetPlatform/${p.coordinateSystem}/${p.latitudeE6}/${p.longitudeE6}';
  static Uint8List? peek(ChatLocation p) => _ready[_key(p)];
  static void evict(ChatLocation p) {
    _images.remove(_key(p));
    _ready.remove(_key(p));
  }

  static var _epoch = 0;
  static final _session = SecureSessionStore.changes.stream.listen((_) {
    _epoch++;
    _images.clear();
    _ready.clear();
  });

  static Future<bool> restoreConsent() async {
    try {
      androidConsent.value =
          await const FlutterSecureStorage().read(key: consentKey) == 'true';
    } catch (_) {}
    return androidConsent.value;
  }

  static Future<void> acceptConsent() async {
    try {
      await const FlutterSecureStorage().write(key: consentKey, value: 'true');
    } catch (_) {}
    androidConsent.value = true;
  }

  static Future<Uint8List?> load(ChatLocation location) {
    // Keep the session subscription alive for the lifetime of this cache.
    _session.resume();
    final platform = defaultTargetPlatform;
    if (kIsWeb ||
        (platform != TargetPlatform.iOS &&
            platform != TargetPlatform.android)) {
      return Future.value();
    }
    final key = _key(location);
    final cached = _images.remove(key);
    if (cached != null) {
      _images[key] = cached;
      return cached;
    }
    final epoch = _epoch;
    late final Future<Uint8List?> request;
    request = _load(location, platform).then((bytes) {
      if (epoch != _epoch || !identical(_images[key], request)) return null;
      if (bytes != null) _ready[key] = bytes;
      if (bytes == null) _images.remove(key);
      return bytes;
    });
    _images[key] = request;
    while (_images.length > 24) {
      final oldest = _images.keys.first;
      _images.remove(oldest);
      _ready.remove(oldest);
    }
    return request;
  }

  static Future<Uint8List?> _load(
    ChatLocation location,
    TargetPlatform platform,
  ) async {
    try {
      if (platform == TargetPlatform.iOS) {
        if (location.coordinateSystem != 'wgs84') return null;
        return await const MethodChannel('kingclub/chat-map-preview')
            .invokeMethod<Uint8List>(
              'snapshot',
              ChatMapCoordinates.appleArguments({
                'latitudeE6': location.latitudeE6,
                'longitudeE6': location.longitudeE6,
                'coordinateSystem': location.coordinateSystem,
              }),
            )
            .timeout(const Duration(seconds: 12));
      }
      final key = TencentChatPlaceSearch.configuredKey;
      if (key.isEmpty || (!androidConsent.value && !await restoreConsent())) {
        return null;
      }
      final point = location.coordinateSystem == 'gcj02'
          ? (lat: location.latitudeE6 / 1e6, lon: location.longitudeE6 / 1e6)
          : ChatMapCoordinates.toTencent(
              location.latitudeE6 / 1e6,
              location.longitudeE6 / 1e6,
            );
      final client = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      try {
        final response = await client.get<List<int>>(
          'https://apis.map.qq.com/ws/staticmap/v2/',
          queryParameters: {
            'key': key,
            'center':
                '${point.lat.toStringAsFixed(6)},${point.lon.toStringAsFixed(6)}',
            'size': '600*700',
            'scale': 1,
            'zoom': 16,
            'format': 'png',
          },
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = response.data;
        if (bytes == null ||
            bytes.length > 4 * 1024 * 1024 ||
            bytes.length < 8 ||
            bytes[0] != 137 ||
            bytes[1] != 80 ||
            bytes[2] != 78 ||
            bytes[3] != 71) {
          return null;
        }
        return Uint8List.fromList(bytes);
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      // Provider errors can contain a URL with its key. Never log them.
      return null;
    }
  }
}
