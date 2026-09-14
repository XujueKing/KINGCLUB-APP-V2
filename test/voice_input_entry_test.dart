import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/voice_capture.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';
import 'package:kingclub/src/features/messaging/presentation/voice_transcription_page.dart';

class Capture extends Fake implements VoiceCapture {
  @override
  bool begin({
    required void Function() onLimit,
    void Function()? onInterrupted,
  }) => true;
  @override
  Future<VoiceDraft?> finish({required bool cancel}) async =>
      cancel ? null : const VoiceDraft('synthetic.m4a', Duration(seconds: 2));
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'voice input opens transcription without sending a voice message',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final calls = <String>[];
      final repo = MessagingRepository(
        account: 'synthetic',
        call: (id, params) async {
          calls.add(id);
          if (id == 'K260913000604') {
            return {
              'conversationId': 'pair',
              'messages': [],
              'hasMore': false,
              'settings': {},
              'sendPermission': {'allowed': true},
              'peerReadSequence': 0,
            };
          }
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(
            peerAccount: 'friend',
            repository: repo,
            voiceCapture: Capture(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('direct-chat-attachments')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('语音输入'));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('按住 说话')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('松开转文字'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(VoiceTranscriptionPage), findsOneWidget);
      expect(calls.where((id) => id == 'K260913000637'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
