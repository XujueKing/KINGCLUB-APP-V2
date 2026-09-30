import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kingclub/src/features/messaging/data/chat_location.dart';
import 'package:kingclub/src/features/messaging/data/chat_map_coordinates.dart';
import 'package:kingclub/src/features/messaging/data/chat_place_search.dart';

class MapTransport implements HttpClientAdapter {
  MapTransport(this.body);
  final dynamic body;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final gps = ChatLocation.fromJson({
  'latitudeE6': 39900000,
  'longitudeE6': 116400000,
  'coordinateSystem': 'wgs84',
  'name': '当前位置',
  'address': '',
});

void main() {
  test(
    'coordinate adapter agrees with Tencent official public-point samples',
    () {
      final samples = jsonDecode(
        File('test/fixtures/tencent_coordinate_samples.json')
            .readAsStringSync(),
      ) as List;
      for (final sample in samples) {
        final wgs = sample['wgs'] as List, gcj = sample['gcj'] as List;
        final forward = ChatMapCoordinates.toTencent(
          (wgs[0] as num).toDouble(),
          (wgs[1] as num).toDouble(),
        );
        expect(
          Geolocator.distanceBetween(
            forward.lat,
            forward.lon,
            (gcj[0] as num).toDouble(),
            (gcj[1] as num).toDouble(),
          ),
          lessThan(2),
        );
        final inverse = ChatMapCoordinates.fromTencent(
          (gcj[0] as num).toDouble(),
          (gcj[1] as num).toDouble(),
        );
        expect(
          Geolocator.distanceBetween(
            inverse.lat,
            inverse.lon,
            (wgs[0] as num).toDouble(),
            (wgs[1] as num).toDouble(),
          ),
          lessThan(2),
        );
      }
      expect(ChatMapCoordinates.toTencent(51.5, -.1), (lat: 51.5, lon: -.1));
      expect(ChatMapCoordinates.fromTencent(51.5, -.1), (lat: 51.5, lon: -.1));
    },
  );

  test('nearby sends GCJ boundary without member auth and returns distinct WGS POIs', () async {
    final row = {
      'title': 'Public test place',
      'address': 'Public test address',
      'location': {'lat': 39.901404, 'lng': 116.406243},
    };
    final transport = MapTransport({
      'status': 0,
      'data': [
        row,
        row,
        {
          'title': 'bad',
          'location': {'lat': 91, 'lng': 0},
        },
      ],
    });
    final dio = Dio()..httpClientAdapter = transport;
    final service = TencentChatPlaceSearch(key: 'test-map-key', dio: dio);
    addTearDown(service.dispose);
    final results = await service.nearby(gps);
    expect(results, hasLength(1));
    expect(results.single.coordinateSystem, 'wgs84');
    expect(
      Geolocator.distanceBetween(
        results.single.latitudeE6 / 1e6,
        results.single.longitudeE6 / 1e6,
        39.9,
        116.4,
      ),
      lessThan(2),
    );
    expect(results.single.name, 'Public test place');
    expect(transport.request!.path, '/ws/place/v1/here');
    expect(
      transport.request!.queryParameters['boundary'],
      startsWith('nearby(39.901'),
    );
    expect(
      transport.request!.headers.keys.where(
        (k) => k.toLowerCase() == 'authorization',
      ),
      isEmpty,
    );
    expect(gps.name, '当前位置');
    expect(gps.latitudeE6, 39900000);
  });

  test(
    'provider rejection is a safe error, never a fake nearby list or key leak',
    () async {
      final dio = Dio()
        ..httpClientAdapter = MapTransport({
          'status': 401,
          'message': 'test-map-key',
        });
      final service = TencentChatPlaceSearch(key: 'test-map-key', dio: dio);
      addTearDown(service.dispose);
      await expectLater(
        service.nearby(gps),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'safe message',
            isNot(contains('test-map-key')),
          ),
        ),
      );
    },
  );
}
