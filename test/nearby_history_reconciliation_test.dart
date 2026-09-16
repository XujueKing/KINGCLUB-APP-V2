import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

void main() {
  sqfliteFfiInit();
  test(
    'confirmed page atomically reconciles only its bound member devices',
    () async {
      final dir = await Directory.systemTemp.createTemp('bound-peer-history-');
      final store = await ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: '${dir.path}/history.db',
        key: await AesGcm.with256bits().newSecretKey(),
        account: 'alice',
      );
      addTearDown(() async {
        await store.close();
        await dir.delete(recursive: true);
      });
      final first = 'novovm-ed25519:${'ab' * 32}';
      final second = 'novovm-ed25519:${'cd' * 32}';
      final unknown = 'novovm-ed25519:${'ef' * 32}';
      const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      for (final device in [first, second, unknown]) {
        await store.persistNearbyText(
          peerId: device,
          peerAccount: device == unknown ? null : 'bob',
          id: id,
          text: 'same message',
          outgoing: true,
        );
      }
      final confirmed = <String, dynamic>{
        'messageId': 'server-one',
        'clientMessageId': id,
        'sequence': 1,
        'sender': 'alice',
        'recipient': 'bob',
        'text': 'same message',
      };
      expect(
        await store.commit('direct:bob', [confirmed], expectedEpoch: 1),
        false,
      );
      expect((await store.nearbyMessages(first, pendingOnly: true)).length, 1);
      await expectLater(
        store.commit('direct:bob', [
          {...confirmed, 'text': 'conflict'},
        ], expectedEpoch: 0),
        throwsStateError,
      );
      expect((await store.read('direct:bob')).messages, isEmpty);
      expect(
        await store.commit('direct:bob', [confirmed], expectedEpoch: 0),
        true,
      );
      for (final device in [first, second]) {
        expect(await store.nearbyMessages(device, pendingOnly: true), isEmpty);
        final row = (await store.nearbyMessages(device)).single;
        expect(row['serverMessageId'], 'server-one');
        expect(row['delivered'], false);
      }
      expect(
        (await store.nearbyMessages(unknown, pendingOnly: true)).length,
        1,
      );
      await expectLater(
        store.persistNearbyText(
          peerId: first,
          peerAccount: 'outsider',
          id: id,
          text: 'same message',
          outgoing: true,
        ),
        throwsStateError,
      );
      expect(
        (await store.read('direct:bob')).messages.single['messageId'],
        'server-one',
      );
    },
  );
  test('real SQLite upgrade and scoped server reconciliation persist across reopen', () async {
    final dir = await Directory.systemTemp.createTemp('peer-reconciliation-');
    final file = '${dir.path}/history.db';
    final old = await databaseFactoryFfi.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE message (conversation TEXT NOT NULL, sequence INTEGER NOT NULL, payload BLOB NOT NULL, PRIMARY KEY(conversation,sequence))',
          );
          await db.execute(
            'CREATE TABLE nearby_message (peer TEXT NOT NULL, id TEXT NOT NULL, outgoing INTEGER NOT NULL, delivered INTEGER NOT NULL DEFAULT 0, created INTEGER NOT NULL, payload BLOB NOT NULL, PRIMARY KEY(peer,id,outgoing))',
          );
        },
      ),
    );
    await old.close();
    final key = await AesGcm.with256bits().newSecretKey();
    Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
      factory: databaseFactoryFfi,
      file: file,
      key: key,
      account: 'alice',
    );
    var store = await open();
    addTearDown(() async {
      await store.close();
      await dir.delete(recursive: true);
    });
    final peer = 'novovm-ed25519:${'ab' * 32}';
    const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const second = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    for (final messageId in [id, second]) {
      await store.persistNearbyText(
        peerId: peer,
        id: messageId,
        text: 'hello',
        outgoing: true,
      );
    }
    await store.persistNearbyText(
      peerId: peer,
      id: id,
      text: 'reply',
      outgoing: false,
    );
    Map<String, dynamic> confirmed(
      String client, {
      String text = 'hello',
      String sender = 'alice',
      String recipient = 'bob',
      String? type,
    }) => {
      'messageId': 'server-$client',
      'clientMessageId': client,
      'sequence': 1,
      'sender': sender,
      'recipient': recipient,
      'text': text,
      'messageType': ?type,
    };
    Future<int> reconcile(List<Map<String, dynamic>> rows) => store
        .reconcileNearbyText(peerId: peer, peerAccount: 'bob', confirmed: rows);
    expect(await reconcile([confirmed(id, recipient: 'outsider')]), 0);
    expect(await reconcile([confirmed(id, type: 'voice')]), 0);
    await expectLater(
      reconcile([confirmed(id), confirmed(second, text: 'conflict')]),
      throwsStateError,
    );
    expect((await store.nearbyMessages(peer, pendingOnly: true)).length, 2);
    expect(await reconcile([confirmed(id)]), 1);
    expect(await reconcile([confirmed(id)]), 0);
    final outgoing = (await store.nearbyMessages(peer))
        .singleWhere((m) => m['id'] == id && m['outgoing'] == true);
    expect(outgoing['serverMessageId'], 'server-$id');
    expect(outgoing['delivered'], false);
    expect(
      await reconcile([
        confirmed(id, text: 'reply', sender: 'bob', recipient: 'alice'),
      ]),
      1,
    );
    expect(await reconcile([confirmed(second, text: '', type: 'recalled')]), 1);
    expect(await store.nearbyMessages(peer, pendingOnly: true), isEmpty);
    await store.close();
    store = await open();
    expect((await store.nearbyMessages(peer)).length, 2);
    expect(await store.nearbyMessages(peer, pendingOnly: true), isEmpty);
    expect(await store.confirmNearbyReceipt(peerId: peer, id: id), true);
    expect(
      (await store.nearbyMessages(peer)).singleWhere(
        (m) => m['id'] == id && m['outgoing'] == true,
      )['delivered'],
      true,
    );
  });
}
