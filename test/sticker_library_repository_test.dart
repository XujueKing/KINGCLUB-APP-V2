import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/sticker_library_repository.dart';

class Transport implements HttpClientAdapter {
  Transport(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
  @override
  void close({bool force = false}) {}
}

const asset = '12345678-1234-4234-8234-123456789012';
void main() {
  test('late read after disposal cannot restore cloud data', () async {
    final pending = Completer<Map<String, dynamic>>();
    final repo = StickerLibraryRepository(
      MessagingRepository(account: 'fixture', call: (_, _) => pending.future),
    );
    final read = repo.read();
    repo.dispose();
    final expectation = expectLater(read, throwsStateError);
    pending.complete({
      'revision': 0,
      'packs': [
        {'name': 'favorites', 'images': []},
      ],
    });
    await expectation;
  });
  test('conflict is returned to caller without blind overwrite', () async {
    var calls = 0;
    final repo = StickerLibraryRepository(
      MessagingRepository(
        account: 'fixture',
        call: (_, _) async {
          calls++;
          throw StateError('conflict');
        },
      ),
    );
    addTearDown(repo.dispose);
    await expectLater(
      repo.write(2, [StickerPack('favorites', [])]),
      throwsStateError,
    );
    expect(calls, 1);
  });
  for (final corrupt in [false, true]) {
    test('download checks digest corrupt=$corrupt', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final hash = (await const DartSha256().hash(bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final dio = Dio()
        ..httpClientAdapter = Transport((options) async {
          expect(options.path, '/kingclub/sticker-image/$asset');
          expect(options.followRedirects, false);
          return ResponseBody.fromBytes(corrupt ? [9, 2, 3] : bytes, 200);
        });
      final repo = StickerLibraryRepository(
        MessagingRepository(
          account: 'fixture',
          call: (_, _) async => {
            'assetId': asset,
            'size': 3,
            'sha256': hash,
            'path': '/kingclub/sticker-image/$asset',
            'headers': {'authorization': 'Bearer fixture'},
          },
        ),
        dio: dio,
      );
      addTearDown(repo.dispose);
      if (corrupt) {
        await expectLater(repo.download(asset), throwsFormatException);
      } else {
        expect(await repo.download(asset), bytes);
      }
    });
  }
  test(
    'rejects download redirect destination in signed API response',
    () async {
      final dio = Dio()
        ..httpClientAdapter = Transport(
          (_) async => throw StateError('must not request'),
        );
      final repo = StickerLibraryRepository(
        MessagingRepository(
          account: 'fixture',
          call: (_, _) async => {
            'assetId': asset,
            'size': 3,
            'sha256': 'a' * 64,
            'path': 'https://other.invalid/file',
            'headers': {'authorization': 'Bearer fixture'},
          },
        ),
        dio: dio,
      );
      addTearDown(repo.dispose);
      await expectLater(repo.download(asset), throwsFormatException);
    },
  );
}
