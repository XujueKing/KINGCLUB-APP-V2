import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

void main() {
  sqfliteFfiInit();
  test(
    'read receipts persist until acknowledged and cannot cross peer scopes',
    () async {
      final dir = await Directory.systemTemp.createTemp('read-receipts-');
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
      final peer = 'novovm-ed25519:${'a' * 64}',
          other = 'novovm-ed25519:${'b' * 64}';
      const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      for (final outgoing in [true, false]) {
        await store.persistNearbyText(
          peerId: peer,
          peerAccount: 'friend',
          id: id,
          text: 'text',
          outgoing: outgoing,
        );
      }
      expect(await store.pendingNearbyReadReceipts(peer), isEmpty);
      await store.markNearbyMemberRead('friend', [id]);
      await store.persistNearbyText(
        peerId: other,
        peerAccount: 'friend',
        id: id,
        text: 'text',
        outgoing: false,
      );
      expect(await store.pendingNearbyReadReceipts(other), [id]);
      expect(await store.pendingNearbyReadReceipts(peer), [id]);
      await store.close();
      store = await open();
      expect(await store.pendingNearbyReadReceipts(peer), [id]);
      expect(
        await store.applyNearbyReadReceipt(
          peerId: other,
          peerAccount: 'friend',
          ids: [id],
          acknowledgement: false,
        ),
        isEmpty,
      );
      expect(
        await store.applyNearbyReadReceipt(
          peerId: peer,
          peerAccount: 'wrong',
          ids: [id],
          acknowledgement: false,
        ),
        isEmpty,
      );
      expect(
        (await store.nearbyMemberMessages('friend'))
            .where((r) => r['outgoing'] == true)
            .single['read'],
        false,
      );
      expect(
        await store.applyNearbyReadReceipt(
          peerId: peer,
          peerAccount: 'friend',
          ids: [id],
          acknowledgement: false,
        ),
        [id],
      );
      final sent = (await store.nearbyMemberMessages('friend'))
          .where((r) => r['outgoing'] == true)
          .single;
      expect(sent['read'], true);
      expect(await store.nearbyPeerReadIds('friend', [id]), {id});
      expect(await store.nearbyPeerReadIds('wrong', [id]), isEmpty);
      expect(sent['delivered'], true);
      expect(await store.pendingNearbyReadReceipts(peer), [id]);
      await store.applyNearbyReadReceipt(
        peerId: other,
        peerAccount: 'friend',
        ids: [id],
        acknowledgement: true,
      );
      expect(await store.pendingNearbyReadReceipts(peer), [id]);
      await store.applyNearbyReadReceipt(
        peerId: peer,
        peerAccount: 'friend',
        ids: [id],
        acknowledgement: true,
      );
      expect(await store.pendingNearbyReadReceipts(peer), isEmpty);
      await store.close();
      store = await open();
      expect(await store.pendingNearbyReadReceipts(peer), isEmpty);
      await store.persistNearbyText(
        peerId: peer,
        peerAccount: 'friend',
        id: id,
        text: 'text',
        outgoing: false,
      );
      expect(await store.pendingNearbyReadReceipts(peer), [id]);
      expect(await store.nearbyUnreadCount(peerAccount: 'friend'), 0);
      await store.applyNearbyReadReceipt(
        peerId: peer,
        peerAccount: 'friend',
        ids: [id],
        acknowledgement: true,
      );
      expect(await store.pendingNearbyReadReceipts(peer), isEmpty);
      await expectLater(
        store.applyNearbyReadReceipt(
          peerId: peer,
          peerAccount: 'friend',
          ids: List.filled(17, id),
          acknowledgement: false,
        ),
        throwsArgumentError,
      );
    },
  );
}
