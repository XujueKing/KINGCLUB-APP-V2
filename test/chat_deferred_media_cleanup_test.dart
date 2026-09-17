import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';
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
