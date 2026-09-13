import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/contacts/presentation/blacklist_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  testWidgets('failed unblock keeps the real row', (tester) async {
    final repository = MessagingRepository(
      account: 'me',
      call: (id, params) async {
        if (id == 'K260913000613') {
          return {
            'items': [
              {'peer': 'peer', 'nickname': 'Retained fixture'},
            ],
            'hasMore': false,
          };
        }
        throw StateError('Synthetic failure');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlacklistPage(
          repository: repository,
          onOpenAddFriend: () {},
          onOpenUserProfile: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('blacklist-switch-peer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('blacklist-confirm-unblock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('blacklist-peer')), findsOneWidget);
    expect(find.text('已解除黑名单'), findsNothing);
  });

  testWidgets(
    'unblock waits for acknowledgement and never restores following',
    (tester) async {
      final ack = Completer<Map<String, dynamic>>();
      final actions = <String>[];
      var unblocked = false;
      final repository = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000613') {
            return {
              'items': unblocked
                  ? []
                  : [
                      {
                        'peer': 'peer',
                        'nickname': 'Real fixture',
                        'remark': '备注',
                      },
                    ],
              'hasMore': false,
            };
          }
          expect(id, 'K260913000602');
          expect(params['peer'], 'peer');
          actions.add(params['action'] as String);
          await ack.future;
          unblocked = true;
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BlacklistPage(
            repository: repository,
            onOpenAddFriend: () {},
            onOpenUserProfile: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('备注'), findsOneWidget);
      expect(find.text('艾琳'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('blacklist-switch-peer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('blacklist-confirm-unblock')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('blacklist-peer')), findsOneWidget);
      ack.complete({});
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('blacklist-peer')), findsNothing);
      expect(actions, ['unblock']);
    },
  );
  testWidgets('logout rejects late list results', (tester) async {
    final response = Completer<Map<String, dynamic>>();
    final repository = MessagingRepository(
      account: 'me',
      call: (_, _) => response.future,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlacklistPage(
          repository: repository,
          onOpenAddFriend: () {},
          onOpenUserProfile: (_) {},
        ),
      ),
    );
    SecureSessionStore.changes.add(null);
    await tester.pump();
    response.complete({
      'items': [
        {'peer': 'peer', 'nickname': 'Late fixture'},
      ],
      'hasMore': false,
    });
    await tester.pumpAndSettle();
    expect(find.text('Late fixture'), findsNothing);
    expect(find.text('登录状态已变化，请重新打开'), findsOneWidget);
  });
}
