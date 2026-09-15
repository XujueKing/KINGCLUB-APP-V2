import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

void main() {
  sqfliteFfiInit();
  test('real SQLite upgrade and scoped server reconciliation persist across reopen', () async {
    final dir = await Directory.systemTemp.createTemp('peer-reconciliation-');
    final file = '${dir.path}/history.db';
    final old = await databaseFactoryFfi.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, _) async {
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
    expect((await store.nearbyMessages(peer)).length, 3);
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
