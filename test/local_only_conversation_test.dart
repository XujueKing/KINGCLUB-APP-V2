import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/conversation_relay_unread.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  sqfliteFfiInit();
  test(
    'local-only row carries real settings and never shifts server offsets',
    () async {
      final dir = await Directory.systemTemp.createTemp('local-conversation-');
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
      for (final peer in ['existing', 'local']) {
        await store.persistNearbyText(
          peerId: 'novovm-ed25519:${'a' * 64}',
          peerAccount: peer,
          id: peer == 'local'
              ? 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
              : 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          text: 'from $peer',
          outgoing: false,
        );
      }
      final lookups = <String>[];
      final repo = MessagingRepository(
        account: 'me',
        call: (method, params) async {
          if (method == 'K260913000607') {
            final first = params['offset'] == 0;
            return {
              'items': first
                  ? [
                      {
                        'kind': 'direct',
                        'peer': 'existing',
                        'unreadCount': 0,
                        if (params.containsKey('knownLocalMessageIds'))
                          'confirmedLocalMessageIds': <String>[],
                      },
                    ]
                  : [],
              'hasMore': first,
            };
          }
          expect(params['peer'], 'local');
          lookups.add(method);
          if (method == 'K260913000612') return {'nickname': '真实好友'};
          expect(method, 'K260913000604');
          return {
            'lastSequence': 0,
            'settings': {'muted': true, 'pinned': true, 'remark': '备注'},
          };
        },
      );
      final first = await conversationsWithRelayUnread(
        repository: repo,
        history: store,
        limit: 1,
      );
      expect(first['items'], hasLength(1));
      expect(first['nextServerOffset'], 1);
      expect(lookups, isEmpty);
      final last = await conversationsWithRelayUnread(
        repository: repo,
        history: store,
        offset: 1,
        limit: 1,
        loadedPeers: {'existing'},
      );
      expect(last['items'], hasLength(1));
      final row = last['items'][0];
      expect(row['peer'], 'local');
      expect(row['nickname'], '真实好友');
      expect(row['remark'], '备注');
      expect(row['muted'], true);
      expect(row['pinned'], true);
      expect(row['preview'], 'from local');
      expect(row['unreadCount'], 1);
      expect(row['lastSequence'], 0);
      expect(last['nextServerOffset'], 1);
      expect(last['hasMore'], false);
      await store.clear('direct:local', hideNearby: true);
      final hidden = await conversationsWithRelayUnread(
        repository: repo,
        history: store,
        offset: 1,
        loadedPeers: {'existing'},
      );
      expect(hidden['items'], isEmpty);
    },
  );
}
