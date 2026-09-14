import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/message_voice_transcription_page.dart';

void main() {
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
