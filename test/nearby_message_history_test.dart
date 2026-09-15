import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

void main() {
  sqfliteFfiInit();
  test('nearby text persists encrypted, deduplicates and scopes receipts across reopen', () async {
    final dir = await Directory.systemTemp.createTemp('nearby-history-');
    final file = '${dir.path}/history.db';
    final key = await AesGcm.with256bits().newSecretKey();
    Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
      factory: databaseFactoryFfi,
      file: file,
      key: key,
      account: 'local-member',
    );
    var store = await open();
    addTearDown(() async {
      await store.close();
      await dir.delete(recursive: true);
    });
    final peer = 'novovm-ed25519:${List.filled(64, 'a').join()}';
    final other = 'novovm-ed25519:${List.filled(64, 'b').join()}';
    const id = '00000000-0000-4000-8000-000000000001';
    const text = 'NEARBY_PRIVATE_TEXT_NOT_PLAINTEXT';
    await Future.wait(
      List.generate(
        3,
        (_) => store.persistNearbyText(
          peerId: peer,
          id: id,
          text: text,
          outgoing: true,
        ),
      ),
    );
    expect((await store.nearbyMessages(peer, pendingOnly: true)).length, 1);
    await expectLater(
      store.persistNearbyText(
        peerId: peer,
        id: id,
        text: 'changed',
        outgoing: true,
      ),
      throwsStateError,
    );
    expect(await store.confirmNearbyReceipt(peerId: other, id: id), isFalse);
    await store.close();
    store = await open();
    expect((await store.nearbyMessages(peer)).single['text'], text);
    expect(await store.confirmNearbyReceipt(peerId: peer, id: id), isTrue);
    expect(await store.nearbyMessages(peer, pendingOnly: true), isEmpty);
    await store.persistNearbyText(
      peerId: peer,
      id: id,
      text: 'incoming',
      outgoing: false,
    );
    expect((await store.nearbyMessages(peer)).length, 2);
    await store.close();
    expect(
      latin1.decode(await File(file).readAsBytes()).contains(text),
      isFalse,
    );
    store = await open();
    expect(
      (await store.nearbyMessages(peer))
          .where((m) => m['outgoing'] == true)
          .single['delivered'],
      isTrue,
    );
    const longId = '00000000-0000-4000-8000-000000000002';
    final chinese = List.filled(4000, '中').join();
    await store.persistNearbyText(
      peerId: peer,
      id: longId,
      text: chinese,
      outgoing: true,
    );
    await store.close();
    store = await open();
    expect(
      (await store.nearbyMessages(peer))
          .where((row) => row['id'] == longId)
          .single['text'],
      chinese,
    );
    for (final invalid in [
      List.filled(4001, 'a').join(),
      List.filled(2001, '\u{1f642}').join(),
    ]) {
      await expectLater(
        store.persistNearbyText(
          peerId: peer,
          id: '00000000-0000-4000-8000-000000000003',
          text: invalid,
          outgoing: true,
        ),
        throwsArgumentError,
      );
    }
    expect((await store.nearbyMessages(peer)).length, 3);
  });
}
