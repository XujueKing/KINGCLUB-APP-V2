import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/contacts/presentation/contacts_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  for (final contacts in [false, true]) {
    for (final cached in [false, true]) {
      testWidgets('offline list contacts=$contacts cached=$cached', (
        tester,
      ) async {
        FlutterSecureStorage.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(390, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        String? failure = cached ? null : 'NETWORK_ERROR';
        var reads = 0;
        final repo = MessagingRepository(
          account: 'offline-list-test',
          call: (id, _) async {
            if (id != (contacts ? 'K260913000608' : 'K260913000607')) {
              return {'items': [], 'hasMore': false};
            }
            reads++;
            if (failure != null) throw AuthFailure(failure, 'synthetic');
            return {
              'items': [
                contacts
                    ? {'peer': 'friend', 'nickname': 'Cached friend', 'bio': ''}
                    : {
                        'kind': 'group',
                        'groupId': 'group',
                        'conversationId': 'group',
                        'nickname': 'Cached friend',
                        'preview': 'saved message',
                        'unreadCount': 0,
                        'lastSequence': 1,
                        'messageDate': '2026-09-27T01:00:00Z',
                        'pinned': false,
                        'muted': false,
                      },
              ],
              'hasMore': false,
            };
          },
        );
        Widget page(bool active) => MaterialApp(
          home: Scaffold(
            body: contacts
                ? ContactsPage(
                    active: active,
                    realData: true,
                    repository: repo,
                    onIntent: (_) {},
                  )
                : ConversationsPage(
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
        );
        await tester.pumpWidget(page(true));
        await tester.pumpAndSettle();
        if (!cached) {
          expect(find.text('网络不可用，请稍后重试'), findsOneWidget);
        } else {
          expect(find.text('Cached friend'), findsOneWidget);
          final top = tester.getTopLeft(find.text('Cached friend'));
          failure = 'NETWORK_ERROR';
          final before = reads;
          await tester.pumpWidget(page(false));
          await tester.pumpWidget(page(true));
          await tester.pumpAndSettle();
          expect(reads, greaterThan(before));
          expect(find.text('网络不可用，请稍后重试'), findsNothing);
          expect(tester.getTopLeft(find.text('Cached friend')), top);
          await tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh();
          await tester.pump();
          expect(find.text('网络不可用，请稍后重试'), findsOneWidget);
          // Let the transient manual-refresh notice expire before testing auth.
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          failure = 'SESSION_EXPIRED';
          await tester.pumpWidget(page(false));
          await tester.pumpWidget(page(true));
          await tester.pumpAndSettle();
          expect(find.text('登录已失效，请重新登录'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
