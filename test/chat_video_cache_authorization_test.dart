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

class _UnsupportedPlayer extends VideoPlayerController {
  _UnsupportedPlayer() : super.file(File('synthetic.mp4'));
  @override
  Future<void> initialize() async => throw StateError('unsupported codec');
  @override
  // No platform player was created by this unsupported-codec test double.
  // ignore: must_call_super
  Future<void> dispose() async {}
}

class _PlayingPlayer extends VideoPlayerController {
  _PlayingPlayer() : super.file(File('synthetic.mp4'));
  int plays = 0, disposals = 0;
  @override
  Future<void> initialize() async {
    value = const VideoPlayerValue(
      duration: Duration(seconds: 30),
      size: Size(320, 240),
      isInitialized: true,
      position: Duration(seconds: 7),
    );
  }

  @override
  Future<void> play() async {
    plays++;
  }

  @override
  // No platform player is created by this double.
  // ignore: must_call_super
  Future<void> dispose() async {
    disposals++;
  }
}

void main() {
  const id = '12345678-1234-1234-1234-123456789012';
  for (final reason in ['denied', 'changed', 'late-denied']) {
    testWidgets('read receipt keeps player until $reason', (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(events.close);
      final player = _PlayingPlayer();
      var calls = 0, downloads = 0;
      var invalid = false;
      Completer<Map<String, dynamic>>? pending;
      Map<String, dynamic> grant() => {
        'messageId': id,
        'video': {
          'fileId': id,
          'path': '/kingclub/group-chat-video/$id/video',
          'size': invalid && reason == 'changed' ? 4 : 3,
          'sha256': '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81',
          'headers': {'authorization': 'Bearer fixture'},
        },
      };
      final repo = MessagingRepository(
        account: 'synthetic',
        call: (_, _) async {
          calls++;
          if (pending != null) return pending.future;
          if (invalid && reason != 'changed') throw StateError('hidden');
          return grant();
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatVideoView(
              repository: repo,
              messageId: id,
              group: true,
              full: true,
              events: events.stream,
              loadFile: (_) async {
                downloads++;
                return _CachedFile();
              },
              createPlayer: (_) => player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(player.plays, 1);
      expect(calls, 2);
      void read() => events.add({'eventType': 'chat.group.read'});
      read();
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(player.disposals, 0);
      expect(player.plays, 1);
      expect(downloads, 1);
      expect(player.value.position, const Duration(seconds: 7));
      if (reason == 'late-denied') {
        pending = Completer<Map<String, dynamic>>();
        read();
        await tester.pump();
        expect(calls, 4);
        read();
        await tester.pump();
        expect(calls, 4);
        final stale = pending;
        pending = null;
        invalid = true;
        stale.complete(grant());
      } else {
        invalid = true;
        read();
      }
      await tester.pumpAndSettle();
      expect(player.disposals, 1);
      expect(downloads, 1);
      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.text('视频暂不可播放，点击重试'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
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
  testWidgets('HEVC decode failure retries H264 once and does not loop', (
    tester,
  ) async {
    final preferences = <bool>[];
    var players = 0;
    final repo = MessagingRepository(
      account: 'synthetic',
      call: (_, params) async {
        final hevc = params['preferHevc'] == true;
        preferences.add(hevc);
        return {
          'messageId': id,
          'video': {
            'fileId': id,
            'codec': hevc ? 'hevc' : 'h264',
            'path': '/kingclub/chat-video/$id/${hevc ? 'hevc' : 'video'}',
            'size': 3,
            'sha256': '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81',
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
          loadFile: (_) async => _CachedFile(),
          createPlayer: (_) {
            players++;
            return _UnsupportedPlayer();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(preferences, [true, true, false, false]);
    expect(players, 2);
    expect(find.text('视频暂不可播放，点击重试'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
