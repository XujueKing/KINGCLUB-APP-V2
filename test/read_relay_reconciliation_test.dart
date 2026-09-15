import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/conversation_relay_unread.dart';
import 'package:kingclub/src/features/messaging/data/offline_relay_conversations.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  sqfliteFfiInit();
  test(
    'read relay text is still reconciled and cannot replace recalled preview',
    () async {
      final dir = await Directory.systemTemp.createTemp('read-relay-');
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
      const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      await store.persistNearbyText(
        peerId: 'novovm-ed25519:${'a' * 64}',
        peerAccount: 'friend',
        id: id,
        text: 'Old text',
        outgoing: false,
      );
      await store.markNearbyMemberRead('friend', [id]);
      expect(await store.nearbyUnreadIds(), isEmpty);
      expect(await store.nearbyUnconfirmedIncomingIds(), [id]);
      final repo = MessagingRepository(
        account: 'me',
        call: (_, params) async {
          expect(params['knownLocalMessageIds'], [id]);
          return {
            'items': [
              {
                'kind': 'direct',
                'peer': 'friend',
                'unreadCount': 0,
                'preview': 'Message recalled',
                'messageDate': '2000-01-01T00:00:00Z',
                'confirmedLocalMessageIds': [id],
              },
            ],
            'hasMore': false,
          };
        },
      );
      final page = await conversationsWithRelayUnread(
        repository: repo,
        history: store,
      );
      expect(page['items'][0]['preview'], 'Message recalled');
      expect(page['items'][0]['unreadCount'], 0);
      expect(await store.nearbyUnconfirmedIncomingIds(), isEmpty);
      await store.persistNearbyText(
        peerId: 'novovm-ed25519:${'b' * 64}',
        peerAccount: 'friend',
        id: id,
        text: 'Old text',
        outgoing: false,
      );
      final offline = await offlineRelayConversations(
        store,
        (page['items'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList(),
      );
      expect(offline.single['preview'], 'Message recalled');
      expect(offline.single['unreadCount'], 0);
      expect(await store.nearbyUnconfirmedIncomingIds(), isEmpty);
    },
  );
}
