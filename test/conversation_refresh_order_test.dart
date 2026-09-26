import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  for (final lifecycle in [false, true]) {
    testWidgets(
      'pagination is deduplicated and incoming refresh runs afterward lifecycle=$lifecycle',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        final unread = <int>[];
        final offsets = <int>[];
        final replies = <Completer<Map<String, dynamic>>>[];
        final repo = MessagingRepository(
          account: 'test',
          call: (id, params) {
            expect(id, 'K260913000607');
            offsets.add(params['offset'] as int);
            final reply = Completer<Map<String, dynamic>>();
            replies.add(reply);
            return reply.future;
          },
        );
        Map<String, dynamic> result(String name, bool more) => {
          'items': [
            {
              'kind': 'group',
              'groupId': name,
              'conversationId': name,
              'nickname': name,
              'preview': 'preview',
              'unreadCount': name == 'Fresh group' ? 4 : 1,
              'messageDate': '2026-09-15T01:00:00Z',
              'lastSequence': 1,
              'pinned': false,
              'muted': false,
            },
          ],
          'hasMore': more,
        };
        Widget page(bool active) => MaterialApp(
          home: Scaffold(
            body: ConversationsPage(
              active: active,
              realData: true,
              repository: repo,
              systemUnreadCount: 0,
              initialFriendUnreadCount: 0,
              onFriendUnreadChanged: unread.add,
              onOpenContacts: () {},
              onAddFriend: () {},
              onOpenSystemNotifications: () {},
              onOpenDirectChat: () {},
            ),
          ),
        );
        await tester.pumpWidget(page(true));
        await tester.pump();
        expect(offsets, [0]);
        replies[0].complete(result('First group', true));
        await tester.pumpAndSettle();
        await tester.tap(find.text('加载更多'));
        await tester.pump();
        await tester.tap(find.text('加载更多'));
        await tester.pump();
        expect(offsets, [0, 1]);
        // Returning to the tab requests a fresh snapshot while pagination is pending.
        if (lifecycle) {
          // The messages tab stays mounted while another tab is visible.
          await tester.pumpWidget(page(false));
          for (var i = 0; i < 2; i++) {
            for (final state in [
              AppLifecycleState.inactive,
              AppLifecycleState.hidden,
              AppLifecycleState.paused,
              AppLifecycleState.hidden,
              AppLifecycleState.inactive,
              AppLifecycleState.resumed,
            ]) {
              tester.binding.handleAppLifecycleStateChanged(state);
              await tester.pump();
            }
          }
        } else {
          await tester.pumpWidget(page(false));
          await tester.pumpWidget(page(true));
          await tester.pumpWidget(page(false));
          await tester.pumpWidget(page(true));
        }
        expect(offsets, [0, 1]);
        replies[1].complete(result('Second group', false));
        await tester.pumpAndSettle();
        expect(offsets, [0, 1, 0]);
        replies[2].complete(result('Fresh group', false));
        await tester.pumpAndSettle();
        expect(find.text('Fresh group'), findsOneWidget);
        expect(unread.last, 4);
        expect(find.text('First group'), findsNothing);
        expect(find.text('Second group'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
