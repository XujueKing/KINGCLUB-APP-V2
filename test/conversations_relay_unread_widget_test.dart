import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_read_outbox.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  sqfliteFfiInit();
  for (final mode in ['online', 'localOnly', 'readOffline']) {
    testWidgets(
      'relay mark-read updates local badge independently of server: $mode',
      (tester) async {
        await tester.runAsync(() async {
          Future<T> real<T>(Future<T> Function() action) => action();
          FlutterSecureStorage.setMockInitialValues({});
          late Directory dir;
          late ChatHistoryStore history;
          final events = StreamController<String>.broadcast();
          final device = 'novovm-ed25519:${'a' * 64}';
          Future<void> receive(String id) => history.persistNearbyText(
            peerId: device,
            peerAccount: 'peer',
            id: id,
            text: 'relay',
            outgoing: false,
          );
          await real(() async {
            dir = await Directory.systemTemp.createTemp('relay-list-widget-');
            history = await ChatHistoryStore.openDatabaseWithKey(
              factory: databaseFactoryFfi,
              file: '${dir.path}/history.db',
              key: await AesGcm.with256bits().newSecretKey(),
              account: 'me',
            );
            await receive('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
          });
          var count = Completer<int>();
          var expectedCount = mode == 'localOnly' ? 1 : 2;
          var serverUnread = mode == 'localOnly' ? 0 : 1;
          var readCalls = 0;
          var readOffline = mode == 'readOffline';
          final repository = MessagingRepository(
            account: 'me',
            readOutbox: ChatReadOutbox('me'),
            call: (method, params) async {
              if (method == 'K260913000605') {
                readCalls++;
                if (readOffline) {
                  throw const AuthFailure('NETWORK_ERROR', 'offline');
                }
                serverUnread = 0;
                return {};
              }
              if (method != 'K260913000607') return {};
              return {
                'items': [
                  {
                    'kind': 'direct',
                    'peer': 'peer',
                    'nickname': 'Peer',
                    'preview': 'preview',
                    'lastSequence': mode == 'localOnly' ? 0 : 1,
                    'unreadCount': serverUnread,
                    'muted': false,
                    'pinned': false,
                    if (params.containsKey('knownLocalMessageIds'))
                      'confirmedLocalMessageIds': <String>[],
                  },
                ],
                'hasMore': false,
              };
            },
          );
          await real(
            () => tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: ConversationsPage(
                    active: true,
                    realData: true,
                    repository: repository,
                    openRelayHistory: () async => history,
                    relayChanges: events.stream,
                    systemUnreadCount: 0,
                    initialFriendUnreadCount: 0,
                    onFriendUnreadChanged: (value) {
                      if (!count.isCompleted && value == expectedCount) {
                        count.complete(value);
                      }
                    },
                    onOpenContacts: () {},
                    onAddFriend: () {},
                    onOpenSystemNotifications: () {},
                    onOpenDirectChat: () {},
                  ),
                ),
              ),
            ),
          );
          expect(
            await real(() => count.future.timeout(const Duration(seconds: 5))),
            expectedCount,
          );
          await tester.pumpAndSettle();
          expect(find.text('$expectedCount'), findsOneWidget);
          expectedCount++;
          count = Completer<int>();
          await real(() => receive('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'));
          await real(() async {
            events.add('peer');
            await Future<void>.delayed(Duration.zero);
          });
          await tester.pump();
          expect(
            await real(() => count.future.timeout(const Duration(seconds: 5))),
            expectedCount,
          );
          await tester.pumpAndSettle();
          expect(find.text('$expectedCount'), findsOneWidget);
          expectedCount = mode == 'readOffline' ? 1 : 0;
          count = Completer<int>();
          final press = await tester.startGesture(
            tester.getCenter(find.text('relay')),
          );
          await Future<void>.delayed(const Duration(milliseconds: 600));
          await press.up();
          await tester.pumpAndSettle();
          await real(() => tester.tap(find.text('标为已读')));
          await tester.pump();
          expect(
            await real(() => count.future.timeout(const Duration(seconds: 5))),
            expectedCount,
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('conversation-unread-badge')),
            expectedCount == 0 ? findsNothing : findsOneWidget,
          );
          expect(await history.nearbyUnreadCount(peerAccount: 'peer'), 0);
          expect(readCalls, mode == 'localOnly' ? 0 : 1);
          final receipts = await history.pendingNearbyReadReceipts(device);
          expect(receipts, hasLength(2));
          if (mode == 'readOffline') {
            expect(await repository.readOutbox!.read(), {'peer': 1});
            // No websocket or relay event: the successful retry itself must
            // refresh the list and its parent badge.
            readOffline = false;
            expectedCount = 0;
            count = Completer<int>();
            await repository.retryPendingReads(isActive: () => true);
            expect(await count.future.timeout(const Duration(seconds: 5)), 0);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('conversation-unread-badge')),
              findsNothing,
            );
            expect(await repository.readOutbox!.read(), isEmpty);
            expect(readCalls, 2);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await events.close();
          await real(() async {
            await history.close();
            await dir.delete(recursive: true);
          });
        });
      },
    );
  }
}
