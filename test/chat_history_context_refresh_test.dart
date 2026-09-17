import 'dart:async';
import 'dart:io';

import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_playback.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_history_context_page.dart';

class _Output implements ChatVoiceOutput {
  int stops = 0;
  final plays = <String>[];
  @override
  Stream<void> get completed => const Stream.empty();
  @override
  Future<void> play(String path) async {
    plays.add(path);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
}

class _SavedVoice extends MediaCache {
  final reads = <String>[];
  @override
  Future<File> cached({
    required String scope,
    required String contentKey,
    required MediaKind kind,
  }) async {
    expect(scope, 'member:me');
    expect(kind, MediaKind.audio);
    reads.add(contentKey);
    return File('/saved-voice.m4a');
  }
}

void main() {
  for (final group in [false, true]) {
    for (final clearAll in [false, true]) {
      testWidgets(
        'offline context voice uses saved asset group=$group clear=$clearAll',
        (tester) async {
          final media = _SavedVoice();
          final removals = StreamController<ConversationHistoryRemoval>();
          addTearDown(removals.close);
          final conversation = group ? 'group:test' : 'direct:friend';
          final output = _Output();
          final player = ChatVoicePlayback(
            output: output,
            mediaStore: media,
            events: const Stream.empty(),
          );
          var requests = 0;
          final repository = MessagingRepository(
            account: 'me',
            call: (_, _) async {
              requests++;
              throw const AuthFailure('NETWORK_ERROR', 'offline');
            },
          );
          await tester.pumpWidget(
            MaterialApp(
              home: ChatHistoryContextPage(
                account: 'me',
                localConversation: conversation,
                historyRemovals: removals.stream,
                repository: repository,
                messageId: 'voice',
                sequence: 1,
                groupId: group ? 'group' : null,
                events: const Stream.empty(),
                createVoicePlayback: () => player,
                read: ({before, after, required limit}) async =>
                    throw const AuthFailure('NETWORK_ERROR', 'offline'),
                readLocal: () async => [
                  {
                    'messageId': 'voice',
                    'sequence': 1,
                    'sender': 'friend',
                    'messageType': 'voice',
                    'text': '[语音]',
                    'voiceDurationMs': 3000,
                    'voiceAssetId': '12345678-1234-1234-1234-123456789012',
                  },
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('context-voice-voice')));
          await tester.pumpAndSettle();
          expect(requests, 0);
          expect(media.reads, [
            'chat-voice-asset:12345678-1234-1234-1234-123456789012',
          ]);
          expect(output.plays, ['/saved-voice.m4a']);
          if (clearAll) {
            removals.add(ConversationHistoryRemoval(conversation));
          } else {
            await ChatMediaDeletion('me', group, 'voice').dispatch();
          }
          await tester.pumpAndSettle();
          expect(player.activeId, isNull);
          expect(find.text('原消息不可用'), findsOneWidget);
        },
      );
    }
    testWidgets('local deletion fences context and late reads group=$group', (
      tester,
    ) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(events.close);
      Completer<void>? gate;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatHistoryContextPage(
            account: 'me',
            messageId: 'target',
            sequence: 2,
            groupId: group ? 'current' : null,
            events: events.stream,
            read: ({before, after, required limit}) async {
              await gate?.future;
              return {
                'messages': before == null
                    ? []
                    : [
                        {
                          'messageId': 'adjacent',
                          'sequence': 1,
                          'sender': 'friend',
                          'messageType': 'text',
                          'text': 'adjacent body',
                        },
                        {
                          'messageId': 'target',
                          'sequence': 2,
                          'sender': 'friend',
                          'messageType': 'text',
                          'text': 'target body',
                        },
                      ],
                'settings': {'hiddenThrough': 0},
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await ChatMediaDeletion('other', group, 'target').dispatch();
      await ChatMediaDeletion('me', !group, 'target').dispatch();
      await tester.pump();
      expect(find.text('target body'), findsOneWidget);
      gate = Completer<void>();
      events.add({'eventType': 'connection.ready', 'data': {}});
      await tester.pump();
      await ChatMediaDeletion('me', group, 'adjacent').dispatch();
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('adjacent body'), findsNothing);
      expect(find.text('target body'), findsOneWidget);
      gate = Completer<void>();
      events.add({'eventType': 'connection.ready', 'data': {}});
      await tester.pump();
      await ChatMediaDeletion('me', group, 'target').dispatch();
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('target body'), findsNothing);
      expect(find.text('原消息不可用'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await ChatMediaDeletion('me', group, 'target').dispatch();
      expect(tester.takeException(), isNull);
    });
  }
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
