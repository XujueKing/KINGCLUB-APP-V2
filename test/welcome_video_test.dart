import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:kingclub/src/features/auth/presentation/legacy_welcome_page.dart';
import 'package:kingclub/src/features/auth/presentation/welcome_video_background.dart';

class _Player extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  bool playing = false;
  bool looping = false;
  bool disposed = false;
  double volume = 0;

  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async {
    disposed = true;
    await events.close();
  }

  @override
  Future<void> play(int playerId) async => playing = true;
  @override
  Future<void> pause(int playerId) async => playing = false;
  @override
  Future<void> setLooping(int playerId, bool value) async => looping = value;
  @override
  Future<void> setVolume(int playerId, double value) async => volume = value;
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  late VideoPlayerPlatform original;
  late _Player player;
  setUp(() {
    original = VideoPlayerPlatform.instance;
    player = _Player();
    VideoPlayerPlatform.instance = player;
  });
  tearDown(() => VideoPlayerPlatform.instance = original);

  testWidgets('sound, route visibility and background lifecycle stay in sync', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [welcomeMediaRouteObserver],
        home: LegacyWelcomePage(
          onNext: () {},
          onOpenTerms: () {},
          onOpenPrivacy: () {},
        ),
      ),
    );
    // Cover the welcome page before asynchronous initialization finishes.
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('协议'))),
    );
    await tester.pumpAndSettle();
    player.events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 20),
        size: const Size(960, 2148),
      ),
    );
    await tester.pumpAndSettle();
    expect(player.playing, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(player.playing, isTrue);
    expect(player.looping, isTrue);
    expect(player.volume, 1);
    await tester.tap(find.byKey(const ValueKey('welcome-sound-toggle')));
    await tester.pump();
    expect(player.volume, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(player.playing, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(player.playing, isTrue);
    expect(player.volume, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(find.byType(WelcomeVideoBackground), findsNothing);
    expect(player.disposed, isTrue);
  });

  testWidgets('decoder failure preserves the static cover and login action', (
    tester,
  ) async {
    var next = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LegacyWelcomePage(
          onNext: () => next = true,
          onOpenTerms: () {},
          onOpenPrivacy: () {},
        ),
      ),
    );
    player.events.addError(
      PlatformException(code: 'decoder_failed', message: 'Decode failed'),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('legacy-welcome-background')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('welcome-sound-toggle')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('legacy-welcome-consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('legacy-welcome-next')));
    expect(next, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
