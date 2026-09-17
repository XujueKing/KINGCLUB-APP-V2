import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_text_draft_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  ChatTextDraftStore store(String account, String target) =>
      ChatTextDraftStore(account, target, () async {});
  Widget page({bool serverRow = false, ChatOutbox? outbox}) => MaterialApp(
    home: Scaffold(
      body: ConversationsPage(
        pendingOutbox: outbox,
        active: true,
        realData: true,
        repository: MessagingRepository(
          account: 'me',
          call: (method, _) async => method == 'K260913000607'
              ? {
                  'items': [
                    if (serverRow)
                      {
                        'kind': 'direct',
                        'peer': 'peer',
                        'nickname': 'Friend',
                        'preview': 'sent',
                        'unreadCount': 0,
                      },
                  ],
                  'hasMore': false,
                }
              : {},
        ),
        openTextDraftStore: (account, target) async => store(account, target),
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
  testWidgets(
    'unsent first draft survives page recreation and can be removed',
    (tester) async {
      final own = store('me', 'peer:peer');
      await own.write(ChatTextDraft('unsent', displayName: 'Friend'));
      await store(
        'other',
        'peer:hidden',
      ).write(ChatTextDraft('private', displayName: 'Other'));
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('Friend'), findsOneWidget);
      expect(find.text('[草稿] unsent'), findsOneWidget);
      expect(find.text('Other'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('Friend'), findsOneWidget);
      await tester.longPress(find.text('Friend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除草稿'));
      await tester.pumpAndSettle();
      expect(find.text('Friend'), findsNothing);
      expect(await own.read(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'offline first pending conversation appears and follows queue changes',
    (tester) async {
      final queue = SecureChatOutbox('me');
      await queue.put({
        'clientMessageId': 'first',
        'sender': 'me',
        'recipient': 'peer',
        'text': 'pending first',
      });
      await tester.pumpWidget(page(outbox: queue));
      await tester.pumpAndSettle();
      expect(find.textContaining('pending first'), findsOneWidget);
      await queue.remove('first');
      await tester.pumpAndSettle();
      expect(find.textContaining('pending first'), findsNothing);
      await queue.put({
        'clientMessageId': 'second',
        'sender': 'me',
        'groupId': 'group',
        'text': 'pending group',
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('pending group'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('server conversation suppresses duplicate local draft row', (
    tester,
  ) async {
    await store(
      'me',
      'peer:peer',
    ).write(ChatTextDraft('unsent', displayName: 'Friend'));
    await tester.pumpWidget(page(serverRow: true));
    await tester.pumpAndSettle();
    expect(find.text('Friend'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('session change removes draft-only rows', (tester) async {
    await store(
      'me',
      'group:room',
    ).write(ChatTextDraft('notice', displayName: 'Group'));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('Group'), findsOneWidget);
    SecureSessionStore.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Group'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
