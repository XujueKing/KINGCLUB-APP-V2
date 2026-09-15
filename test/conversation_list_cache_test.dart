import 'dart:io';
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
                  relayChanges: const Stream<String>.empty(),
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
          expect(find.text('卡座搭子'), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
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
