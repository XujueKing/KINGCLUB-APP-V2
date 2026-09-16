import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';
import 'package:kingclub/src/core/media/media_cache.dart';

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
  Future<ChatHistoryStore> open({String account = 'me', SecretKey? otherKey}) =>
      ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: '${dir.path}/history.db',
        key: otherKey ?? key,
        account: account,
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
