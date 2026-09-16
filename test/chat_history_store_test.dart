import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';

class PendingOutbox implements ChatOutbox {
  PendingOutbox(this.items);
  final List<Map<String, dynamic>> items;
  @override
  Future<List<Map<String, dynamic>>> read() async => List.of(items);
  @override
  Future<void> put(Map<String, dynamic> message) async => items.add(message);
  @override
  Future<void> remove(String id) async =>
      items.removeWhere((row) => row['clientMessageId'] == id);
}

Map<String, dynamic> message(int sequence) => {
  'sequence': sequence,
  'messageId': 'm-$sequence',
  'clientMessageId': 'c-$sequence',
  'sender': 'peer',
  'recipient': 'me',
  'text': 'Private payload $sequence',
  'headers': {'Authorization': 'DO_NOT_PERSIST'},
  'media': {'url': 'https://secret.test'},
};
void main() {
  sqfliteFfiInit();
  late Directory dir;
  late SecretKey key;
  late ChatHistoryStore store;
  Future<ChatHistoryStore> open({
    String account = 'me',
    SecretKey? otherKey,
    ChatOutbox? outbox,
  }) => ChatHistoryStore.openDatabaseWithKey(
    factory: databaseFactoryFfi,
    file: '${dir.path}/history.db',
    key: otherKey ?? key,
    account: account,
    outbox: outbox,
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('chat-history-');
    key = await AesGcm.with256bits().newSecretKey();
    store = await open();
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  for (final kind in ['hidden', 'recalled']) {
    test(
      '$kind persists identity without deleted content or asset metadata',
      () async {
        await store.commit('direct:peer', [
          {
            ...message(1),
            'messageType': kind,
            'imageAssetId': 'private-image',
            'voiceAssetId': 'private-voice',
            'voiceDurationMs': 1500,
            'videoAssetId': 'private-video',
            'videoDurationMs': 2000,
            'videoWidth': 100,
            'videoHeight': 100,
            'videoHasAudio': true,
            'fileAssetId': 'private-file',
            'fileName': 'private-name.pdf',
            'fileSize': 200,
            'fileSha256': 'private-hash',
            'location': {'label': 'private-place'},
            'reply': {'text': 'private-reply'},
            'call': {'private': true},
          },
        ], expectedEpoch: 0);
        await store.close();
        store = await open();
        final row = (await store.read('direct:peer')).messages.single;
        expect(row, {
          'messageId': 'm-1',
          'clientMessageId': 'c-1',
          'sender': 'peer',
          'recipient': 'me',
          'sequence': 1,
          'messageType': kind,
          'text': kind == 'recalled' ? '消息已撤回' : '',
          'status': 'sent',
        });
      },
    );
  }
  for (final group in [false, true]) {
    test(
      'deleting latest message removes persisted preview only: group=$group',
      () async {
        final conversation = group ? 'group:peer' : 'direct:peer';
        await store.commit(conversation, [
          message(1),
          message(2),
        ], expectedEpoch: 0);
        final target = <String, dynamic>{
          'kind': group ? 'group' : 'direct',
          if (group) 'groupId': 'peer' else 'peer': 'peer',
          'preview': 'Private payload 2',
          'lastSequence': 2,
          'unreadCount': 2,
        };
        final other = <String, dynamic>{
          'kind': group ? 'direct' : 'group',
          if (group) 'peer': 'peer' else 'groupId': 'peer',
          'preview': 'Other conversation',
          'lastSequence': 2,
          'unreadCount': 5,
        };
        await store.saveConversationList([target, other]);
        await store.clear(conversation, deletedMessageIds: {'m-1'});
        expect(await store.readConversationList(), [target, other]);
        final removed = store.clearedConversations.first;
        final beforeDelete = store.conversationListRevision;
        await store.clear(conversation, deletedMessageIds: {'m-2'});
        final event = await removed;
        final displayed = [
          Map<String, dynamic>.of(target),
          Map<String, dynamic>.of(other),
        ];
        event.applyTo(displayed);
        expect(displayed.first['preview'], '');
        expect(displayed.first['unreadCount'], 2);
        expect(displayed.last, other);
        await store.saveConversationList([
          target,
          other,
        ], expectedRevision: beforeDelete);
        await store.close();
        store = await open();
        expect(await store.readConversationList(), displayed);
      },
    );
  }
  for (final kind in ['hidden', 'recalled', 'floor']) {
    for (final saved in ['none', 'other-marker', 'message']) {
      test(
        'remote $kind cleans preview once and rejects stale list writes: saved=$saved',
        () async {
          if (saved != 'none') {
            await store.commit('direct:peer', [
              saved == 'message'
                  ? message(1)
                  : {...message(2), 'messageType': 'hidden', 'text': ''},
            ], expectedEpoch: 0);
          }
          final row = <String, dynamic>{
            'kind': 'direct',
            'peer': 'peer',
            'preview': 'Private payload 1',
            'lastSequence': 1,
            'unreadCount': 1,
          };
          await store.saveConversationList([row]);
          final revision = store.conversationListRevision;
          final events = <ConversationHistoryRemoval>[];
          final subscription = store.clearedConversations.listen(events.add);
          addTearDown(subscription.cancel);
          final rows = kind == 'floor'
              ? <Map<String, dynamic>>[
                  {...message(1), 'messageType': 'hidden', 'text': ''},
                ]
              : [
                  {...message(1), 'messageType': kind, 'text': ''},
                  if (saved == 'other-marker')
                    {...message(2), 'messageType': 'hidden', 'text': ''},
                ];
          Future<bool> update(int epoch) => store.commit(
            'direct:peer',
            rows,
            expectedEpoch: epoch,
            hiddenThrough: kind == 'floor' ? 1 : 0,
          );
          expect(await update(99), false);
          expect(await store.readConversationList(), [row]);
          expect(await update(0), true);
          await Future<void>.delayed(Duration.zero);
          expect(events, hasLength(1));
          final afterFirst = store.conversationListRevision;
          expect(afterFirst, greaterThan(revision));
          expect(await update(0), true);
          await Future<void>.delayed(Duration.zero);
          expect(events, hasLength(1));
          expect(store.conversationListRevision, afterFirst);
          await store.saveConversationList([row], expectedRevision: revision);
          final snapshot = await store.readConversationList();
          if (kind == 'floor') {
            expect(snapshot, isEmpty);
          } else {
            expect(snapshot.single['preview'], '');
            expect(snapshot.single['unreadCount'], 1);
          }
          await subscription.cancel();
          await store.close();
          store = await open();
          expect(await store.readConversationList(), snapshot);
        },
      );
    }
  }
  for (final remote in [false, true]) {
    test(
      'last received file reference releases sent source remote=$remote',
      () async {
        const asset = '12345678-1234-1234-1234-123456789012';
        final bytes = Uint8List.fromList([1, 2, 3]);
        final hash = (await Sha256().hash(bytes)).bytes
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();
        final sent = ChatDownloadCache(
          root: Directory('${dir.path}/sent'),
          key: key,
        );
        final downloads = ChatDownloadCache(
          root: Directory('${dir.path}/downloads'),
          key: key,
        );
        final identity = jsonEncode(['sent-file-v1', asset, 3, hash]);
        await sent.write(identity, 0, bytes);
        await sent.retainCompleted(identity);
        final cleanup = ChatMediaCleanup(
          downloadCache: (_) async => downloads,
          sentFileCache: (_) async => sent,
        );
        Map<String, dynamic> file(String sender) => {
          ...message(1),
          'messageType': 'file',
          'sender': sender,
          'fileAssetId': asset,
          'fileSize': 3,
          'fileSha256': hash,
          'fileName': 'shared.bin',
        };
        await store.commit('direct:peer', [file('me')], expectedEpoch: 0);
        await store.commit('group:other', [file('peer')], expectedEpoch: 0);
        await store.clear('direct:peer', mediaCleanup: cleanup);
        expect(await sent.read(identity, 0, 3), bytes);
        await store.close();
        store = await open();
        if (remote) {
          await store.commit(
            'group:other',
            [
              {...message(1), 'messageType': 'recalled'},
            ],
            expectedEpoch: 0,
            mediaCleanup: cleanup,
          );
        } else {
          await store.clear('group:other', mediaCleanup: cleanup);
        }
        final reopened = ChatDownloadCache(root: sent.root, key: key);
        expect(await reopened.read(identity, 0, 3), isNull);
        expect(await reopened.isRetained(identity), false);
      },
    );
  }
  test(
    'remote tombstones preserve shared voice until final reference',
    () async {
      final media = MediaCache(
        directory: () async => Directory('${dir.path}/media'),
      );
      final cleanup = ChatMediaCleanup(media: media);
      final file = await media.importBytes(
        Uint8List.fromList([1]),
        scope: 'member:me',
        contentKey: 'chat-voice-asset:shared',
        kind: MediaKind.audio,
      );
      await store.commit('direct:peer', [
        for (var i = 1; i <= 2; i++)
          {...message(i), 'messageType': 'voice', 'voiceAssetId': 'shared'},
      ], expectedEpoch: 0);
      await store.commit(
        'direct:peer',
        [
          {...message(1), 'messageType': 'recalled'},
        ],
        expectedEpoch: 0,
        mediaCleanup: cleanup,
      );
      expect(await file.exists(), true);
      await store.commit(
        'direct:peer',
        [
          {...message(2), 'messageType': 'hidden'},
        ],
        expectedEpoch: 0,
        mediaCleanup: cleanup,
      );
      expect(await file.exists(), false);
    },
  );
  for (final group in [false, true]) {
    for (final action in ['recalled', 'hidden', 'clear']) {
      test(
        'remote $action cleans media after invalidation group=$group',
        () async {
          final media = MediaCache(
            directory: () async => Directory('${dir.path}/media'),
          );
          final cleanup = ChatMediaCleanup(media: media);
          final conversation = '${group ? 'group' : 'direct'}:peer';
          final files = <File>[];
          for (var i = 1; i <= 2; i++) {
            files.add(
              await media.importBytes(
                Uint8List.fromList([i]),
                scope: 'member:me',
                contentKey: 'chat-image-message:$group:m-$i:image',
                kind: MediaKind.image,
              ),
            );
          }
          await store.commit(
            conversation,
            [
              for (var i = 1; i <= 2; i++)
                {...message(i), 'messageType': 'image'},
            ],
            expectedEpoch: 0,
            cursor: 2,
          );
          final epoch = (await store.adoptHistoryVersion(
            conversation,
            expectedEpoch: 0,
            historyVersion: 1,
          ))!;
          // A late pre-revision response must not delete even local media.
          expect(
            await store.commit(
              conversation,
              [],
              expectedEpoch: 0,
              historyVersion: 1,
              hiddenThrough: 2,
              mediaCleanup: cleanup,
            ),
            false,
          );
          expect(await files.first.exists(), true);
          await store.commit(
            conversation,
            [
              if (action != 'clear')
                {...message(1), 'messageType': action, 'text': ''},
              {...message(2), 'messageType': 'image'},
            ],
            expectedEpoch: epoch,
            historyVersion: 1,
            hiddenThrough: action == 'clear' ? 1 : 0,
            mediaCleanup: cleanup,
          );
          expect(await files.first.exists(), false);
          expect(await files.last.exists(), true);
          await expectLater(
            media.importBytes(
              Uint8List.fromList([1]),
              scope: 'member:me',
              contentKey: 'chat-image-message:$group:m-1:image',
              kind: MediaKind.image,
            ),
            throwsStateError,
          );
        },
      );
    }
  }
  for (final revision in [false, true]) {
    test(
      'invalidated history remains cleanable after restart revision=$revision',
      () async {
        final media = MediaCache(
          directory: () async => Directory('${dir.path}/media'),
        );
        final file = await media.importBytes(
          Uint8List.fromList([1, 2, 3]),
          scope: 'member:me',
          contentKey: 'chat-image-message:false:m-1:image',
          kind: MediaKind.image,
        );
        await store.commit(
          'direct:peer',
          [
            {...message(1), 'messageType': 'image'},
          ],
          expectedEpoch: 0,
          cursor: 1,
        );
        if (revision) {
          await store.adoptHistoryVersion(
            'direct:peer',
            expectedEpoch: 0,
            historyVersion: 1,
          );
        } else {
          await store.clear('direct:peer', deleteMedia: false);
        }
        await store.close();
        store = await open();
        expect((await store.read('direct:peer')).messages, isEmpty);
        expect(await file.exists(), true);
        await store.clear(
          'direct:peer',
          mediaCleanup: ChatMediaCleanup(media: media),
        );
        expect(await file.exists(), false);
      },
    );
  }
  test(
    'clear preserves media still owned by pending outgoing messages',
    () async {
      const asset = '12345678-1234-1234-1234-123456789012';
      final voice = {
        ...message(1),
        'sender': 'me',
        'messageType': 'voice',
        'voiceAssetId': asset,
      };
      final image = {...message(2), 'sender': 'me', 'messageType': 'image'};
      final outbox = PendingOutbox([voice, image]);
      await store.close();
      store = await open(outbox: outbox);
      final media = MediaCache(
        directory: () async => Directory('${dir.path}/media'),
      );
      await media.importBytes(
        Uint8List.fromList([1]),
        scope: 'member:me',
        contentKey: 'chat-voice-asset:$asset',
        kind: MediaKind.audio,
      );
      await media.importBytes(
        Uint8List.fromList([2]),
        scope: 'member:me',
        contentKey: 'chat-image-sent:c-2',
        kind: MediaKind.image,
      );
      await store.commit(
        'direct:peer',
        [voice, image],
        expectedEpoch: 0,
        cursor: 2,
      );
      await store.clear(
        'direct:peer',
        mediaCleanup: ChatMediaCleanup(media: media),
      );
      expect((await store.read('direct:peer')).messages, isEmpty);
      expect(await outbox.read(), [voice, image]);
      expect(
        await media.cached(
          scope: 'member:me',
          contentKey: 'chat-voice-asset:$asset',
          kind: MediaKind.audio,
        ),
        isNotNull,
      );
      expect(
        await media.cached(
          scope: 'member:me',
          contentKey: 'chat-image-sent:c-2',
          kind: MediaKind.image,
        ),
        isNotNull,
      );
    },
  );
  test(
    'clear preserves shared voice until last persisted reference is removed',
    () async {
      final media = MediaCache(
        directory: () async => Directory('${dir.path}/media'),
      );
      final cleanup = ChatMediaCleanup(media: media);
      const asset = '12345678-1234-1234-1234-123456789012';
      Map<String, dynamic> voice(int sequence) => {
        ...message(sequence),
        'messageType': 'voice',
        'voiceAssetId': asset,
        'voiceDurationMs': 3000,
      };
      await media.importBytes(
        Uint8List.fromList([1, 2, 3]),
        scope: 'member:me',
        contentKey: 'chat-voice-asset:$asset',
        kind: MediaKind.audio,
      );
      await store.commit(
        'direct:peer',
        [voice(1)],
        expectedEpoch: 0,
        cursor: 1,
      );
      await store.commit(
        'direct:other',
        [for (var i = 1; i <= 50; i++) message(i), voice(51)],
        expectedEpoch: 0,
        cursor: 51,
      );
      await store.clear('direct:peer', mediaCleanup: cleanup);
      expect((await store.read('direct:peer')).messages, isEmpty);
      expect(
        await (await media.cached(
          scope: 'member:me',
          contentKey: 'chat-voice-asset:$asset',
          kind: MediaKind.audio,
        )).readAsBytes(),
        [1, 2, 3],
      );
      await store.clear('direct:other', mediaCleanup: cleanup);
      final reopened = MediaCache(
        directory: () async => Directory('${dir.path}/media'),
      );
      await expectLater(
        reopened.cached(
          scope: 'member:me',
          contentKey: 'chat-voice-asset:$asset',
          kind: MediaKind.audio,
        ),
        throwsStateError,
      );
      expect((await store.read('direct:other')).messages, isEmpty);
    },
  );
  test('refresh keeps attachments and targeted deletion only removes selected media', () async {
    final media = MediaCache(
      directory: () async => Directory('${dir.path}/media'),
    );
    final cleanup = ChatMediaCleanup(media: media);
    final rows = [
      for (var i = 1; i <= 2; i++) {...message(i), 'messageType': 'image'},
    ];
    for (var i = 1; i <= 2; i++) {
      await media.importBytes(
        Uint8List.fromList([i]),
        scope: 'member:me',
        contentKey: 'chat-image-message:false:m-$i:image',
        kind: MediaKind.image,
      );
    }
    await store.commit('direct:peer', rows, expectedEpoch: 0, cursor: 2);
    final epoch = await store.clear(
      'direct:peer',
      deleteMedia: false,
      mediaCleanup: cleanup,
    );
    expect(
      await media.cached(
        scope: 'member:me',
        contentKey: 'chat-image-message:false:m-1:image',
        kind: MediaKind.image,
      ),
      isNotNull,
    );
    await store.commit('direct:peer', rows, expectedEpoch: epoch, cursor: 2);
    await store.clear(
      'direct:peer',
      deletedMessageIds: {'m-1'},
      mediaCleanup: cleanup,
    );
    await expectLater(
      media.cached(
        scope: 'member:me',
        contentKey: 'chat-image-message:false:m-1:image',
        kind: MediaKind.image,
      ),
      throwsStateError,
    );
    expect(
      await media.cached(
        scope: 'member:me',
        contentKey: 'chat-image-message:false:m-2:image',
        kind: MediaKind.image,
      ),
      isNotNull,
    );
    await store.close();
    store = await open();
    expect(
      (await store.read('direct:peer')).messages.map((row) => row['messageId']),
      ['m-2'],
    );
    // No network resync between these deletions: the second attachment must
    // still have its ownership metadata and be cleaned by a subsequent clear.
    await store.clear('direct:peer', mediaCleanup: cleanup);
    await expectLater(
      media.cached(
        scope: 'member:me',
        contentKey: 'chat-image-message:false:m-2:image',
        kind: MediaKind.image,
      ),
      throwsStateError,
    );
  });
  test('call metadata survives reopen but hidden records lose it', () async {
    final call = {
      'callId': '00000000-0000-4000-8000-000000000001',
      'mediaKind': 'audio',
      'endReason': 'missed',
      'durationMs': null,
      'privateUrl': 'must-not-persist',
    };
    await store.commit(
      'direct:peer',
      [
        {...message(1), 'call': call},
        {...message(2), 'call': call, 'messageType': 'hidden', 'text': ''},
      ],
      expectedEpoch: 0,
      cursor: 2,
    );
    await store.close();
    store = await open();
    final rows = (await store.read('direct:peer')).messages;
    expect(rows.first['call'], {
      'callId': call['callId'],
      'mediaKind': 'audio',
      'endReason': 'missed',
      'durationMs': null,
    });
    expect(rows.last.containsKey('call'), false);
  });
  test(
    'recall revision invalidates old disk pages and rejects delayed writes',
    () async {
      await store.commit(
        'direct:peer',
        [message(1)],
        expectedEpoch: 0,
        cursor: 1,
      );
      final epoch = await store.adoptHistoryVersion(
        'direct:peer',
        expectedEpoch: 0,
        historyVersion: 1,
      );
      expect(epoch, 1);
      expect((await store.read('direct:peer')).messages, isEmpty);
      expect(
        await store.commit(
          'direct:peer',
          [message(1)],
          expectedEpoch: 0,
          cursor: 1,
        ),
        false,
      );
      expect(
        await store.commit(
          'direct:peer',
          [message(1)],
          expectedEpoch: 1,
          cursor: 1,
        ),
        false,
      );
      expect(
        await store.commit(
          'direct:peer',
          [
            {...message(1), 'messageType': 'recalled', 'text': '消息已撤回'},
          ],
          expectedEpoch: 1,
          historyVersion: 1,
          cursor: 1,
        ),
        true,
      );
      await store.close();
      store = await open();
      final page = await store.read('direct:peer');
      expect(page.historyVersion, 1);
      expect(page.messages.single['messageType'], 'recalled');
      expect(
        await store.adoptHistoryVersion(
          'direct:peer',
          expectedEpoch: 1,
          historyVersion: 0,
        ),
        isNull,
      );
      expect(
        await store.adoptHistoryVersion(
          'direct:peer',
          expectedEpoch: 1,
          historyVersion: 1,
        ),
        1,
      );
      expect(
        await store.adoptHistoryVersion(
          'direct:peer',
          expectedEpoch: 1,
          historyVersion: 2,
        ),
        2,
      );
      expect((await store.read('direct:peer')).cursor, 0);
      expect((await store.read('direct:peer')).messages, isEmpty);
    },
  );
  test(
    'file metadata survives encrypted history reopen without download grants',
    () async {
      await store.commit(
        'direct:peer',
        [
          {
            ...message(1),
            'messageType': 'file',
            'fileAssetId': '12345678-1234-1234-1234-123456789012',
            'fileName': 'private-fixture.txt',
            'fileSize': 123,
            'fileSha256': 'a' * 64,
            'fileDownloadToken': 'NEVER_STORE_TOKEN',
          },
        ],
        expectedEpoch: 0,
        cursor: 1,
      );
      await store.close();
      store = await open();
      final saved = (await store.read('direct:peer')).messages.single;
      expect(saved['fileName'], 'private-fixture.txt');
      expect(saved['fileSize'], 123);
      expect(saved['fileSha256'], 'a' * 64);
      expect(saved.containsKey('fileDownloadToken'), false);
      final raw = String.fromCharCodes(
        await File('${dir.path}/history.db').readAsBytes(),
      );
      expect(raw.contains('private-fixture.txt'), false);
      expect(raw.contains('NEVER_STORE_TOKEN'), false);
    },
  );
  test(
    'encrypted disk pages survive reopen and strip transport credentials',
    () async {
      await store.commit(
        'direct:peer',
        [message(1), message(2), message(3)],
        expectedEpoch: 0,
        cursor: 3,
      );
      await store.close();
      store = await open();
      final page = await store.read('direct:peer', limit: 2);
      expect(page.messages.map((m) => m['sequence']), [2, 3]);
      expect(page.cursor, 3);
      expect(page.messages.first.containsKey('headers'), false);
      expect(page.messages.first.containsKey('media'), false);
      expect(
        (await store.read(
          'direct:peer',
          before: 2,
        )).messages.single['sequence'],
        1,
      );
      final bytes = await File('${dir.path}/history.db').readAsBytes();
      final raw = String.fromCharCodes(bytes);
      expect(raw.contains('Private payload'), false);
      expect(raw.contains('DO_NOT_PERSIST'), false);
    },
  );
  test(
    'clear advances epoch and rejects old pages and cursor resurrection',
    () async {
      await store.commit(
        'direct:peer',
        [message(1)],
        expectedEpoch: 0,
        cursor: 1,
      );
      final epoch = await store.clear('direct:peer');
      expect(epoch, 1);
      expect(
        await store.commit(
          'direct:peer',
          [message(2)],
          expectedEpoch: 0,
          cursor: 2,
        ),
        false,
      );
      expect((await store.read('direct:peer')).messages, isEmpty);
      expect((await store.read('direct:peer')).cursor, 0);
      expect(
        await store.commit(
          'direct:peer',
          [message(3)],
          expectedEpoch: epoch,
          cursor: 3,
        ),
        true,
      );
    },
  );
  test('account and conversation identities isolate records', () async {
    await store.commit(
      'direct:peer',
      [message(1)],
      expectedEpoch: 0,
      cursor: 1,
    );
    expect((await store.read('group:peer')).messages, isEmpty);
    await store.close();
    store = await open(account: 'other');
    expect((await store.read('direct:peer')).messages, isEmpty);
  });
  test('invalid batch leaves both messages and checkpoint unchanged', () async {
    await expectLater(
      store.commit(
        'direct:peer',
        [
          message(1),
          {...message(2), 'text': null},
        ],
        expectedEpoch: 0,
        cursor: 2,
      ),
      throwsFormatException,
    );
    final page = await store.read('direct:peer');
    expect(page.messages, isEmpty);
    expect(page.cursor, 0);
  });
  test('moving ciphertext to another sequence fails authentication', () async {
    await store.commit(
      'direct:peer',
      [message(1)],
      expectedEpoch: 0,
      cursor: 1,
    );
    final db = await databaseFactoryFfi.openDatabase('${dir.path}/history.db');
    await db.update('message', {'sequence': 2});
    await expectLater(
      store.read('direct:peer'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
  test(
    'remote clear floor prunes old rows and rejects late page resurrection',
    () async {
      await store.commit(
        'direct:peer',
        [message(1), message(2), message(3)],
        expectedEpoch: 0,
        cursor: 3,
      );
      await store.commit('direct:peer', [], expectedEpoch: 0, hiddenThrough: 2);
      expect(
        (await store.read('direct:peer')).messages.map((m) => m['sequence']),
        [3],
      );
      await store.commit(
        'direct:peer',
        [message(1), message(2)],
        expectedEpoch: 0,
        hiddenThrough: 0,
      );
      expect(
        (await store.read('direct:peer')).messages.map((m) => m['sequence']),
        [3],
      );
      await store.close();
      store = await open();
      await store.commit('direct:peer', [message(2)], expectedEpoch: 0);
      expect(
        (await store.read('direct:peer')).messages.map((m) => m['sequence']),
        [3],
      );
    },
  );
  test(
    'version one database upgrades without discarding conversation state',
    () async {
      final file = '${dir.path}/upgrade.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE conversation (id TEXT PRIMARY KEY, cursor INTEGER NOT NULL DEFAULT 0, epoch INTEGER NOT NULL DEFAULT 0)',
            );
            await db.execute(
              'CREATE TABLE message (conversation TEXT NOT NULL, sequence INTEGER NOT NULL, payload BLOB NOT NULL, PRIMARY KEY(conversation, sequence))',
            );
            await db.insert('conversation', {
              'id': 'retained',
              'cursor': 12,
              'epoch': 3,
            });
          },
        ),
      );
      await legacy.close();
      final upgraded = await ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: file,
        key: key,
        account: 'me',
      );
      final db = await databaseFactoryFfi.openDatabase(file);
      final row = (await db.query('conversation')).single;
      expect(row['cursor'], 12);
      expect(row['epoch'], 3);
      expect(row['hiddenThrough'], 0);
      await upgraded.close();
    },
  );
  test('wrong encryption key rejects ciphertext', () async {
    await store.commit(
      'direct:peer',
      [message(1)],
      expectedEpoch: 0,
      cursor: 1,
    );
    await store.close();
    store = await open(otherKey: await AesGcm.with256bits().newSecretKey());
    await expectLater(
      store.read('direct:peer'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
