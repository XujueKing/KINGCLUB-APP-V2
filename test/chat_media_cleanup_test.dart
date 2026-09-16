import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';

import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';

class DelayedDownload implements HttpClientAdapter {
  final started = Completer<void>();
  final response = Completer<ResponseBody>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) {
    started.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('file cleanup uses the exact downloader identity', () async {
    final root = await Directory.systemTemp.createTemp('chat-file-cleanup-');
    addTearDown(() => root.delete(recursive: true));
    final cache = ChatDownloadCache(
      root: root,
      key: await AesGcm.with256bits().newSecretKey(),
    );
    final identity = jsonEncode([
      'a',
      true,
      'm',
      'asset',
      3,
      'hash',
      'test.bin',
    ]);
    await cache.write(identity, 0, Uint8List.fromList([1, 2, 3]));
    await ChatMediaCleanup(
      downloadCache: (account) async {
        expect(account, 'a');
        return cache;
      },
    ).remove(
      account: 'a',
      group: true,
      message: {
        'messageType': 'file',
        'messageId': 'm',
        'fileAssetId': 'asset',
        'fileSize': 3,
        'fileSha256': 'hash',
        'fileName': 'test.bin',
      },
    );
    expect(await cache.read(identity, 0, 3), isNull);
    await expectLater(
      cache.write(identity, 0, Uint8List.fromList([4, 5, 6])),
      throwsStateError,
    );
  });
  test(
    'deletion fences in-flight download and imports after restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('chat-delete-race-');
      addTearDown(() => dir.delete(recursive: true));
      final transport = DelayedDownload();
      final cache = MediaCache(
        directory: () async => dir,
        dio: Dio()..httpClientAdapter = transport,
      );
      final download = cache.get(
        'https://example.test/image',
        scope: 'member:a',
        contentKey: 'message-image',
      );
      final rejected = expectLater(download, throwsStateError);
      await transport.started.future;
      final deletion = cache.removePermanently(
        scope: 'member:a',
        contentKey: 'message-image',
        kind: MediaKind.image,
      );
      // Let deletion persist its marker before releasing the response body.
      while (!await Directory('${dir.path}/deleted').exists()) {
        await Future<void>.delayed(Duration.zero);
      }
      transport.response.complete(ResponseBody.fromBytes([1, 2, 3], 200));
      await deletion;
      await rejected;
      final reopened = MediaCache(directory: () async => dir);
      await expectLater(
        reopened.importBytes(
          Uint8List.fromList([9]),
          scope: 'member:a',
          contentKey: 'message-image',
          kind: MediaKind.image,
        ),
        throwsStateError,
      );
      expect(
        await dir
            .list(recursive: true)
            .where(
              (entry) =>
                  entry.path.endsWith('.media') || entry.path.endsWith('.part'),
            )
            .toList(),
        isEmpty,
      );
    },
  );
  test(
    'deletes owned image copies and preserves other accounts and messages',
    () async {
      final dir = await Directory.systemTemp.createTemp('chat-cleanup-');
      addTearDown(() => dir.delete(recursive: true));
      final cache = MediaCache(directory: () async => dir);
      for (final account in ['a', 'b']) {
        for (final key in [
          'chat-image-sent:c',
          'chat-image-message:false:m:image',
          'avatar',
        ]) {
          await cache.importBytes(
            Uint8List.fromList([1, 2, 3]),
            scope: 'member:$account',
            contentKey: key,
            kind: MediaKind.image,
          );
        }
      }
      await ChatMediaCleanup(media: cache).remove(
        account: 'a',
        group: false,
        message: {
          'messageType': 'image',
          'sender': 'a',
          'messageId': 'm',
          'clientMessageId': 'c',
        },
      );
      final reopened = MediaCache(directory: () async => dir);
      await expectLater(
        reopened.cached(
          scope: 'member:a',
          contentKey: 'chat-image-sent:c',
          kind: MediaKind.image,
        ),
        throwsStateError,
      );
      await expectLater(
        reopened.cached(
          scope: 'member:a',
          contentKey: 'chat-image-message:false:m:image',
          kind: MediaKind.image,
        ),
        throwsStateError,
      );
      expect(
        await reopened.cached(
          scope: 'member:a',
          contentKey: 'avatar',
          kind: MediaKind.image,
        ),
        isNotNull,
      );
      expect(
        await reopened.cached(
          scope: 'member:b',
          contentKey: 'chat-image-sent:c',
          kind: MediaKind.image,
        ),
        isNotNull,
      );
    },
  );
}
