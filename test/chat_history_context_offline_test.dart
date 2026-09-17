import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_history_context_page.dart';

void main() {
  for (final group in [false, true]) {
    testWidgets(
      'clear fences pending context without per-message events $group',
      (tester) async {
        final removals = StreamController<ConversationHistoryRemoval>();
        addTearDown(removals.close);
        final pending = Completer<List<Map<String, dynamic>>>();
        final conversation = group ? 'group:test' : 'direct:friend';
        await tester.pumpWidget(
          MaterialApp(
            home: ChatHistoryContextPage(
              account: 'me',
              messageId: 'm1',
              sequence: 1,
              groupId: group ? 'test' : null,
              localConversation: conversation,
              historyRemovals: removals.stream,
              events: const Stream.empty(),
              read: ({before, after, required limit}) async =>
                  throw const AuthFailure('NETWORK_ERROR', 'offline'),
              readLocal: () => pending.future,
            ),
          ),
        );
        await tester.pump();
        removals.add(ConversationHistoryRemoval('direct:unrelated'));
        await tester.pump();
        expect(find.text('原消息不可用'), findsNothing);
        removals.add(ConversationHistoryRemoval(conversation));
        await tester.pumpAndSettle();
        expect(find.text('原消息不可用'), findsOneWidget);
        pending.complete([
          {
            'messageId': 'm1',
            'sequence': 1,
            'sender': 'me',
            'text': 'late secret',
          },
        ]);
        await tester.pumpAndSettle();
        expect(find.text('late secret'), findsNothing);
        expect(find.text('原消息不可用'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        removals.add(ConversationHistoryRemoval(conversation));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final code in ['NETWORK_ERROR', 'SESSION_CHANGED', 'FORBIDDEN']) {
    testWidgets('context local fallback only for network: $code', (
      tester,
    ) async {
      var localReads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatHistoryContextPage(
            account: 'me',
            messageId: 'm1',
            sequence: 1,
            events: const Stream.empty(),
            read: ({before, after, required limit}) async =>
                throw AuthFailure(code, 'unavailable'),
            readLocal: () async {
              localReads++;
              return [
                {
                  'messageId': 'm1',
                  'sequence': 1,
                  'sender': 'me',
                  'text': 'saved body',
                },
              ];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(localReads, code == 'NETWORK_ERROR' ? 1 : 0);
      expect(
        find.text('saved body'),
        code == 'NETWORK_ERROR' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('当前显示本机已保存的记录'),
        code == 'NETWORK_ERROR' ? findsOneWidget : findsNothing,
      );
    });
  }
  testWidgets('logout rejects late local context', (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatHistoryContextPage(
          account: 'me',
          messageId: 'm1',
          sequence: 1,
          events: const Stream.empty(),
          read: ({before, after, required limit}) async =>
              throw const AuthFailure('NETWORK_ERROR', 'offline'),
          readLocal: () => pending.future,
        ),
      ),
    );
    await tester.pump();
    SecureSessionStore.changes.add(null);
    await tester.pump();
    pending.complete([
      {
        'messageId': 'm1',
        'sequence': 1,
        'sender': 'me',
        'text': 'saved private body',
      },
    ]);
    await tester.pumpAndSettle();
    expect(find.text('saved private body'), findsNothing);
    expect(find.text('登录状态已变化'), findsOneWidget);
  });
}
