import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_inbox.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'chat_voice_prefetch_test.dart' show rows, grant, asset;

class DiskVoiceMedia extends MediaCache {
  DiskVoiceMedia(Directory root) : super(directory: () async => root);
  int downloads = 0;
  @override
  Future<File> get(
    String url, {
    required String scope,
    String? contentKey,
    MediaKind kind = MediaKind.image,
    Map<String, String>? headers,
  }) async {
    downloads++;
    return importBytes(
      Uint8List.fromList([1, 2, 3]),
      scope: scope,
      contentKey: contentKey!,
      kind: kind,
    );
  }
}

void main() {
  sqfliteFfiInit();
  for (final group in [false, true]) {
    for (final clearDuringRequest in [false, true]) {
      test(
        'unopened voice ownership survives restart; group=$group late=$clearDuringRequest',
        () async {
          final root = await Directory.systemTemp.createTemp(
            'voice-inbox-history-',
          );
          final key = await AesGcm.with256bits().newSecretKey();
          Future<ChatHistoryStore> open() =>
              ChatHistoryStore.openDatabaseWithKey(
                factory: databaseFactoryFfi,
                file: '${root.path}/history.db',
                account: 'me',
                key: key,
              );
          var history = await open();
          final media = DiskVoiceMedia(Directory('${root.path}/media'));
          final requested = Completer<void>();
          final response = Completer<Map<String, dynamic>>();
          final historyKey = '${group ? 'group' : 'direct'}:peer';
          final inbox = ChatVoiceInbox(
            MessagingRepository(
              account: 'me',
              call: (method, _) async {
                if (method == 'K260913000638' || method == 'K260913000640') {
                  final value = grant();
                  if (group) {
                    (value['voice'] as Map)['path'] =
                        '/kingclub/group-chat-voice/${rows.single['messageId']}';
                  }
                  return value;
                }
                requested.complete();
                return response.future;
              },
            ),
            media: media,
            openHistory: () async => history,
          );
          try {
            inbox.update([
              {
                if (group) 'kind': 'group',
                group ? 'groupId' : 'peer': 'peer',
                'lastSequence': 1,
                'unreadCount': 1,
              },
            ]);
            await requested.future;
            if (clearDuringRequest) {
              await history.clear(
                historyKey,
                mediaCleanup: ChatMediaCleanup(media: media),
              );
            }
            response.complete({
              'messages': [
                {
                  ...rows.single,
                  'sequence': 1,
                  'clientMessageId': 'client',
                  'text': '',
                  if (group) 'groupId': 'peer',
                },
              ],
              'settings': {'hiddenThrough': 0},
              'historyVersion': 1,
              if (group) 'membershipVersion': 1,
              if (group) 'joinedSequence': 0,
              'hasMore': false,
            });
            await inbox.idle;
            inbox.dispose();
            await history.close();
            history = await open();
            final page = await history.read(historyKey);
            expect(
              page.cursor,
              0,
              reason: 'Prefetch must not skip foreground sync',
            );
            expect(page.messages, hasLength(clearDuringRequest ? 0 : 1));
            expect(media.downloads, clearDuringRequest ? 0 : 1);
            if (!clearDuringRequest) {
              final file = await media.cached(
                scope: 'member:me',
                contentKey: 'chat-voice-asset:$asset',
                kind: MediaKind.audio,
              );
              expect(await file.exists(), true);
              await history.clear(
                historyKey,
                mediaCleanup: ChatMediaCleanup(media: media),
              );
              expect(await file.exists(), false);
              expect((await history.read(historyKey)).messages, isEmpty);
            }
          } finally {
            inbox.dispose();
            await history.close();
            await root.delete(recursive: true);
          }
        },
      );
    }
  }
}
