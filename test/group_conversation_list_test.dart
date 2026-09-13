import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

void main() {
  testWidgets(
    'group row with no peer uses group settings and group conversation route',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      var pinned = false;
      Map<String, dynamic>? setting;
      final repo = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000607')
            return {
              'items': [
                {
                  'kind': 'group',
                  'groupId': 'actual-group',
                  'conversationId': 'actual-group',
                  'peer': null,
                  'nickname': 'Actual group',
                  'preview': 'Group preview',
                  'messageDate': '2026-09-13T01:00:00Z',
                  'lastSequence': 1,
                  'unreadCount': 2,
                  'pinned': pinned,
                  'muted': false,
                },
              ],
              'hasMore': false,
            };
          if (id == 'K260913000623') {
            setting = params;
            pinned = params['pinned'] as bool;
            return {'saved': true};
          }
          if (id == 'K260913000621')
            return {
              'messages': [],
              'hasMore': false,
              'readSequence': 0,
              'lastSequence': 0,
            };
          throw StateError('Unexpected interface $id');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationsPage(
              active: true,
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
      expect(find.text('Actual group'), findsOneWidget);
      await tester.longPress(find.text('Actual group'));
      await tester.pumpAndSettle();
      expect(find.text('拉黑'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, '置顶'));
      await tester.pumpAndSettle();
      expect(setting, {'groupId': 'actual-group', 'pinned': true});
      await tester.tap(find.text('Actual group'));
      await tester.pumpAndSettle();
      final page = tester.widget<DirectChatPage>(find.byType(DirectChatPage));
      expect(page.groupId, 'actual-group');
      expect(page.peerAccount, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
