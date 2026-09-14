import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/contacts/presentation/contacts_page.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  for (final contacts in [false, true]) {
    testWidgets(
      '${contacts ? "contacts" : "conversations"} binds after login and rebinds on session renewal',
      (tester) async {
        tester.view.physicalSize = const Size(393, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        FlutterSecureStorage.setMockInitialValues({});
        var revision = 0;
        final repository = MessagingRepository(
          account: 'me',
          call: (id, params) async {
            if (id == 'K260913000615') return {'version': 0, 'groups': []};
            if (id == 'K260913000611') return {'items': [], 'hasMore': false};
            if (id == 'K260913000612') return <String, dynamic>{};
            return {
              'items': [
                {
                  'peer': 'peer',
                  'nickname': 'Friend $revision',
                  'remark': '',
                  'gender': null,
                  'bio': '',
                  'preview': 'Preview $revision',
                  'lastSequence': 1,
                  'unreadCount': revision,
                  'muted': false,
                  'pinned': false,
                  'messageDate': '2026-09-14T01:00:00Z',
                },
              ],
              'hasMore': false,
            };
          },
        );
        Widget page(bool real) => MaterialApp(
          home: Scaffold(
            body: contacts
                ? ContactsPage(
                    key: const ValueKey('page'),
                    active: true,
                    realData: real,
                    repository: repository,
                    onIntent: (_) {},
                  )
                : ConversationsPage(
                    key: const ValueKey('page'),
                    active: true,
                    realData: real,
                    repository: repository,
                    systemUnreadCount: 0,
                    initialFriendUnreadCount: 0,
                    onFriendUnreadChanged: (_) {},
                    onOpenContacts: () {},
                    onAddFriend: () {},
                    onOpenSystemNotifications: () {},
                    onOpenDirectChat: () {},
                  ),
          ),
        );
        await tester.pumpWidget(page(false));
        await tester.pumpAndSettle();
        await tester.pumpWidget(page(true));
        await tester.pumpAndSettle();
        expect(find.text('Friend 0'), findsOneWidget);
        revision = 1;
        await SecureSessionStore().saveSession({
          'sessionId': 'renewed',
          'account': {'userAccount': 'me'},
        });
        for (
          var attempt = 0;
          attempt < 20 && find.text('Friend 1').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.text('Friend 0'), findsNothing);
        expect(await SecureSessionStore().readSession(), isNotNull);
        await tester.pumpAndSettle();
        expect(find.text('Friend 1'), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        revision = 2;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.text('Friend 2'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
