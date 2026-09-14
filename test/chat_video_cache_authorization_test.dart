import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_video_view.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';

class _CachedFile implements File {
  @override
  Future<int> length() async => 3;
  @override
  Stream<List<int>> openRead([int? start, int? end]) => Stream.value([1, 2, 3]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const id = '12345678-1234-1234-1234-123456789012';
  testWidgets(
    'permission revoked during cached file read cannot start playback',
    (tester) async {
      final file = _CachedFile();
      final digest = (await Sha256().hash([1, 2, 3])).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final rechecked = Completer<void>();
      var calls = 0;
      final repo = MessagingRepository(
        account: 'synthetic',
        call: (_, _) async {
          calls++;
          if (calls == 2) {
            rechecked.complete();
            throw StateError('message recalled');
          }
          return {
            'messageId': id,
            'video': {
              'fileId': id,
              'path': '/kingclub/chat-video/$id/video',
              'size': 3,
              'sha256': digest,
              'headers': {'authorization': 'Bearer fixture'},
            },
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatVideoView(
            repository: repo,
            messageId: id,
            full: true,
            events: const Stream.empty(),
            loadFile: (_) async => file,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(rechecked.isCompleted, isTrue);
      expect(calls, 2);
      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.text('视频暂不可播放，点击重试'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'session change discards a late video grant before cache access',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      var reads = 0;
      final repo = MessagingRepository(
        account: 'synthetic',
        call: (_, _) => pending.future,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatVideoView(
            repository: repo,
            messageId: id,
            full: true,
            events: const Stream.empty(),
            loadFile: (_) async {
              reads++;
              throw StateError('must not read');
            },
          ),
        ),
      );
      SecureSessionStore.changes.add(null);
      await tester.pump();
      pending.complete({});
      await tester.pumpAndSettle();
      expect(reads, 0);
      expect(find.byType(VideoPlayer), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
