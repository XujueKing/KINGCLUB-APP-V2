import 'dart:async';

import 'package:kingclub/src/core/session/secure_session_store.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_history_search_page.dart';

import 'chat_history_search_page_test.dart' show row;

void main() {
  testWidgets('logout fences both local preview and remote completion', (
    tester,
  ) async {
    final cached = Completer<Map<String, dynamic>>();
    final remote = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatHistorySearchPage(
          account: 'me',
          localConversation: 'direct:peer',
          events: const Stream.empty(),
          historyRemovals: const Stream<ConversationHistoryRemoval>.empty(),
          localSearch: (_, _, _) => cached.future,
          search: (_, _) => remote.future,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'match');
    await tester.pump(const Duration(milliseconds: 301));
    SecureSessionStore.changes.add(null);
    await tester.pump();
    cached.complete({
      'messages': [row(20, 'private cached')],
      'hasMore': false,
    });
    remote.complete({
      'messages': [row(21, 'private remote')],
      'hasMore': false,
    });
    await tester.pumpAndSettle();
    expect(find.text('private cached'), findsNothing);
    expect(find.text('private remote'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    await tester.pumpWidget(const SizedBox());
  });
  for (final outcome in ['success', 'offline', 'denied']) {
    testWidgets('local search appears before slow network: $outcome', (
      tester,
    ) async {
      final remote = Completer<Map<String, dynamic>>();
      var calls = 0;
      final localCursors = <int?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ChatHistorySearchPage(
            account: 'me',
            localConversation: 'direct:peer',
            events: const Stream.empty(),
            historyRemovals: const Stream<ConversationHistoryRemoval>.empty(),
            search: (_, _) {
              calls++;
              return remote.future;
            },
            localSearch: (_, before, type) async {
              localCursors.add(before);
              expect(type, isNull);
              return {
                'messages': [
                  row(
                    before == null ? 20 : 10,
                    before == null ? 'cached match' : 'older cached match',
                  ),
                ],
                'hasMore': before == null,
                'localOnly': true,
              };
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'match');
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pump();
      expect(find.text('cached match'), findsOneWidget);
      expect(calls, 1);
      if (outcome == 'success') {
        remote.complete({
          'messages': [row(21, 'server match')],
          'hasMore': false,
        });
      } else {
        remote.completeError(
          AuthFailure(
            outcome == 'offline' ? 'NETWORK_ERROR' : 'CHAT_FORBIDDEN',
            'unavailable',
          ),
        );
      }
      await tester.pumpAndSettle();
      if (outcome == 'success') {
        expect(find.text('server match'), findsOneWidget);
        expect(find.text('cached match'), findsNothing);
      } else if (outcome == 'denied') {
        expect(find.text('cached match'), findsNothing);
        expect(find.text('server match'), findsNothing);
      } else {
        expect(find.text('cached match'), findsOneWidget);
        expect(localCursors, [null]);
        await tester.tap(find.byType(TextButton).last);
        await tester.pumpAndSettle();
        expect(localCursors, [null, 20]);
        expect(find.text('older cached match'), findsOneWidget);
        expect(calls, 1);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final denied in [false, true]) {
    testWidgets(
      'late cached results cannot replace settled remote denied=$denied',
      (tester) async {
        final cached = Completer<Map<String, dynamic>>();
        await tester.pumpWidget(
          MaterialApp(
            home: ChatHistorySearchPage(
              account: 'me',
              localConversation: 'direct:peer',
              events: const Stream.empty(),
              historyRemovals: const Stream<ConversationHistoryRemoval>.empty(),
              localSearch: (_, _, _) => cached.future,
              search: (_, _) async {
                if (denied) throw const AuthFailure('CHAT_FORBIDDEN', 'denied');
                return {
                  'messages': [row(21, 'server match')],
                  'hasMore': false,
                };
              },
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'match');
        await tester.pump(const Duration(milliseconds: 301));
        await tester.pump();
        cached.complete({
          'messages': [row(20, 'late cached match')],
          'hasMore': false,
        });
        await tester.pumpAndSettle();
        expect(find.text('late cached match'), findsNothing);
        expect(
          find.text('server match'),
          denied ? findsNothing : findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
