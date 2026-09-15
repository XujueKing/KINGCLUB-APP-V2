import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_history_context_page.dart';

void main() {
  const id = '00000000-0000-4000-8000-000000000001';
  for (final media in CallMedia.values) {
    for (final group in [false, true]) {
      testWidgets('${media.name} history callback group=$group', (
        tester,
      ) async {
        final pending = Completer<void>();
        final calls = <CallMedia>[];
        await tester.pumpWidget(
          MaterialApp(
            home: ChatHistoryContextPage(
              messageId: 'message',
              sequence: 1,
              account: 'me',
              groupId: group ? 'group' : null,
              onCall: (value) {
                calls.add(value);
                return pending.future;
              },
              read: ({before, after, required limit}) async => {
                'messages': before == null
                    ? []
                    : [
                        {
                          'messageId': 'message',
                          'sequence': 1,
                          'sender': 'me',
                          'messageType': 'text',
                          'text': '通话原文',
                          'call': {
                            'callId': id,
                            'mediaKind': media.name,
                            'endReason': 'hangup',
                            'durationMs': 15000,
                          },
                        },
                        {
                          'messageId': 'plain',
                          'sequence': 2,
                          'sender': 'me',
                          'messageType': 'text',
                          'text': '语音通话 · 00:15',
                        },
                      ],
                'settings': {'hiddenThrough': 0},
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('context-call-$id'));
        if (group) {
          expect(card, findsNothing);
          expect(calls, isEmpty);
        } else {
          expect(card, findsOneWidget);
          await tester.tap(card);
          await tester.pump();
          await tester.tap(card);
          await tester.pump();
          expect(calls, [media]);
          pending.complete();
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
