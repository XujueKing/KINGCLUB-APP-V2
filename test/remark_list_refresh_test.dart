import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/contacts_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  for (final contacts in [false, true]) {
    testWidgets(
      'saved remark refreshes ${contacts ? 'contacts' : 'conversations'} without websocket',
      (tester) async {
        tester.view.physicalSize = const Size(393, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var remark = 'Before';
        var fail = false;
        var reads = 0;
        final repo = MessagingRepository(
          account: 'me',
          call: (method, params) async {
            if (method == 'K260913000606') {
              if (fail) throw StateError('offline');
              remark = params['remark'] as String;
              return {};
            }
            if (method == 'K260913000615') return {'version': 0, 'groups': []};
            if (method == 'K260913000611') {
              return {'items': [], 'hasMore': false};
            }
            if (method == 'K260913000608' || method == 'K260913000607') {
              reads++;
              return {
                'items': [
                  {
                    'peer': 'peer',
                    'nickname': 'Nickname',
                    'remark': remark,
                    'kind': 'direct',
                    'conversationId': 'pair',
                    'preview': '',
                    'lastSequence': 0,
                    'unreadCount': 0,
                    'muted': false,
                    'pinned': false,
                  },
                ],
                'hasMore': false,
              };
            }
            return {};
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: contacts
                  ? ContactsPage(
                      active: true,
                      realData: true,
                      repository: repo,
                      onIntent: (_) {},
                    )
                  : ConversationsPage(
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
        expect(find.text('Before'), findsOneWidget);
        final before = reads;
        fail = true;
        await expectLater(
          repo.settings('peer', remark: 'Failed'),
          throwsStateError,
        );
        await tester.pumpAndSettle();
        expect(reads, before);
        expect(find.text('Before'), findsOneWidget);
        fail = false;
        await repo.settings('peer', remark: 'After');
        await tester.pumpAndSettle();
        expect(find.text('After'), findsOneWidget);
        expect(find.text('Before'), findsNothing);
        final after = reads;
        final other = MessagingRepository(
          account: 'other',
          call: (_, _) async => {},
        );
        await other.settings('peer', remark: 'Other account');
        await tester.pumpAndSettle();
        expect(reads, after);
        await repo.settings('peer', remark: '');
        await tester.pumpAndSettle();
        expect(find.text('Nickname'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
