import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

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
