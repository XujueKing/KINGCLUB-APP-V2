import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';

class _Transport implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return ResponseBody.fromBytes(
      List.filled(8, 7),
      200,
      headers: {
        'content-length': ['8'],
        'content-type': ['image/png'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;
  late _Transport transport;
  late MediaCache cache;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kingclub-media-test-');
    transport = _Transport();
    cache = MediaCache(
      directory: () async => dir,
      dio: Dio()..httpClientAdapter = transport,
      imageBudget: 16,
    );
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });
  test(
    'deduplicates requests, reuses persisted media and rotated URLs',
    () async {
      final files = await Future.wait(
        List.generate(
          4,
          (_) => cache.get(
            'https://media.example.test/file?token=a',
            scope: 'member:a',
            contentKey: 'photo-v1',
          ),
        ),
      );
      expect(transport.calls, 1);
      expect(files.map((f) => f.path).toSet().length, 1);
      final reopened = MediaCache(
        directory: () async => dir,
        dio: Dio()..httpClientAdapter = transport,
      );
      await reopened.get(
        'https://media.example.test/file?token=b',
        scope: 'member:a',
        contentKey: 'photo-v1',
      );
      expect(transport.calls, 1);
      await cache.get(
        'https://media.example.test/file?token=b',
        scope: 'member:b',
        contentKey: 'photo-v1',
      );
      expect(transport.calls, 2);
    },
  );
  test(
    'evicts old media under budget and clears private data separately',
    () async {
      final first = await cache.get(
        'https://media.example.test/1',
        scope: 'public',
      );
      await cache.get('https://media.example.test/2', scope: 'member:a');
      final last = await cache.get(
        'https://media.example.test/3',
        scope: 'public',
      );
      expect(await cache.sizeBytes(), 16);
      expect(await first.exists(), false);
      await cache.clear(privateOnly: true);
      expect(await last.exists(), true);
      expect(await cache.sizeBytes(), 8);
      await cache.clear();
      expect(await cache.sizeBytes(), 0);
    },
  );
  test('version changes redownload and insecure links are rejected', () async {
    await cache.get(
      'https://media.example.test/a',
      scope: 'public',
      contentKey: 'v1',
    );
    await cache.get(
      'https://media.example.test/a',
      scope: 'public',
      contentKey: 'v2',
    );
    expect(transport.calls, 2);
    await expectLater(
      cache.get('http://media.example.test/a', scope: 'public'),
      throwsFormatException,
    );
  });
}
