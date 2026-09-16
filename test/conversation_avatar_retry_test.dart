import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  testWidgets(
    'failed avatars retry but successful avatars survive tab switches and resume',
    (tester) async {
      var profiles = 0;
      final repo = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000612') {
            profiles++;
            if (profiles == 1) throw StateError('temporary network failure');
            return {'avatar': null};
          }
          if (id == 'K260913000607') {
            return {
              'items': [
                {
                  'kind': 'direct',
                  'peer': 'friend',
                  'conversationId': 'pair',
                  'nickname': 'Friend',
                  'preview': 'hello',
                  'messageDate': '2026-09-15T00:00:00Z',
                  'lastSequence': 1,
                  'unreadCount': 0,
                  'pinned': false,
                  'muted': false,
                },
              ],
              'hasMore': false,
            };
          }
          return {};
        },
      );
      Future<void> show(bool active) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationsPage(
                active: active,
                realData: true,
                repository: repo,
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
        await tester.pumpAndSettle();
      }

      await show(true);
      expect(profiles, 1);
      await show(false);
      expect(profiles, 2); // The failed grant retries during this rebuild.
      await show(true);
      expect(profiles, 2);
      await show(false);
      await show(true);
      expect(profiles, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(profiles, 2);
      // An ordinary parent rebuild still shares the current grant.
      await show(true);
      expect(profiles, 2);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
