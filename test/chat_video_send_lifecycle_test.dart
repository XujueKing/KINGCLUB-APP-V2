import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_uploader.dart';
import 'package:kingclub/src/features/messaging/data/chat_session_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_video_send_page.dart';

class _File implements File {
  @override
  Future<int> length() async => 3;
  @override
  String get path => 'synthetic.mp4';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Chat extends ChangeNotifier implements ChatSessionController {
  _Chat(this.messaging);
  @override
  final MessagingRepository messaging;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected chat operation');
}

class _Preview extends VideoPlayerController {
  _Preview({this.paused, this.playing, this.ready = false})
    : super.file(File('synthetic.mp4'));
  final Completer<void>? paused;
  final Completer<void>? playing;
  final bool ready;
  int plays = 0, pauses = 0;
  @override
  Future<void> initialize() async {
    if (ready) {
      value = const VideoPlayerValue(
        duration: Duration(seconds: 8),
        size: Size(1280, 720),
        isInitialized: true,
      );
    }
  }

  @override
  Future<void> pause() async {
    pauses++;
    await paused?.future;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> play() async {
    plays++;
    await playing?.future;
    value = value.copyWith(isPlaying: true);
  }

  // This double never creates a platform player.
  @override
  // ignore: must_call_super
  Future<void> dispose() async {}
}

class _Uploader extends ChatFileUploader {
  _Uploader(MessagingRepository repo)
    : super(repository: repo, checkSession: () async {});
  final result = Completer<UploadedChatFile>();
  bool started = false;
  @override
  Future<UploadedChatFile> upload(
    File input, {
    required String fileName,
    void Function(int, int)? onProgress,
  }) {
    started = true;
    return result.future;
  }
}

void main() {
  testWidgets(
    'late preview play is paused in background and resume does not autoplay',
    (tester) async {
      final playing = Completer<void>();
      final preview = _Preview(ready: true, playing: playing);
      final repo = MessagingRepository(
        account: 'synthetic',
        call: (_, _) async => {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatVideoSendPage(
            file: _File(),
            fileName: 'synthetic.mp4',
            chat: _Chat(repo),
            createPreview: (_) => preview,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await tester.pump();
      expect(preview.plays, 1);
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await tester.pump();
      playing.complete();
      await tester.pump();
      expect(preview.value.isPlaying, isFalse);
      expect(preview.pauses, greaterThanOrEqualTo(2));
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pump();
      expect(preview.plays, 1);
      expect(preview.value.isPlaying, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('uploading prevents preview playback from restarting', (
    tester,
  ) async {
    final preview = _Preview(ready: true);
    final repo = MessagingRepository(
      account: 'synthetic',
      call: (_, _) async => {},
    );
    final uploader = _Uploader(repo);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatVideoSendPage(
          file: _File(),
          fileName: 'synthetic.mp4',
          chat: _Chat(repo),
          createPreview: (_) => preview,
          createUploader: () async => uploader,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pump();
    expect(uploader.started, isTrue);
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pump();
    expect(preview.plays, 0);
    await tester.pumpWidget(const SizedBox());
    uploader.result.completeError(StateError('cancelled after leaving'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'session change blocks late upload from processing or sending video',
    (tester) async {
      var requests = 0;
      final repo = MessagingRepository(
        account: 'synthetic',
        call: (_, _) async {
          requests++;
          throw StateError('must not call');
        },
      );
      final uploader = _Uploader(repo);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatVideoSendPage(
            file: _File(),
            fileName: 'synthetic.mp4',
            chat: _Chat(repo),
            createUploader: () async => uploader,
            createPreview: (_) => _Preview(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('发送'));
      await tester.pump();
      expect(uploader.started, isTrue);
      SecureSessionStore.changes.add(null);
      await tester.pump();
      uploader.result.complete(
        const UploadedChatFile(
          'asset',
          'synthetic.mp4',
          3,
          'hash',
          'fingerprint',
          'request',
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(find.text('登录状态已变化，请重新进入会话'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'leaving while preview pauses never starts upload or updates disposed page',
    (tester) async {
      final repo = MessagingRepository(
        account: 'synthetic',
        call: (_, _) async => {},
      );
      final uploader = _Uploader(repo), paused = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatVideoSendPage(
            file: _File(),
            fileName: 'synthetic.mp4',
            chat: _Chat(repo),
            createUploader: () async => uploader,
            createPreview: (_) => _Preview(paused: paused),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('发送'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      paused.complete();
      await tester.pumpAndSettle();
      expect(uploader.started, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
