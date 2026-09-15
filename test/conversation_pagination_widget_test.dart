import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/offline_relay_conversations.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  sqfliteFfiInit();
  test(
    'merged rows preserve pins, tie order and distinct group identities',
    () {
      final existing = <Map<String, dynamic>>[
        {
          'kind': 'direct',
          'peer': 'same',
          'preview': 'old',
          'messageDate': '2020-01-01',
        },
        {'kind': 'group', 'groupId': 'same', 'messageDate': '2020-01-02'},
        {'kind': 'direct', 'peer': 'tie', 'messageDate': '2020-01-02'},
        {
          'kind': 'direct',
          'peer': 'pinned',
          'pinned': true,
          'messageDate': '2010-01-01',
        },
      ];
      final merged = mergeConversationRows(existing, [
        {
          'kind': 'direct',
          'peer': 'same',
          'preview': 'new',
          'messageDate': '2025-01-01',
        },
      ]);
      expect(merged.map((r) => r['peer'] ?? 'group'), [
        'pinned',
        'same',
        'group',
        'tie',
      ]);
      expect(merged[1]['preview'], 'new');
      expect(existing.first['preview'], 'old');
    },
  );
  testWidgets(
    'relay row remains on first page and server pagination replaces it once',
    (tester) async {
      await tester.runAsync(() async {
        FlutterSecureStorage.setMockInitialValues({});
        final dir = await Directory.systemTemp.createTemp('relay-page-');
        final store = await ChatHistoryStore.openDatabaseWithKey(
          factory: databaseFactoryFfi,
          file: '${dir.path}/history.db',
          key: await AesGcm.with256bits().newSecretKey(),
          account: 'me',
        );
        try {
          await store.persistNearbyText(
            peerId: 'novovm-ed25519:${'a' * 64}',
            peerAccount: 'relayfriend',
            id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            text: 'Latest relay text',
            outgoing: false,
          );
          final offsets = <int>[];
          final repository = MessagingRepository(
            account: 'me',
            call: (method, params) async {
              if (method != 'K260913000607') return {};
              final offset = params['offset'] as int;
              offsets.add(offset);
              return {
                'items': [
                  {
                    'kind': 'direct',
                    'peer': offset == 0 ? 'oldfriend' : 'relayfriend',
                    'nickname': offset == 0 ? 'Old friend' : 'Resolved name',
                    'preview': 'Server preview',
                    'messageDate': '2020-01-01T00:00:00Z',
                    'unreadCount': 0,
                    'lastSequence': 1,
                    'muted': false,
                    'pinned': false,
                    if (params.containsKey('knownLocalMessageIds'))
                      'confirmedLocalMessageIds': <String>[],
                  },
                ],
                'hasMore': offset == 0,
              };
            },
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ConversationsPage(
                  active: true,
                  realData: true,
                  repository: repository,
                  openRelayHistory: () async => store,
                  relayChanges: const Stream<String>.empty(),
                  systemUnreadCount: 0,
                  initialFriendUnreadCount: 0,
                  onFriendUnreadChanged: (_) {},
                  onOpenContacts: () {},
                  onAddFriend: () {},
                  onOpenSystemNotifications: () {},
                  onOpenDirectChat: () {},
                ),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(find.text('Latest relay text'), findsOneWidget);
          expect(find.text('Old friend'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('Latest relay text')).dy,
            lessThan(tester.getTopLeft(find.text('Old friend')).dy),
          );
          await tester.tap(find.text('加载更多'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(offsets, [0, 1]);
          expect(find.text('Latest relay text'), findsOneWidget);
          expect(find.text('Resolved name'), findsOneWidget);
          expect(find.text('relayfriend'), findsNothing);
          expect(find.text('加载更多'), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await store.close();
          await dir.delete(recursive: true);
        }
      });
    },
  );
}
