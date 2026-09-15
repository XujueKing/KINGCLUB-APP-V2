import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_history_search_page.dart';

Map<String, dynamic> row(int sequence, String text) => {
  'messageId': 'm$sequence',
  'sequence': sequence,
  'text': text,
  'sender': 'synthetic',
  'createdDate': DateTime(2020, 1, 2, 10).toUtc().toIso8601String(),
};
void main() {
  testWidgets(
    'server search paginates independently and privacy change clears results',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>();
      addTearDown(events.close);
      final calls = <int?>[];
      var allowed = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatHistorySearchPage(
            events: events.stream,
            search: (query, before) async {
              expect(query, 'needle');
              calls.add(before);
              if (!allowed) throw StateError('denied');
              return {
                'messages': before == null
                    ? [row(9, 'needle newer')]
                    : [row(3, 'needle older')],
                'hasMore': before == null,
              };
            },
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('chat-history-search-input')),
        'needle',
      );
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpAndSettle();
      expect(find.text('needle newer'), findsOneWidget);
      expect(find.text('synthetic · 2020年1月2日 10:00'), findsOneWidget);
      await tester.tap(find.text('加载更早结果'));
      await tester.pumpAndSettle();
      expect(calls, [null, 9]);
      expect(find.text('needle older'), findsOneWidget);
      allowed = false;
      events.add({'eventType': 'chat.settings.changed'});
      await tester.pump();
      await tester.pump();
      expect(find.text('needle newer'), findsNothing);
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpAndSettle();
      expect(find.text('搜索未完成，请重试'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('new query and logout reject late results', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatHistorySearchPage(
          events: const Stream.empty(),
          search: (query, before) async {
            if (query == 'old') return pending.future;
            return {
              'messages': [row(2, 'new result')],
              'hasMore': false,
            };
          },
        ),
      ),
    );
    final input = find.byKey(const ValueKey('chat-history-search-input'));
    await tester.enterText(input, 'old');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.enterText(input, 'new');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(find.text('new result'), findsOneWidget);
    pending.complete({
      'messages': [row(1, 'old result')],
      'hasMore': false,
    });
    await tester.pumpAndSettle();
    expect(find.text('old result'), findsNothing);
    SecureSessionStore.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('new result'), findsNothing);
    expect(find.text('登录状态已变化'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
