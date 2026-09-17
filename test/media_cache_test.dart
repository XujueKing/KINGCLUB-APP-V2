import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';

class _Transport implements HttpClientAdapter {
  int calls = 0;
  int size = 8;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return ResponseBody.fromBytes(
      List.filled(size, 7),
      200,
      headers: {
        'content-length': ['$size'],
        'content-type': ['image/png'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _BlockedTransport implements HttpClientAdapter {
  final ready = Completer<void>();
  final requests = <String, Completer<ResponseBody>>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) {
    final response = Completer<ResponseBody>();
    requests[options.path] = response;
    if (requests.length == 2) ready.complete();
    cancel?.then((_) {
      if (!response.isCompleted) {
        response.completeError(
          DioException(requestOptions: options, type: DioExceptionType.cancel),
        );
      }
    });
    return response.future;
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
      retainMedia: false,
    );
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });
  test('deleting a blocked download cancels only its own transfer', () async {
    final blocked = _BlockedTransport();
    final media = MediaCache(
      directory: () async => dir,
      dio: Dio()..httpClientAdapter = blocked,
    );
    final first = media.get(
      'https://media.example.test/deleted',
      scope: 'member:a',
      contentKey: 'deleted',
      kind: MediaKind.video,
    );
    final rejected = expectLater(first, throwsA(anything));
    final second = media.get(
      'https://media.example.test/kept',
      scope: 'member:a',
      contentKey: 'kept',
      kind: MediaKind.video,
    );
    await blocked.ready.future;
    await media.cancelForDeletion(
      scope: 'member:a',
      contentKey: 'deleted',
      kind: MediaKind.video,
    );
    await media
        .removePermanently(
          scope: 'member:a',
          contentKey: 'deleted',
          kind: MediaKind.video,
        )
        .timeout(const Duration(seconds: 3));
    await rejected;
    final kept = blocked.requests['https://media.example.test/kept']!;
    expect(kept.isCompleted, false);
    kept.complete(ResponseBody.fromBytes([1, 2, 3], 200));
    expect(await (await second).readAsBytes(), [1, 2, 3]);
    final reopened = MediaCache(directory: () async => dir);
    await expectLater(
      reopened.cached(
        scope: 'member:a',
        contentKey: 'deleted',
        kind: MediaKind.video,
      ),
      throwsStateError,
    );
    expect(
      await (await reopened.cached(
        scope: 'member:a',
        contentKey: 'kept',
        kind: MediaKind.video,
      )).readAsBytes(),
      [1, 2, 3],
    );
    expect(
      await dir
          .list(recursive: true)
          .where((e) => e.path.endsWith('.part'))
          .toList(),
      isEmpty,
    );
  });
  test('maximum upload-sized voice remains readable after reopening', () async {
    transport.size = 2 * 1024 * 1024;
    final file = await cache.get(
      'https://media.example.test/voice',
      scope: 'member:a',
      contentKey: 'large-voice',
      kind: MediaKind.audio,
    );
    expect(await file.length(), transport.size);
    final reopened = MediaCache(directory: () async => dir);
    final offline = await reopened.cached(
      scope: 'member:a',
      contentKey: 'large-voice',
      kind: MediaKind.audio,
    );
    expect(await offline.readAsBytes(), List.filled(transport.size, 7));
    expect(transport.calls, 1);
  });
  test('oversized voice leaves no published or partial cache', () async {
    transport.size = 2 * 1024 * 1024 + 1;
    await expectLater(
      cache.get(
        'https://media.example.test/voice',
        scope: 'member:a',
        contentKey: 'oversized-voice',
        kind: MediaKind.audio,
      ),
      throwsA(anything),
    );
    expect(
      await dir.list(recursive: true).where((e) => e is File).toList(),
      isEmpty,
    );
  });
  test(
    'persistent media survives reopen and budget without network reads',
    () async {
      final store = MediaCache(
        directory: () async => dir,
        dio: Dio()..httpClientAdapter = transport,
        imageBudget: 1,
        audioBudget: 1,
        videoBudget: 1,
      );
      for (final kind in MediaKind.values) {
        for (final id in ['first', 'second']) {
          await store.get(
            'https://media.example.test/${kind.name}/$id',
            scope: 'member:a',
            contentKey: id,
            kind: kind,
          );
        }
      }
      expect(transport.calls, 6);
      final reopened = MediaCache(directory: () async => dir);
      for (final kind in MediaKind.values) {
        for (final id in ['first', 'second']) {
          final file = await reopened.cached(
            scope: 'member:a',
            contentKey: id,
            kind: kind,
          );
          expect(await file.readAsBytes(), List.filled(8, 7));
          await expectLater(
            reopened.cached(scope: 'member:b', contentKey: id, kind: kind),
            throwsStateError,
          );
        }
      }
      await reopened.clear();
      await expectLater(
        reopened.cached(
          scope: 'member:a',
          contentKey: 'first',
          kind: MediaKind.audio,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'offline image lookup never downloads and respects account isolation',
    () async {
      final file = await cache.get(
        'https://media.example.test/avatar',
        scope: 'member:a',
        contentKey: 'avatar-1',
      );
      final reopened = MediaCache(
        directory: () async => dir,
        dio: Dio()..httpClientAdapter = transport,
      );
      expect(
        (await reopened.cachedImage(
          scope: 'member:a',
          contentKey: 'avatar-1',
        )).path,
        file.path,
      );
      await expectLater(
        reopened.cachedImage(scope: 'member:b', contentKey: 'avatar-1'),
        throwsStateError,
      );
      await reopened.clear(privateOnly: true);
      await expectLater(
        reopened.cachedImage(scope: 'member:a', contentKey: 'avatar-1'),
        throwsStateError,
      );
      expect(transport.calls, 1);
    },
  );
  test('clear rejects an old request paused before cache lookup', () async {
    final cached = await cache.get(
      'https://media.example.test/voice',
      scope: 'member:a',
      contentKey: 'voice',
      kind: MediaKind.audio,
    );
    final started = Completer<void>(), release = Completer<void>();
    var reads = 0;
    final reopened = MediaCache(
      directory: () async {
        if (++reads == 1) {
          started.complete();
          await release.future;
        }
        return dir;
      },
      dio: Dio()..httpClientAdapter = transport,
    );
    final pending = reopened.get(
      'https://media.example.test/voice',
      scope: 'member:a',
      contentKey: 'voice',
      kind: MediaKind.audio,
    );
    final check = expectLater(pending, throwsStateError);
    await started.future;
    final clearing = reopened.clear(privateOnly: true);
    release.complete();
    await check;
    await clearing;
    expect(await cached.exists(), false);
    expect(transport.calls, 1);
  });
  test(
    'session cancellation retains files but rejects in-flight local reads',
    () async {
      final file = await cache.get(
        'https://media.example.test/voice',
        scope: 'member:a',
        contentKey: 'voice',
        kind: MediaKind.audio,
      );
      final entered = Completer<void>(), release = Completer<void>();
      final waiting = MediaCache(
        directory: () async {
          if (!entered.isCompleted) entered.complete();
          await release.future;
          return dir;
        },
      );
      final read = waiting.cached(
        scope: 'member:a',
        contentKey: 'voice',
        kind: MediaKind.audio,
      );
      final rejected = expectLater(read, throwsStateError);
      await entered.future;
      await waiting.cancelPending();
      release.complete();
      await rejected;
      expect(await file.exists(), isTrue);
      final reopened = MediaCache(directory: () async => dir);
      expect(
        (await reopened.cached(
          scope: 'member:a',
          contentKey: 'voice',
          kind: MediaKind.audio,
        )).path,
        file.path,
      );
      await expectLater(
        reopened.cached(
          scope: 'member:b',
          contentKey: 'voice',
          kind: MediaKind.audio,
        ),
        throwsStateError,
      );
    },
  );
  test('clear immediately after get cancels before network starts', () async {
    final pending = cache.get(
      'https://media.example.test/voice',
      scope: 'member:a',
      contentKey: 'voice',
      kind: MediaKind.audio,
    );
    final check = expectLater(pending, throwsStateError);
    await cache.clear(privateOnly: true);
    await check;
    expect(transport.calls, 0);
  });
  test(
    'eviction removes only matching account audio and retry downloads',
    () async {
      Future<File> load(String account) => cache.get(
        'https://media.example.test/voice',
        scope: account,
        contentKey: 'voice',
        kind: MediaKind.audio,
      );
      final first = await load('member:a');
      final other = await load('member:b');
      await cache.evict(
        scope: 'member:a',
        contentKey: 'voice',
        kind: MediaKind.audio,
      );
      expect(await first.exists(), false);
      expect(await other.exists(), true);
      await load('member:a');
      expect(transport.calls, 3);
    },
  );
  test(
    'video posters persist, deduplicate and isolate account scopes',
    () async {
      var decodes = 0;
      Future<Uint8List?> decode(File source) async {
        expect(await source.exists(), true);
        decodes++;
        return Uint8List.fromList([1, 2, 3]);
      }

      Future<File> load(String scope) => cache.videoPoster(
        'https://media.example.test/video',
        scope: scope,
        contentKey: 'video-1',
        decode: decode,
      );
      final files = await Future.wait([load('member:a'), load('member:a')]);
      expect(files[0].path, files[1].path);
      await load('member:a');
      expect(decodes, 1);
      expect(transport.calls, 1);
      final second = await load('member:b');
      expect(second.path, isNot(files[0].path));
      expect(decodes, 2);
      await cache.clear(privateOnly: true);
      expect(await files[0].exists(), false);
      expect(await second.exists(), false);
    },
  );
  test(
    'persistent poster generation retains previously downloaded images',
    () async {
      final store = MediaCache(
        directory: () async => dir,
        dio: Dio()..httpClientAdapter = transport,
        imageBudget: 1,
      );
      final photo = await store.get(
        'https://media.example.test/photo',
        scope: 'member:a',
        contentKey: 'photo',
      );
      await store.videoPoster(
        'https://media.example.test/video',
        scope: 'member:a',
        contentKey: 'video',
        decode: (_) async => Uint8List.fromList([1, 2, 3]),
      );
      expect(await photo.readAsBytes(), List.filled(8, 7));
    },
  );
  test(
    'clearing during poster decoding discards late generated bytes',
    () async {
      final started = Completer<void>();
      final decoded = Completer<Uint8List?>();
      final pending = cache.videoPoster(
        'https://media.example.test/video',
        scope: 'member:a',
        contentKey: 'video-1',
        decode: (_) {
          started.complete();
          return decoded.future;
        },
      );
      final assertion = expectLater(pending, throwsStateError);
      await started.future;
      final clearing = cache.clear(privateOnly: true);
      decoded.complete(Uint8List.fromList([1, 2, 3]));
      await assertion;
      await clearing;
      expect(await cache.sizeBytes(), 0);
    },
  );
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
