import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

void main() {
  sqfliteFfiInit();
  testWidgets(
    'clear rejects a delayed server list before rendering or saving',
    (tester) async {
      await tester.runAsync(() async {
        FlutterSecureStorage.setMockInitialValues({});
        final dir = await Directory.systemTemp.createTemp('late-list-clear-');
        final store = await ChatHistoryStore.openDatabaseWithKey(
          factory: databaseFactoryFfi,
          file: '${dir.path}/history.db',
          key: await AesGcm.with256bits().newSecretKey(),
          account: 'me',
        );
        final replies = <Completer<Map<String, dynamic>>>[];
        final repo = MessagingRepository(
          account: 'me',
          call: (id, _) {
            expect(id, 'K260913000607');
            final reply = Completer<Map<String, dynamic>>();
            replies.add(reply);
            return reply.future;
          },
        );
        final reportedUnread = <int>[];
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ConversationsPage(
                  active: true,
                  realData: true,
                  repository: repo,
                  openRelayHistory: () async => store,
                  systemUnreadCount: 0,
                  initialFriendUnreadCount: 0,
                  onFriendUnreadChanged: reportedUnread.add,
                  onOpenContacts: () {},
                  onAddFriend: () {},
                  onOpenSystemNotifications: () {},
                  onOpenDirectChat: () {},
                ),
              ),
            ),
          );
          Future<void> waitForRequests(int count) async {
            for (var i = 0; i < 100 && replies.length < count; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
              await tester.pump();
            }
            expect(replies.length, count);
          }

          await waitForRequests(1);
          await store.clear('group:target');
          replies.first.complete({
            'items': [
              {
                'kind': 'group',
                'groupId': 'target',
                'nickname': 'Deleted group',
                'preview': 'Stale secret preview',
                'unreadCount': 9,
                'lastSequence': 1,
                'muted': false,
                'pinned': false,
              },
            ],
            'hasMore': false,
          });
          await waitForRequests(2);
          expect(find.text('Stale secret preview'), findsNothing);
          expect(reportedUnread, isNot(contains(9)));
          expect(await store.readConversationList(), isEmpty);
          replies.last.complete({'items': [], 'hasMore': false});
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(await store.readConversationList(), isEmpty);
          expect(reportedUnread.last, 0);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await store.close();
          await dir.delete(recursive: true);
        }
      });
    },
  );
  for (final group in [false, true]) {
    test(
      'clear removes only its persisted list row after reopen: group=$group',
      () async {
        final dir = await Directory.systemTemp.createTemp('clear-list-');
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
        final conversation = group ? 'group:target' : 'direct:target';
        final rows = [
          {
            'kind': group ? 'group' : 'direct',
            if (group) 'groupId': 'target' else 'peer': 'target',
            'preview': 'delete this',
            'unreadCount': 3,
          },
          {
            'kind': group ? 'direct' : 'group',
            if (group) 'peer': 'target' else 'groupId': 'target',
            'preview': 'keep this',
            'unreadCount': 7,
          },
        ];
        await store.saveConversationList(rows);
        final oldRevision = store.conversationListRevision;
        await store.clear(conversation, deleteMedia: false);
        expect(await store.readConversationList(), rows);
        await store.clear(
          conversation,
          deletedMessageIds: {'unrelated-message'},
        );
        expect(await store.readConversationList(), rows);
        // Queue a save before clearing without waiting for encryption/write.
        final saving = store.saveConversationList(rows);
        final clearing = store.clear(conversation);
        await Future.wait([saving, clearing]);
        await store.saveConversationList(rows, expectedRevision: oldRevision);
        await store.close();
        store = await open();
        expect(await store.readConversationList(), [rows.last]);
      },
    );
  }
  testWidgets(
    'offline cold entry renders cached conversation without demo data',
    (tester) async {
      await tester.runAsync(() async {
        FlutterSecureStorage.setMockInitialValues({});
        final dir = await Directory.systemTemp.createTemp('offline-list-');
        final store = await ChatHistoryStore.openDatabaseWithKey(
          factory: databaseFactoryFfi,
          file: '${dir.path}/history.db',
          key: await AesGcm.with256bits().newSecretKey(),
          account: 'me',
        );
        final events = StreamController<String>.broadcast();
        try {
          await store.saveConversationList([
            {
              'kind': 'direct',
              'peer': 'friend',
              'nickname': 'Cached friend',
              'preview': 'Cached text',
              'unreadCount': 2,
              'lastSequence': 3,
              'muted': false,
              'pinned': false,
            },
          ]);
          var unread = 0;
          final repository = MessagingRepository(
            account: 'me',
            call: (_, _) async {
              throw const AuthFailure('NETWORK_ERROR', 'offline');
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
                  relayChanges: events.stream,
                  systemUnreadCount: 0,
                  initialFriendUnreadCount: 0,
                  onFriendUnreadChanged: (value) {
                    unread = value;
                  },
                  onOpenContacts: () {},
                  onAddFriend: () {},
                  onOpenSystemNotifications: () {},
                  onOpenDirectChat: () {},
                ),
              ),
            ),
          );
          // Real SQLite completes outside the widget fake clock.
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(find.text('Cached friend'), findsOneWidget);
          expect(find.text('Cached text'), findsOneWidget);
          expect(unread, 2);
          await store.persistNearbyText(
            peerId: 'novovm-ed25519:${'a' * 64}',
            peerAccount: 'newfriend',
            id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            text: 'Arrived offline',
            outgoing: false,
          );
          events.add('newfriend');
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(find.text('Arrived offline'), findsOneWidget);
          expect(unread, 3);
          events.add('newfriend');
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(unread, 3);
          await store.clear('direct:newfriend', hideNearby: true);
          events.add('newfriend');
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(find.text('Arrived offline'), findsNothing);
          expect(unread, 2);
          expect(find.text('卡座搭子'), findsNothing);
          // No realtime/relay event and every server refresh still fails.
          // Committing clear itself must update the visible list and badge.
          await store.clear('direct:friend', hideNearby: true);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(find.text('Cached friend'), findsNothing);
          expect(find.text('Cached text'), findsNothing);
          expect(unread, 0);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await events.close();
          await store.close();
          await dir.delete(recursive: true);
        }
      });
    },
  );
  test(
    'conversation display cache is encrypted, projected and account bound',
    () async {
      final dir = await Directory.systemTemp.createTemp('conversation-cache-');
      final file = '${dir.path}/history.db';
      final key = await AesGcm.with256bits().newSecretKey();
      Future<ChatHistoryStore> open(String account) =>
          ChatHistoryStore.openDatabaseWithKey(
            factory: databaseFactoryFfi,
            file: file,
            key: key,
            account: account,
          );
      var store = await open('me');
      addTearDown(() async {
        await store.close();
        await dir.delete(recursive: true);
      });
      expect(await store.readConversationList(), isEmpty);
      await store.saveConversationList([
        {
          'kind': 'direct',
          'peer': 'friend',
          'nickname': 'Private name',
          'preview': 'Private preview',
          'unreadCount': 2,
          'lastSequence': 3,
          'muted': false,
          'avatar': {'url': 'secret-url'},
          'token': 'secret-token',
          'sendPermission': {'allowed': true},
        },
      ]);
      await store.close();
      store = await open('me');
      final rows = await store.readConversationList();
      expect(rows.single['preview'], 'Private preview');
      expect(rows.single.containsKey('avatar'), false);
      expect(rows.single.containsKey('token'), false);
      expect(rows.single.containsKey('sendPermission'), false);
      await store.close();
      final raw = await databaseFactoryFfi.openDatabase(file);
      expect(
        jsonEncode(await raw.query('conversation_list_cache')),
        isNot(contains('Private')),
      );
      await raw.close();
      store = await open('other');
      await expectLater(
        store.readConversationList(),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await store.close();
      store = await open('me');
      await store.saveConversationList([]);
      expect(await store.readConversationList(), isEmpty);
    },
  );
}
