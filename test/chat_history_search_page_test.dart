import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_history_search_page.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

Map<String, dynamic> row(int sequence, String text) => {
  'messageId': 'm$sequence',
  'sequence': sequence,
  'text': text,
  'sender': 'synthetic',
  'createdDate': DateTime(2020, 1, 2, 10).toUtc().toIso8601String(),
};
void main() {
  for (final group in [false, true]) {
    testWidgets(
      'conversation clear fences unsaved search results group=$group',
      (tester) async {
        final removals = StreamController<ConversationHistoryRemoval>();
        addTearDown(removals.close);
        final late = Completer<Map<String, dynamic>>();
        final conversation = group ? 'group:test' : 'direct:friend';
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: ChatHistorySearchPage(
              account: 'me',
              groupId: group ? 'test' : null,
              localConversation: conversation,
              historyRemovals: removals.stream,
              events: const Stream.empty(),
              search: (_, _) async {
                calls++;
                if (calls == 2) return late.future;
                return {
                  'messages': [row(1, 'unsaved result')],
                  'hasMore': false,
                };
              },
            ),
          ),
        );
        final input = find.byKey(const ValueKey('chat-history-search-input'));
        await tester.enterText(input, 'first');
        await tester.pump(const Duration(milliseconds: 301));
        await tester.pumpAndSettle();
        expect(find.text('unsaved result'), findsOneWidget);
        removals.add(ConversationHistoryRemoval('direct:unrelated'));
        await tester.pump();
        expect(find.text('unsaved result'), findsOneWidget);
        await tester.enterText(input, 'second');
        await tester.pump(const Duration(milliseconds: 301));
        expect(calls, 2);
        removals.add(ConversationHistoryRemoval(conversation));
        await tester.pump();
        expect(tester.widget<TextField>(input).controller!.text, isEmpty);
        late.complete({
          'messages': [row(2, 'late private result')],
          'hasMore': false,
        });
        await tester.pumpAndSettle();
        expect(find.text('late private result'), findsNothing);
        expect(calls, 2);
        await tester.enterText(input, 'new');
        await tester.pump(const Duration(milliseconds: 301));
        await tester.pumpAndSettle();
        expect(calls, 3);
        removals.add(ConversationHistoryRemoval(conversation, sequences: {1}));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 301));
        await tester.pumpAndSettle();
        expect(find.text('unsaved result'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        removals.add(ConversationHistoryRemoval(conversation));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final group in [false, true]) {
    testWidgets(
      'local deletion invalidates search without a socket event group=$group',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: ChatHistorySearchPage(
              account: 'me',
              groupId: group ? 'group' : null,
              events: const Stream.empty(),
              search: (_, _) async {
                calls++;
                return {
                  'messages': [
                    row(1, 'deleted original'),
                    row(2, 'retained original'),
                    {
                      ...row(3, 'recalled private text'),
                      'messageType': 'recalled',
                    },
                  ],
                  'hasMore': false,
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
        expect(find.text('deleted original'), findsOneWidget);
        expect(find.text('recalled private text'), findsNothing);
        await ChatMediaDeletion('other', group, 'm1').dispatch();
        await ChatMediaDeletion('me', !group, 'm1').dispatch();
        await tester.pump(const Duration(milliseconds: 301));
        expect(calls, 1);
        await ChatMediaDeletion('me', group, 'm1').dispatch();
        await tester.pump();
        expect(find.text('deleted original'), findsNothing);
        await tester.pump(const Duration(milliseconds: 301));
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(find.text('deleted original'), findsNothing);
        expect(find.text('retained original'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await ChatMediaDeletion('me', group, 'm2').dispatch();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('media type switches reset cursor and reject previous results', (
    tester,
  ) async {
    final voice = Completer<Map<String, dynamic>>();
    final requests = <(String, int?)>[];
    Map<String, dynamic>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatHistorySearchPage(
          events: const Stream.empty(),
          onSelected: (message) => selected = message,
          search: (query, before) async => {
            'messages': [row(20, query)],
            'hasMore': false,
          },
          mediaSearch: (type, before) async {
            requests.add((type, before));
            if (type == 'voice') return voice.future;
            return {
              'messages': [
                {
                  ...row(
                    before == null ? 10 : 2,
                    before == null ? 'image-new' : 'image-old',
                  ),
                  'messageType': type,
                },
              ],
              'hasMore': before == null,
            };
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('history-type-voice')));
    await tester.pump(const Duration(milliseconds: 301));
    await tester.tap(find.byKey(const ValueKey('history-type-image')));
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(find.text('image-new'), findsOneWidget);
    voice.complete({
      'messages': [
        {...row(15, 'late-voice'), 'messageType': 'voice'},
      ],
      'hasMore': false,
    });
    await tester.pumpAndSettle();
    expect(find.text('late-voice'), findsNothing);
    await tester.tap(find.text('加载更早结果'));
    await tester.pumpAndSettle();
    expect(requests, [('voice', null), ('image', null), ('image', 10)]);
    await tester.tap(find.text('image-old'));
    expect(selected?['sequence'], 2);
    await tester.enterText(
      find.byKey(const ValueKey('chat-history-search-input')),
      'keyword',
    );
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(find.text('image-new'), findsNothing);
    expect(find.text('keyword'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });
  for (final group in [false, true]) {
    testWidgets('unrelated group events preserve search; group=$group', (
      tester,
    ) async {
      final events = StreamController<Map<String, dynamic>>();
      addTearDown(events.close);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatHistorySearchPage(
            groupId: group ? 'current' : null,
            events: events.stream,
            search: (_, _) async {
              calls++;
              return {
                'messages': [row(1, 'retained result')],
                'hasMore': false,
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
      for (final type in ['chat.group.read', 'chat.group.changed']) {
        events.add({
          'eventType': type,
          'data': {'groupId': 'other'},
        });
        await tester.pump();
        expect(find.text('retained result'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 301));
      }
      expect(calls, 1);
      events.add({
        'eventType': group ? 'chat.group.changed' : 'chat.settings.changed',
        'data': group ? {'groupId': 'current'} : {},
      });
      await tester.pump();
      await tester.pump();
      expect(find.text('retained result'), findsNothing);
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
    });
  }
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
            senderLabel: (account) => account == 'synthetic' ? '朋友备注' : '群成员',
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
      expect(find.text('朋友备注 · 2020年1月2日 10:00'), findsOneWidget);
      expect(find.textContaining('synthetic'), findsNothing);
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
