import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';
import 'package:kingclub/src/features/messaging/presentation/message_voice_transcription_page.dart';

void main() {
  for (final group in [false, true]) {
    testWidgets('only relevant transcript events recheck group=$group', (
      tester,
    ) async {
      final events = StreamController<Map<String, dynamic>>();
      var reads = 0;
      var allowed = true;
      final repository = MessagingRepository(
        account: 'synthetic',
        call: (id, _) async {
          if (id == 'K260915000675') {
            return {
              'messageId': 'message',
              'kind': group ? 'group' : 'direct',
              'status': 'recognized',
              'text': '保留识别内容',
            };
          }
          reads++;
          if (!allowed) throw StateError('denied');
          return {'messageId': 'message', 'voice': {}};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MessageVoiceTranscriptionPage(
            repository: repository,
            messageId: 'message',
            group: group,
            scopeId: 'current',
            events: events.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, 1);
      for (final type in [
        'chat.message.created',
        'chat.read',
        'chat.group.changed',
        'chat.group.read',
        'chat.settings.changed',
        'chat.relationship.changed',
      ]) {
        events.add({
          'eventType': type,
          'data': {'groupId': 'other', 'conversationId': 'other'},
        });
      }
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(find.text('保留识别内容'), findsOneWidget);
      events.add({'eventType': 'connection.ready'});
      await tester.pumpAndSettle();
      expect(reads, 2);
      allowed = false;
      events.add({
        'eventType': group ? 'chat.group.changed' : 'chat.settings.changed',
        'data': {group ? 'groupId' : 'conversationId': 'current'},
      });
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(find.text('保留识别内容'), findsNothing);
      await tester.pumpWidget(const SizedBox());
        unawaited(events.close());
    });
    for (final late in [false, true]) {
      testWidgets('local deletion clears transcript group=$group late=$late', (
        tester,
      ) async {
        final pending = Completer<Map<String, dynamic>>();
        var calls = 0;
        final result = {
          'messageId': 'message',
          'kind': group ? 'group' : 'direct',
          'status': 'recognized',
          'text': '删除测试语音',
        };
        final repository = MessagingRepository(
          account: 'synthetic',
          call: (id, _) async {
            calls++;
            if (id == 'K260915000675') return late ? pending.future : result;
            return {'messageId': 'message', 'voice': {}};
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: MessageVoiceTranscriptionPage(
              repository: repository,
              messageId: 'message',
              group: group,
              events: const Stream.empty(),
            ),
          ),
        );
        await tester.pump();
        for (final event in [
          ChatMediaDeletion('other', group, 'message'),
          ChatMediaDeletion('synthetic', !group, 'message'),
          ChatMediaDeletion('synthetic', group, 'other'),
        ]) {
          await event.dispatch();
        }
        await tester.pump();
        if (!late) expect(find.text('删除测试语音'), findsOneWidget);
        expect(find.text('内容已移除'), findsNothing);
        await ChatMediaDeletion('synthetic', group, 'message').dispatch();
        if (late) pending.complete(result);
        await tester.pumpAndSettle();
        expect(find.text('删除测试语音'), findsNothing);
        expect(find.text('内容已移除'), findsOneWidget);
        final before = calls;
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '重试'))
              .onPressed,
          isNull,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.text('内容已移除'), findsOneWidget);
        expect(calls, before);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'background ignores notifications and late recognition until retry',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(events.close);
      final pending = Completer<Map<String, dynamic>>();
      var recognitions = 0, permissions = 0;
      final result = {
        'messageId': 'message',
        'kind': 'direct',
        'status': 'recognized',
        'text': '测试内容',
      };
      final repo = MessagingRepository(
        account: 'synthetic',
        call: (id, params) async {
          if (id == 'K260915000675') {
            recognitions++;
            return recognitions == 1 ? pending.future : result;
          }
          permissions++;
          return {'messageId': 'message', 'voice': {}};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MessageVoiceTranscriptionPage(
            repository: repo,
            messageId: 'message',
            group: false,
            events: events.stream,
          ),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      events.add({'eventType': 'chat.settings.changed'});
      pending.complete(result);
      await tester.pumpAndSettle();
      expect(permissions, 0);
      expect(find.text('测试内容'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(recognitions, 1);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(recognitions, 2);
      expect(permissions, 1);
      expect(find.text('测试内容'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('permission revocation clears a displayed transcript', (
    tester,
  ) async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(events.close);
    bool allowed = true;
    int reads = 0;
    final repo = MessagingRepository(
      account: 'synthetic',
      call: (id, params) async {
        if (id == 'K260915000675') {
          return {
            'messageId': 'message',
            'kind': 'direct',
            'status': 'recognized',
            'text': '明天见',
          };
        }
        reads++;
        if (!allowed) throw StateError('denied');
        return {'messageId': 'message', 'voice': {}};
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MessageVoiceTranscriptionPage(
          repository: repo,
          messageId: 'message',
          group: false,
          events: events.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('明天见'), findsOneWidget);
    allowed = false;
    events.add({'eventType': 'chat.settings.changed'});
    await tester.pumpAndSettle();
    expect(find.text('明天见'), findsNothing);
    expect(reads, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('session change rejects late recognition', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    final repo = MessagingRepository(
      account: 'synthetic',
      call: (id, params) => pending.future,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MessageVoiceTranscriptionPage(
          repository: repo,
          messageId: 'message',
          group: true,
          events: const Stream.empty(),
        ),
      ),
    );
    SecureSessionStore.changes.add(null);
    await tester.pump();
    pending.complete({
      'messageId': 'message',
      'kind': 'group',
      'status': 'recognized',
      'text': '旧结果',
    });
    await tester.pumpAndSettle();
    expect(find.text('旧结果'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
