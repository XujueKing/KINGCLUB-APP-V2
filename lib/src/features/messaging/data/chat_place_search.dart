import 'package:dio/dio.dart';

import 'chat_location.dart';
import 'chat_map_coordinates.dart';

abstract class ChatPlaceSearch {
  Future<List<ChatLocation>> nearby(ChatLocation center);
  Future<List<ChatLocation>> search(String query, ChatLocation? center);
  void cancel();
  void dispose();
}

/// A dedicated unauthenticated map client: no member token or chat payload.
class TencentChatPlaceSearch implements ChatPlaceSearch {
  TencentChatPlaceSearch({required this.key, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://apis.map.qq.com',
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  static const configuredKey = String.fromEnvironment(
    'KINGCLUB_TENCENT_MAP_KEY',
  );
  final String key;
  final Dio _dio;
  CancelToken? _pending;

  @override
  Future<List<ChatLocation>> nearby(ChatLocation center) {
    final point = _point(center);
    return _get('/ws/geocoder/v1/', {
      'location': '${point.lat},${point.lon}',
      'get_poi': 1,
      'poi_options': 'radius=1000;page_size=20;page_index=1;policy=2',
    });
  }

  @override
  Future<List<ChatLocation>> search(String query, ChatLocation? center) {
    final text = query.trim();
    if (text.isEmpty || text.length > 100) {
      throw StateError('请输入100字以内的地点名称或地址');
    }
    final point = center == null ? null : _point(center);
    return _get('/ws/place/v1/search', {
      'keyword': text,
      'boundary': point == null
          ? 'region(全国,0)'
          : 'nearby(${point.lat},${point.lon},1000,1)',
      if (point != null) 'orderby': '_distance',
      'page_size': 20,
      'page_index': 1,
    });
  }

  ({double lat, double lon}) _point(ChatLocation center) =>
      center.coordinateSystem == 'gcj02'
      ? (lat: center.latitudeE6 / 1e6, lon: center.longitudeE6 / 1e6)
      : ChatMapCoordinates.toTencent(
          center.latitudeE6 / 1e6,
          center.longitudeE6 / 1e6,
        );

  Future<List<ChatLocation>> _get(
    String path,
    Map<String, dynamic> query,
  ) async {
    cancel();
    final token = CancelToken();
    _pending = token;
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: {...query, 'key': key},
        cancelToken: token,
      );
      if (token.isCancelled) throw StateError('地点查询已取消');
      final body = response.data;
      if (body is! Map || body['status'] != 0) {
        throw StateError('附近地点服务暂不可用，请重试');
      }
      final result = body['result'];
      final reference = result is Map ? result['address_reference'] : null;
      final rows = path == '/ws/geocoder/v1/' && result is Map
          ? [
              if (reference is Map) ...[
                reference['landmark_l2'],
                reference['landmark_l1'],
              ],
              if (result['pois'] is List) ...(result['pois'] as List),
            ]
          : body['data'];
      if (rows is! List) throw StateError('附近地点服务暂不可用，请重试');
      final unique = <String, ChatLocation>{};
      for (final row in rows.take(30)) {
        if (row is! Map || row['location'] is! Map) continue;
        final position = row['location'] as Map;
        final lat = position['lat'], lon = position['lng'];
        final title = row['title'], address = row['address'] ?? '';
        if (lat is! num ||
            lon is! num ||
            !lat.isFinite ||
            !lon.isFinite ||
            lat.abs() > 90 ||
            lon.abs() > 180 ||
            title is! String ||
            title.trim().isEmpty ||
            title.length > 100 ||
            address is! String ||
            address.length > 300) {
          continue;
        }
        final wgs = ChatMapCoordinates.fromTencent(
          lat.toDouble(),
          lon.toDouble(),
        );
        final location = ChatLocation.fromJson({
          'latitudeE6': (wgs.lat * 1e6).round(),
          'longitudeE6': (wgs.lon * 1e6).round(),
          'coordinateSystem': 'wgs84',
          'name': title,
          'address': address,
        });
        unique['${location.latitudeE6}:${location.longitudeE6}:${location.name}'] =
            location;
      }
      return unique.values.toList();
    } on DioException {
      // Never show Dio's URL/exception: it contains the SDK key and coordinates.
      throw StateError(token.isCancelled ? '地点查询已取消' : '地点服务连接失败，请重试');
    } finally {
      if (identical(_pending, token)) _pending = null;
    }
  }

  @override
  void cancel() {
    _pending?.cancel();
    _pending = null;
  }

  @override
  void dispose() {
    cancel();
    _dio.close(force: true);
  }
}
