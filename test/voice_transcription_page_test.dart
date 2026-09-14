import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/voice_capture.dart';
import 'package:kingclub/src/features/messaging/presentation/voice_transcription_page.dart';

void main() {
  for (final invalidate in [false, true]) {
    testWidgets(
      'recognition is editable, late session results rejected: $invalidate',
      (tester) async {
        final pending = Completer<String>();
        var calls = 0;
        final repo = MessagingRepository(
          account: 'synthetic',
          call: (_, _) async {
            calls++;
            throw StateError('Must not send');
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: VoiceTranscriptionPage(
              draft: const VoiceDraft('synthetic.m4a', Duration(seconds: 2)),
              repository: repo,
              convert: () => pending.future,
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        if (invalidate) {
          SecureSessionStore.changes.add(null);
          await tester.pump();
        }
        pending.complete('明天七点见');
        await tester.pumpAndSettle();
        final input = tester.widget<TextField>(find.byType(TextField));
        expect(input.controller!.text, invalidate ? '' : '明天七点见');
        if (!invalidate) {
          await tester.enterText(find.byType(TextField), '明天八点见');
          expect(input.controller!.text, '明天八点见');
        }
        expect(calls, 0);
        if (invalidate) {
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
        }
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('leaving before recognition completes ignores late result', (
    tester,
  ) async {
    final pending = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceTranscriptionPage(
          draft: const VoiceDraft('synthetic.m4a', Duration(seconds: 2)),
          repository: MessagingRepository(
            account: 'synthetic',
            call: (_, _) async => throw StateError('Must not send'),
          ),
          convert: () => pending.future,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    pending.complete('迟到结果');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
