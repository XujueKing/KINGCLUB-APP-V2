import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_image_forwarder.dart';
import 'package:kingclub/src/features/messaging/data/chat_image_uploader.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';

class Download implements HttpClientAdapter {
  Download(this.handle);
  final Future<ResponseBody> Function(RequestOptions) handle;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) => handle(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final group in [false, true]) {
    test('authorized image copied once for retries group=$group', () async {
      final dir = await Directory.systemTemp.createTemp('forward-image-');
      addTearDown(() => dir.delete(recursive: true));
      final media = MediaCache(directory: () async => dir);
      var reads = 0, uploads = 0;
      final path =
          '/kingclub/${group ? 'group-chat-image' : 'chat-image'}/source/image';
      final repo = MessagingRepository(
        account: 'me',
        call: (id, p) async {
          expect(id, group ? 'K260913000635' : 'K260913000633');
          return {
            'messageId': 'source',
            'image': {
              'path': path,
              'fileId': 'file',
              'headers': {'authorization': 'Bearer synthetic'},
            },
          };
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = Download((o) async {
          reads++;
          expect(o.path, path);
          expect(o.followRedirects, false);
          expect(o.headers['authorization'], 'Bearer synthetic');
          return ResponseBody.fromBytes(
            [1, 2, 3],
            200,
            headers: {
              'content-length': ['3'],
            },
          );
        });
      final forwarder = ChatImageForwarder(
        repository: repo,
        messageId: 'source',
        group: group,
        dio: dio,
        mediaStore: media,
        upload: (bytes) async {
          uploads++;
          expect(bytes, [1, 2, 3]);
          return UploadedChatImage(
            'owned-copy',
            2,
            2,
            'fingerprint',
            'request',
            sourceBytes: Uint8List.fromList([9, 8]),
          );
        },
      );
      expect((await forwarder.prepare()).assetId, 'owned-copy');
      expect((await forwarder.prepare()).assetId, 'owned-copy');
      expect(reads, 1);
      expect(uploads, 1);
      expect(await dir.list().toList(), isEmpty);
      await forwarder.acknowledgeQueued(clientMessageId: 'new-client');
      final reopened = MediaCache(directory: () async => dir);
      final local = await reopened.cached(
        scope: 'member:me',
        contentKey: 'chat-image-sent:new-client',
        kind: MediaKind.image,
      );
      expect(await local.readAsBytes(), [9, 8]);
      await ChatMediaCleanup(media: reopened).remove(
        account: 'me',
        group: group,
        message: {
          'sender': 'me',
          'messageType': 'image',
          'messageId': 'new-message',
          'clientMessageId': 'new-client',
        },
      );
      expect(await local.exists(), false);
      forwarder.dispose();
    });
  }
  for (final mode in ['wrong-path', 'oversize', 'truncated', 'session']) {
    test('rejects $mode before creating destination asset', () async {
      var uploads = 0, reads = 0;
      final repo = MessagingRepository(
        account: 'me',
        call: (_, p) async => {
          'messageId': 'source',
          'image': {
            'path': mode == 'wrong-path'
                ? 'https://external.invalid/image'
                : '/kingclub/chat-image/source/image',
            'fileId': 'file',
            'headers': {'authorization': 'Bearer synthetic'},
          },
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = Download((o) async {
          reads++;
          if (mode == 'session') {
            SecureSessionStore.changes.add(null);
            await Future<void>.delayed(Duration.zero);
          }
          return ResponseBody.fromBytes(
            [1, 2, 3],
            200,
            headers: {
              'content-length': [
                mode == 'oversize'
                    ? '20971521'
                    : mode == 'truncated'
                    ? '5'
                    : '3',
              ],
            },
          );
        });
      final forwarder = ChatImageForwarder(
        repository: repo,
        messageId: 'source',
        dio: dio,
        upload: (bytes) async {
          uploads++;
          return const UploadedChatImage('copy', 1, 1, 'f', 'r');
        },
      );
      await expectLater(forwarder.prepare(), throwsA(anything));
      expect(uploads, 0);
      if (mode == 'wrong-path') expect(reads, 0);
      forwarder.dispose();
    });
  }
}
