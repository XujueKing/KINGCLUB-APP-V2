import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_playback.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_history_context_page.dart';

class _Output implements ChatVoiceOutput {
  int stops = 0;
  @override
  Stream<void> get completed => const Stream.empty();
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  for (final invalidateSession in [false, true]) {
    testWidgets(
      'history receipt preserves voice until ${invalidateSession ? "logout" : "hidden"}',
      (tester) async {
        final events = StreamController<Map<String, dynamic>>.broadcast();
        addTearDown(events.close);
        final output = _Output();
        final player = ChatVoicePlayback(
          output: output,
          events: events.stream,
          loadFile: (_, _, _, _) async => File('/voice.m4a'),
        );
        var hidden = false, reads = 0;
        Completer<void>? gate;
        final repository = MessagingRepository(
          account: 'me',
          call: (_, p) async => {
            'messageId': p['messageId'],
            'voice': {
              'fileId': '12345678-1234-1234-1234-123456789012',
              'durationMs': 3000,
              'contentType': 'audio/mp4',
              'path': '/kingclub/group-chat-voice/voice',
              'headers': {'authorization': 'Bearer private'},
            },
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ChatHistoryContextPage(
              account: 'me',
              messageId: 'voice',
              sequence: 1,
              groupId: 'current',
              repository: repository,
              events: events.stream,
              createVoicePlayback: () => player,
              read: ({before, after, required limit}) async {
                reads++;
                await gate?.future;
                return {
                  'messages': before == null
                      ? []
                      : [
                          {
                            'messageId': 'voice',
                            'sequence': 1,
                            'sender': 'friend',
                            'messageType': hidden ? 'hidden' : 'voice',
                            'text': '[语音]',
                            'voiceDurationMs': 3000,
                          },
                        ],
                  'settings': {'hiddenThrough': 0},
                  'membershipVersion': 1,
                  'joinedSequence': 0,
                };
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('播放语音 3秒'));
        await tester.pumpAndSettle();
        expect(player.activeId, 'voice');
        final stops = output.stops;
        void receipt(String group) => events.add({
          'eventType': 'chat.group.read',
          'data': {'groupId': group},
        });
        receipt('other');
        for (final type in [
          'chat.settings.changed',
          'chat.relationship.changed',
        ]) {
          events.add({
            'eventType': type,
            'data': {'conversationId': 'unrelated-direct'},
          });
        }
        await tester.pumpAndSettle();
        expect(reads, 2);
        expect(player.activeId, 'voice');
        expect(output.stops, stops);
        receipt('current');
        await tester.pumpAndSettle();
        expect(reads, 4);
        expect(player.activeId, 'voice');
        expect(output.stops, stops);
        if (invalidateSession) {
          gate = Completer<void>();
          receipt('current');
          await tester.pump();
          SecureSessionStore.changes.add(null);
          await tester.pump();
          gate.complete();
          await tester.pumpAndSettle();
          receipt('current');
          await tester.pumpAndSettle();
          expect(find.text('登录状态已变化'), findsOneWidget);
        } else {
          hidden = true;
          receipt('current');
          await tester.pumpAndSettle();
          expect(find.textContaining('暂时无法查看'), findsOneWidget);
        }
        expect(player.activeId, isNull);
        expect(output.stops, greaterThan(stops));
        expect(find.text('点击停止'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
