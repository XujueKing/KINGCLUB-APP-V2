import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  sqfliteFfiInit();
  testWidgets(
    'relay events update the real list badge and parent count; mark-read clears both',
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
        var serverUnread = 1;
        final repository = MessagingRepository(
          account: 'me',
          call: (method, params) async {
            if (method == 'K260913000605') {
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
                  'lastSequence': 1,
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
                    if (!count.isCompleted) count.complete(value);
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
          2,
        );
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);
        count = Completer<int>();
        await real(() => receive('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'));
        await real(() async {
          events.add('peer');
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();
        expect(
          await real(() => count.future.timeout(const Duration(seconds: 5))),
          3,
        );
        await tester.pumpAndSettle();
        expect(find.text('3'), findsOneWidget);
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
          0,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('conversation-unread-badge')),
          findsNothing,
        );
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
