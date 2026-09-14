import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_video_view.dart';

void main() {
  testWidgets(
    'denied video does not open a player and can retry authorization',
    (tester) async {
      var calls = 0;
      final repository = MessagingRepository(
        account: 'synthetic',
        call: (id, params) async {
          expect(id, 'K260915000668');
          calls++;
          throw StateError('denied');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatVideoView(
              repository: repository,
              messageId: '12345678-1234-1234-1234-123456789012',
              group: true,
              full: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('视频暂不可播放，点击重试'), findsOneWidget);
      expect(calls, 1);
      await tester.tap(find.text('视频暂不可播放，点击重试'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
