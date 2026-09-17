import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

void main() {
  sqfliteFfiInit();
  test('v20 migration rolls back earlier reply rewrites on corrupt later ciphertext', () async {
    final dir = await Directory.systemTemp.createTemp('reply-rollback-');
    final file = '${dir.path}/history.db';
    final key = await AesGcm.with256bits().newSecretKey();
    Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
      factory: databaseFactoryFfi,
      file: file,
      key: key,
      account: 'me',
    );
    var store = await open();
    await store.commit('direct:peer', [
      for (var i = 1; i <= 55; i++)
        {
          'messageId': 'reply-$i',
          'clientMessageId': 'client-$i',
          'sequence': i,
          'sender': 'peer',
          'recipient': 'me',
          'text': 'kept body $i',
          'reply': {
            'messageId': '11111111-1111-4111-8111-111111111111',
            'available': true,
            'sequence': 99,
            'text': 'legacy preview',
          },
          'createdDate': '2026-09-17T00:00:00Z',
        },
    ], expectedEpoch: 0);
    await store.close();
    var db = await databaseFactoryFfi.openDatabase(file);
    final original = (await db.query(
      'message',
      where: 'sequence=55',
    )).single['payload'];
    final corrupt = Uint8List.fromList((original as List).cast<int>());
    corrupt[corrupt.length - 1] ^= 1;
    await db.update('message', {'payload': corrupt}, where: 'sequence=55');
    await db.setVersion(19);
    final before = await db.query('message', orderBy: 'sequence');
    await db.close();
    await expectLater(open(), throwsA(isA<SecretBoxAuthenticationError>()));
    db = await databaseFactoryFfi.openDatabase(file);
    expect(await db.getVersion(), 19);
    expect(await db.query('message', orderBy: 'sequence'), before);
    await db.update('message', {'payload': original}, where: 'sequence=55');
    await db.close();
    store = await open();
    final messages = (await store.read('direct:peer', limit: 100)).messages;
    expect(messages, hasLength(55));
    expect(
      messages.every((m) => (m['reply'] as Map)['available'] == false),
      true,
    );
    expect(messages.last['text'], 'kept body 55');
    await store.close();
    await dir.delete(recursive: true);
  });
  for (final mode in ['delete', 'recall', 'clear-floor']) {
    for (final legacy in [false, true]) {
      test(
        'cached replies lose deleted source text across restart: $mode legacy=$legacy',
        () async {
          final dir = await Directory.systemTemp.createTemp('reply-delete-');
          final key = await AesGcm.with256bits().newSecretKey();
          Future<ChatHistoryStore> open() =>
              ChatHistoryStore.openDatabaseWithKey(
                factory: databaseFactoryFfi,
                file: '${dir.path}/history.db',
                key: key,
                account: 'me',
              );
          var store = await open();
          const sourceId = '11111111-1111-4111-8111-111111111111';
          final source = <String, dynamic>{
            'messageId': sourceId,
            'clientMessageId': 'source',
            'sequence': 1,
            'sender': 'peer',
            'recipient': 'me',
            'text': 'private original',
            'createdDate': '2026-09-17T00:00:00Z',
          };
          final reply = {
            ...source,
            'messageId': 'reply',
            'clientMessageId': 'reply',
            'sequence': 2,
            'text': 'kept reply body',
            'reply': {
              'messageId': sourceId,
              'available': true,
              'sequence': 1,
              'text': 'private original',
            },
          };
          await store.commit('direct:peer', [source, reply], expectedEpoch: 0);
          await store.commit('direct:other', [source, reply], expectedEpoch: 0);
          if (legacy) {
            await store.close();
            final raw = await databaseFactoryFfi.openDatabase(
              '${dir.path}/history.db',
            );
            final conversation = (await Sha256().hash(
              utf8.encode('me|direct:peer'),
            )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
            if (mode == 'recall') {
              final box = await AesGcm.with256bits().encrypt(
                utf8.encode(
                  jsonEncode({
                    ...source,
                    'messageType': 'recalled',
                    'text': '消息已撤回',
                  }),
                ),
                secretKey: key,
                aad: utf8.encode('chat-history-v1|me|$conversation|1'),
              );
              await raw.update(
                'message',
                {'payload': box.concatenation()},
                where: 'conversation=? AND sequence=1',
                whereArgs: [conversation],
              );
            } else {
              await raw.delete(
                'message',
                where: 'conversation=? AND sequence=1',
                whereArgs: [conversation],
              );
            }
            if (mode == 'clear-floor') {
              await raw.update(
                'conversation',
                {'hiddenThrough': 1},
                where: 'id=?',
                whereArgs: [conversation],
              );
            }
            await raw.setVersion(19);
            await raw.close();
            store = await open();
          } else if (mode == 'delete') {
            await store.clear('direct:peer', deletedMessageIds: {sourceId});
          } else {
            await store.commit(
              'direct:peer',
              mode == 'recall'
                  ? [
                      {...source, 'messageType': 'recalled'},
                    ]
                  : [],
              expectedEpoch: 0,
              hiddenThrough: mode == 'clear-floor' ? 1 : 0,
            );
          }
          await store.close();
          store = await open();
          final rows = (await store.read('direct:peer')).messages;
          final quoted = rows.singleWhere((r) => r['sequence'] == 2);
          expect(quoted['text'], 'kept reply body');
          expect(quoted['reply'], {'messageId': sourceId, 'available': false});
          expect(
            ((await store.read('direct:other')).messages.last['reply']
                as Map)['available'],
            true,
          );
          await store.close();
          await dir.delete(recursive: true);
        },
      );
    }
  }
}
