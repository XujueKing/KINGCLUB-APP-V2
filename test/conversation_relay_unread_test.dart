import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/conversation_relay_unread.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  sqfliteFfiInit();
  test('server and relay unread merge once while read and history remain independent', () async {
    final dir = await Directory.systemTemp.createTemp('relay-list-');
    final key = await AesGcm.with256bits().newSecretKey();
    Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
      factory: databaseFactoryFfi,
      file: '${dir.path}/history.db',
      key: key,
      account: 'me',
    );
    var store = await open();
    addTearDown(() async {
      await store.close();
      await dir.delete(recursive: true);
    });
    const matched = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const local = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    final device = 'novovm-ed25519:${'a' * 64}';
    for (final id in [matched, local]) {
      await store.persistNearbyText(
        peerId: device,
        peerAccount: 'friend',
        id: id,
        text: id,
        outgoing: false,
      );
    }
    final requests = <List<String>>[];
    String? serverDate;
    final repository = MessagingRepository(
      account: 'me',
      call: (_, params) async {
        final ids = (params['knownLocalMessageIds'] as List?)?.cast<String>();
        if (ids != null) requests.add(ids);
        return {
          'items': [
            {
              'kind': 'direct',
              'peer': 'friend',
              'unreadCount': 1,
              'preview': 'server preview',
              'messageDate': ?serverDate,
              if (ids != null)
                'confirmedLocalMessageIds': [
                  if (ids.contains(matched)) matched,
                ],
            },
            {
              'kind': 'group',
              'groupId': 'group',
              'unreadCount': 3,
              if (ids != null) 'confirmedLocalMessageIds': <String>[],
            },
          ],
          'hasMore': false,
        };
      },
    );
    final result = await conversationsWithRelayUnread(
      repository: repository,
      history: store,
    );
    expect(result['items'][0]['unreadCount'], 2);
    expect(result['items'][1]['unreadCount'], 3);
    expect(result['items'][0]['preview'], local);
    expect(DateTime.tryParse(result['items'][0]['messageDate']), isNotNull);
    expect(result['items'][1].containsKey('preview'), isFalse);
    expect(
      (await store.nearbyMemberMessages(
        'friend',
        forPreview: true,
      )).map((message) => message['id']),
      [local],
    );
    const pending = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
    await store.persistNearbyText(
      peerId: device,
      peerAccount: 'friend',
      id: pending,
      text: 'not delivered',
      outgoing: true,
    );
    expect(
      (await store.nearbyMemberMessages(
        'friend',
        limit: 1,
        forPreview: true,
      )).single['id'],
      local,
    );
    expect(await store.nearbyUnreadIds(), [local]);
    expect(
      (await store.nearbyMemberMessages('friend'))
          .where((m) => m['read'] == true),
      isEmpty,
    );
    expect(
      (await store.nearbyMemberMessages('friend'))
          .every((m) => m['serverMessageId'] == null),
      isTrue,
    );
    await store.close();
    store = await open();
    await store.persistNearbyText(
      peerId: 'novovm-ed25519:${'b' * 64}',
      peerAccount: 'friend',
      id: matched,
      text: matched,
      outgoing: false,
    );
    await conversationsWithRelayUnread(repository: repository, history: store);
    expect(requests.last, [local]);
    expect(await store.nearbyUnreadCount(peerAccount: 'friend'), 1);
    for (var index = 0; index < 201; index++) {
      await store.persistNearbyText(
        peerId: device,
        peerAccount: 'friend',
        id: '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
        text: 'batch $index',
        outgoing: false,
      );
    }
    requests.clear();
    final many = await conversationsWithRelayUnread(
      repository: repository,
      history: store,
    );
    expect(requests.map((ids) => ids.length), [200, 2]);
    expect(many['items'][0]['unreadCount'], 203);
    serverDate = DateTime.now()
        .toUtc()
        .add(const Duration(days: 1))
        .toIso8601String();
    final newerServer = await conversationsWithRelayUnread(
      repository: repository,
      history: store,
    );
    expect(newerServer['items'][0]['preview'], 'server preview');
    expect(newerServer['items'][0]['messageDate'], serverDate);
    await store.clear('direct:friend', hideNearby: true);
    expect(
      await store.nearbyMemberMessages('friend', forPreview: true),
      isEmpty,
    );
  });
}
