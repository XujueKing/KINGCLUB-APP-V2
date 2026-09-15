import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_call_history.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

import 'direct_chat_controller_test.dart' as fixture;

const callId = '00000000-0000-4000-8000-000000000001';
Map<String, dynamic> record(String media) => {
  'callId': callId,
  'mediaKind': media,
  'endReason': 'hangup',
  'durationMs': 15000,
};

void main() {
  test('rejects plain text and malformed call metadata', () {
    expect(ChatCallHistory.tryParse('语音通话 · 00:15'), isNull);
    for (final override in [
      {'callId': 'not-a-call'},
      {'mediaKind': 'unknown'},
      {'durationMs': -1},
      {'durationMs': 1.5},
      {'endReason': 'ringing'},
    ]) {
      expect(
        ChatCallHistory.tryParse({...record('audio'), ...override}),
        isNull,
      );
    }
    expect(
      ChatCallHistory.tryParse({...record('audio'), 'durationMs': null}),
      isNotNull,
    );
  });
  for (final media in ['audio', 'video']) {
    testWidgets('tapping $media record starts same media once', (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final requests = <Map<String, dynamic>>[];
      final queue = fixture.MemoryOutbox();
      final repo = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000604') {
            return fixture.history([
              {
                ...fixture.ack({'clientMessageId': 'msg', 'text': '通话记录'}),
                'call': record(media),
              },
            ]);
          }
          if (id == 'K260913000643') {
            requests.add(params);
            return pending.future;
          }
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(
            peerAccount: 'peer',
            repository: repo,
            chatOutbox: queue,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('chat-call-record-$callId'));
      expect(card, findsOneWidget);
      await tester.tap(card);
      await tester.pump();
      await tester.tap(card);
      await tester.pump();
      expect(requests, hasLength(1));
      expect(requests.single['peer'], 'peer');
      expect(requests.single['mediaKind'], media);
      await tester.pumpWidget(const SizedBox());
      pending.completeError(Exception('test call cancelled'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
