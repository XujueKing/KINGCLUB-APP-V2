import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

void main() {
  sqfliteFfiInit();
  test('member history deduplicates devices and suppresses confirmed copies', () async {
    final dir = await Directory.systemTemp.createTemp('member-history-');
    final store = await ChatHistoryStore.openDatabaseWithKey(
      factory: databaseFactoryFfi,
      file: '${dir.path}/history.db',
      key: await AesGcm.with256bits().newSecretKey(),
      account: 'me',
    );
    addTearDown(() async {
      await store.close();
      await dir.delete(recursive: true);
    });
    final a = 'novovm-ed25519:${'a' * 64}';
    final b = 'novovm-ed25519:${'b' * 64}';
    const id = '00000000-0000-4000-8000-000000000001';
    Future<void> put(
      String device,
      String? member,
      bool outgoing,
      String text,
    ) => store.persistNearbyText(
      peerId: device,
      peerAccount: member,
      id: id,
      outgoing: outgoing,
      text: text,
    );
    await put(a, 'friend', true, 'hello');
    await put(b, 'friend', true, 'hello');
    await store.confirmNearbyReceipt(peerId: b, id: id);
    final rows = await store.nearbyMemberMessages('friend', limit: 1);
    expect(rows, hasLength(1));
    expect(rows.single['text'], 'hello');
    expect(rows.single['delivered'], isTrue);
    expect(rows.single.containsKey('sequence'), isFalse);
    await put(a, 'friend', false, 'reply');
    expect(await store.nearbyMemberMessages('friend'), hasLength(2));
    expect(await store.nearbyMemberMessages('other'), isEmpty);
    await put(b, null, false, 'unbound');
    expect(await store.nearbyMemberMessages('friend'), hasLength(2));
    await store.reconcileNearbyText(
      peerId: a,
      peerAccount: 'friend',
      confirmed: [
        {
          'messageId': 'server-1',
          'clientMessageId': id,
          'sequence': 1,
          'sender': 'me',
          'recipient': 'friend',
          'messageType': 'text',
          'text': 'hello',
        },
      ],
    );
    // Even an unreconciled copy on B cannot reappear alongside server history.
    expect(
      (await store.nearbyMemberMessages('friend')).single['text'],
      'reply',
    );
    await expectLater(store.nearbyMemberMessages('me'), throwsArgumentError);
    await expectLater(
      store.nearbyMemberMessages('friend', limit: 201),
      throwsArgumentError,
    );
    await put(b, 'friend', false, 'unbound');
    await expectLater(store.nearbyMemberMessages('friend'), throwsStateError);
  });
}
