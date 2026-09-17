import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  Widget page(MessagingRepository repo) => MaterialApp(
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
  );
  Map<String, dynamic> list(bool group, bool pinned) => {
    'items': [
      {
        'kind': group ? 'group' : 'direct',
        group ? 'groupId' : 'peer': 'target',
        'nickname': 'Friend',
        'preview': 'hello',
        'unreadCount': 1,
        'lastSequence': 1,
        'muted': false,
        'pinned': pinned,
      },
    ],
    'hasMore': false,
  };
  VoidCallback pin(WidgetTester tester) => tester
      .widget<InkWell>(
        find.descendant(
          of: find.byKey(const ValueKey('conversation-swipe-pin')),
          matching: find.byType(InkWell),
        ),
      )
      .onTap!;

  for (final group in [false, true]) {
    testWidgets(
      'repeated pin is serialized and uses current row (group=$group)',
      (tester) async {
        final reply = Completer<Map<String, dynamic>>();
        var pinned = false;
        final mutations = <bool>[];
        final repo = MessagingRepository(
          account: 'me',
          call: (method, params) async {
            if (method == 'K260913000607') return list(group, pinned);
            if (params.containsKey('pinned')) {
              mutations.add(params['pinned'] as bool);
              if (mutations.length == 1) await reply.future;
              pinned = params['pinned'] as bool;
            }
            return {};
          },
        );
        await tester.pumpWidget(page(repo));
        await tester.pumpAndSettle();
        final oldPin = pin(tester);
        oldPin();
        oldPin();
        await tester.pump();
        expect(mutations, [true]);
        reply.complete({});
        await tester.pumpAndSettle();
        oldPin();
        await tester.pumpAndSettle();
        expect(mutations, [true, false]);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('menu opened before session invalidation cannot mutate', (
    tester,
  ) async {
    var mutations = 0;
    final repo = MessagingRepository(
      account: 'me',
      call: (method, params) async {
        if (method == 'K260913000607') return list(true, false);
        mutations++;
        return {};
      },
    );
    await tester.pumpWidget(page(repo));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Friend'));
    await tester.pumpAndSettle();
    SecureSessionStore.changes.add(null);
    await tester.pumpAndSettle();
    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(3));
    await tester.tap(tiles.at(1));
    await tester.pumpAndSettle();
    expect(mutations, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
