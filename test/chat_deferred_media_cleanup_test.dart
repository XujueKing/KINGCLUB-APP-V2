import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class PendingReferences implements ChatOutbox {
  final messages = <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> read() async => List.of(messages);
  @override
  Future<void> put(Map<String, dynamic> message) async => messages.add(message);
  @override
  Future<void> remove(String id) async =>
      messages.removeWhere((m) => m['clientMessageId'] == id);
}

void main() {
  sqfliteFfiInit();
  for (final group in [false, true]) {
    for (final type in ['image', 'video']) {
      test('pending $type source survives clear and restart ($group)', () async {
        final root = await Directory.systemTemp.createTemp(
          'chat-pending-media-',
        );
        final key = await AesGcm.with256bits().newSecretKey();
        final queue = PendingReferences();
        final cache = MediaCache(
          directory: () async => Directory('${root.path}/media'),
        );
        final cleanup = ChatMediaCleanup(media: cache);
        final conversation = group ? 'group:g' : 'direct:peer';
        final kind = type == 'image' ? MediaKind.image : MediaKind.video;
        final sourceKey = 'chat-$type-sent:client1';
        final ownedKey = 'chat-$type-message:$group:message1:$type';
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final message = <String, dynamic>{
          'sequence': 1,
          'messageId': 'message1',
          'clientMessageId': 'client1',
          'sender': 'me',
          'messageType': type,
          '${type}AssetId': 'asset1',
          if (type == 'video') ...{
            'videoDurationMs': 1000,
            'videoWidth': 16,
            'videoHeight': 16,
            'videoHasAudio': false,
          },
          'text': '',
        };
        Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
          factory: databaseFactoryFfi,
          file: '${root.path}/history.db',
          key: key,
          account: 'me',
          outbox: queue,
        );
        var store = await open();
        try {
          final source = await cache.importBytes(
            bytes,
            scope: 'member:me',
            contentKey: sourceKey,
            kind: kind,
          );
          final owned = await cache.importBytes(
            bytes,
            scope: 'member:me',
            contentKey: ownedKey,
            kind: kind,
          );
          final other = await cache.importBytes(
            bytes,
            scope: 'member:other',
            contentKey: sourceKey,
            kind: kind,
          );
          await store.commit(conversation, [message], expectedEpoch: 0);
          // Server acknowledgment and local outbox removal are separate steps.
          await queue.put(message);
          await store.clear(conversation, mediaCleanup: cleanup);
          expect((await store.read(conversation)).messages, isEmpty);
          expect(await owned.exists(), isFalse);
          expect(await source.readAsBytes(), bytes);
          await store.close();
          store = await open();
          await store.collectDeferredMedia(mediaCleanup: cleanup);
          expect(await source.readAsBytes(), bytes);
          await expectLater(
            cache.importBytes(
              bytes,
              scope: 'member:me',
              contentKey: ownedKey,
              kind: kind,
            ),
            throwsStateError,
          );
          await queue.remove('client1');
          await store.collectDeferredMedia(mediaCleanup: cleanup);
          expect(await source.exists(), isFalse);
          expect(await other.readAsBytes(), bytes);
          final reopened = MediaCache(
            directory: () async => Directory('${root.path}/media'),
          );
          await expectLater(
            reopened.cached(
              scope: 'member:me',
              contentKey: sourceKey,
              kind: kind,
            ),
            throwsStateError,
          );
        } finally {
          await store.close();
          await root.delete(recursive: true);
        }
      });
    }
    test(
      'shared file source survives restart until its last reference ($group)',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'chat-file-deferred-',
        );
        final key = await AesGcm.with256bits().newSecretKey();
        final queue = PendingReferences();
        final sent = ChatDownloadCache(
          root: Directory('${root.path}/sent'),
          key: key,
        );
        final downloaded = ChatDownloadCache(
          root: Directory('${root.path}/download'),
          key: key,
        );
        final cleanup = ChatMediaCleanup(
          downloadCache: (_) async => downloaded,
          sentFileCache: (_) async => sent,
        );
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final digest = (await Sha256().hash(bytes)).bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        const asset = '11111111-1111-4111-8111-111111111111';
        final identity = jsonEncode([
          'sent-file-v1',
          asset,
          bytes.length,
          digest,
        ]);
        final message = <String, dynamic>{
          'sequence': 1,
          'messageId': 'file1',
          'clientMessageId': 'client1',
          'sender': 'me',
          'messageType': 'file',
          'fileAssetId': asset,
          'fileSize': bytes.length,
          'fileSha256': digest,
          'fileName': 'private-name.txt',
          'text': '',
        };
        final ownDownload = jsonEncode([
          'me',
          group,
          'file1',
          asset,
          bytes.length,
          digest,
          'private-name.txt',
        ]);
        final conversation = group ? 'group:g' : 'direct:peer';
        Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
          factory: databaseFactoryFfi,
          file: '${root.path}/history.db',
          key: key,
          account: 'me',
          outbox: queue,
        );
        var store = await open();
        try {
          await sent.write(identity, 0, bytes);
          await sent.retainCompleted(identity);
          await downloaded.write(ownDownload, 0, bytes);
          await downloaded.retainCompleted(ownDownload);
          await store.commit(conversation, [message], expectedEpoch: 0);
          await queue.put({...message, 'clientMessageId': 'pending'});
          await store.clear(conversation, mediaCleanup: cleanup);
          await expectLater(
            downloaded.ensureNotDeleted(ownDownload),
            throwsStateError,
          );
          expect(await sent.read(identity, 0, bytes.length), bytes);
          await store.close();
          store = await open();
          await store.collectDeferredMedia(mediaCleanup: cleanup);
          expect(await sent.read(identity, 0, bytes.length), bytes);
          // A received reference to the same asset must also retain our source.
          await store.commit('direct:other', [
            {
              ...message,
              'messageId': 'file2',
              'clientMessageId': 'client2',
              'sender': 'peer',
            },
          ], expectedEpoch: 0);
          await queue.remove('pending');
          await store.collectDeferredMedia(mediaCleanup: cleanup);
          expect(await sent.read(identity, 0, bytes.length), bytes);
          await store.clear('direct:other', mediaCleanup: cleanup);
          await store.collectDeferredMedia(mediaCleanup: cleanup);
          expect(await sent.read(identity, 0, bytes.length), isNull);
          expect(await sent.isRetained(identity), isFalse);
        } finally {
          await store.close();
          await root.delete(recursive: true);
        }
      },
    );
    test(
      'deferred voice source survives restart and waits for all references ($group)',
      () async {
        final root = await Directory.systemTemp.createTemp('chat-deferred-');
        final key = await AesGcm.with256bits().newSecretKey();
        final queue = PendingReferences();
        final cache = MediaCache(
          directory: () async => Directory('${root.path}/media'),
        );
        final cleanup = ChatMediaCleanup(media: cache);
        final conversation = group ? 'group:g' : 'direct:peer';
        final message = <String, dynamic>{
          'sequence': 1,
          'messageId': 'm1',
          'clientMessageId': 'c1',
          'sender': 'me',
          'messageType': 'voice',
          'voiceAssetId': 'voice-asset',
          'voiceDurationMs': 3000,
          'text': 'deleted-body-must-not-survive',
        };
        Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
          factory: databaseFactoryFfi,
          file: '${root.path}/history.db',
          key: key,
          account: 'me',
          outbox: queue,
        );
        var store = await open();
        try {
          for (final name in [
            'chat-voice-asset:voice-asset',
            'chat-voice:me:voice-asset',
          ]) {
            await cache.importBytes(
              Uint8List.fromList([1, 2, 3]),
              scope: 'member:me',
              contentKey: name,
              kind: MediaKind.audio,
            );
          }
          await store.commit(conversation, [message], expectedEpoch: 0);
          await queue.put({...message, 'clientMessageId': 'pending'});
          await store.clear(conversation, mediaCleanup: cleanup);
          expect((await store.read(conversation)).messages, isEmpty);
          await store.close();
          store = await open();
          await store.collectDeferredMedia(mediaCleanup: cleanup);
          expect(
            await cache.cached(
              scope: 'member:me',
              contentKey: 'chat-voice-asset:voice-asset',
              kind: MediaKind.audio,
            ),
            isNotNull,
          );
          // A different conversation remains an owner even after the queue drains.
          await store.commit('direct:other', [
            {...message, 'messageId': 'm2'},
          ], expectedEpoch: 0);
          await queue.remove('pending');
          await store.collectDeferredMedia(mediaCleanup: cleanup);
          expect(
            await cache.cached(
              scope: 'member:me',
              contentKey: 'chat-voice-asset:voice-asset',
              kind: MediaKind.audio,
            ),
            isNotNull,
          );
          await store.clear('direct:other', mediaCleanup: cleanup);
          await store.collectDeferredMedia(mediaCleanup: cleanup);
          for (final name in [
            'chat-voice-asset:voice-asset',
            'chat-voice:me:voice-asset',
          ]) {
            await expectLater(
              cache.cached(
                scope: 'member:me',
                contentKey: name,
                kind: MediaKind.audio,
              ),
              throwsStateError,
            );
          }
        } finally {
          await store.close();
          await root.delete(recursive: true);
        }
      },
    );
  }
}
