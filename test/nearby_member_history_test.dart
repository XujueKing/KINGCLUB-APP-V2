import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

void main() {
  sqfliteFfiInit();
  test(
    'explicit clear hides replay and new device copies across reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('member-clear-');
      final file = '${dir.path}/history.db';
      final key = await AesGcm.with256bits().newSecretKey();
      Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: file,
        key: key,
        account: 'me',
      );
      var store = await open();
      addTearDown(() async {
        await store.close();
        await dir.delete(recursive: true);
      });
      final a = 'novovm-ed25519:${'a' * 64}';
      final b = 'novovm-ed25519:${'b' * 64}';
      const id = '00000000-0000-4000-8000-000000000001';
      Future<void> put(String device, String member, String messageId) =>
          store.persistNearbyText(
            peerId: device,
            peerAccount: member,
            id: messageId,
            text: 'text',
            outgoing: false,
          );
      await put(a, 'friend', id);
      await put(b, 'other', id);
      expect(await store.nearbyUnreadCount(), 2);
      expect(await store.nearbyUnreadIds(limit: 1), [id]);
      expect(await store.nearbyUnreadCount(peerAccount: 'friend'), 1);
      expect(await store.markNearbyMemberRead('friend', [id]), 1);
      expect(await store.markNearbyMemberRead('friend', [id]), 0);
      expect(await store.nearbyUnreadCount(), 1);
      final readReplay = 'novovm-ed25519:${'d' * 64}';
      await put(readReplay, 'friend', id);
      expect(await store.nearbyUnreadCount(peerAccount: 'friend'), 0);
      expect((await store.nearbyMemberMessages('friend')).single['read'], true);
      await store.clear('direct:friend');
      expect(await store.nearbyMemberMessages('friend'), hasLength(1));
      await store.clear('direct:friend', hideNearby: true);
      await put(a, 'friend', id);
      expect(await store.nearbyMemberMessages('friend'), isEmpty);
      final c = 'novovm-ed25519:${'c' * 64}';
      await put(c, 'friend', id);
      expect(await store.nearbyMemberMessages('friend'), isEmpty);
      expect(await store.nearbyMemberMessages('other'), hasLength(1));
      const fresh = '00000000-0000-4000-8000-000000000002';
      await put(a, 'friend', fresh);
      await store.close();
      store = await open();
      expect((await store.nearbyMemberMessages('friend')).single['id'], fresh);
      expect(await store.nearbyMessages(a), hasLength(2));
      expect(await store.nearbyUnreadCount(), 2);
      expect(await store.nearbyUnreadIds(), [id, fresh]);
      await store.markNearbyMemberRead('other', [id]);
      expect(await store.nearbyUnreadIds(afterId: id), [fresh]);
      await store.markNearbyMemberRead('friend', [id]);
      expect(await store.nearbyUnreadCount(peerAccount: 'friend'), 1);
      await store.clear('direct:friend', hideNearby: true);
      expect(await store.nearbyUnreadCount(), 0);
    },
  );
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
    await expectLater(put(b, 'friend', false, 'unbound'), throwsStateError);
    expect(
      (await store.nearbyMemberMessages('friend')).single['text'],
      'reply',
    );
    expect(
      (await store.nearbyMessages(b))
          .where((row) => row['outgoing'] == false)
          .single['text'],
      'unbound',
    );
    final c = 'novovm-ed25519:${'c' * 64}';
    await expectLater(put(c, 'friend', false, 'conflicting'), throwsStateError);
    expect(await store.nearbyMessages(c), isEmpty);
    await put(c, 'friend', false, 'reply');
    expect(
      (await store.nearbyMemberMessages('friend')).single['text'],
      'reply',
    );
  });
}
