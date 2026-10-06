import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kingclub/src/features/auth/presentation/mobile_login_page.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:kingclub/src/features/auth/presentation/legacy_welcome_page.dart';
import 'package:kingclub/src/features/auth/presentation/welcome_video_background.dart';

class _Player extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  final musicEvents = StreamController<VideoEvent>();
  int created = 0;
  bool musicPlaying = false;
  int musicPauses = 0;
  bool musicLooping = false;
  bool musicDisposed = false;
  double musicVolume = 0;
  bool playing = false;
  bool looping = false;
  bool disposed = false;
  double volume = 0;

  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++created;
    if (id == 2) {
      expect(options.dataSource.asset, isIn(welcomeMusicAssets));
      musicEvents.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 145),
          size: Size.zero,
        ),
      );
    }
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      playerId == 1 ? events.stream : musicEvents.stream;
  @override
  Future<void> dispose(int playerId) async {
    if (playerId == 1) {
      disposed = true;
      await events.close();
    } else {
      musicDisposed = true;
      await musicEvents.close();
    }
  }

  @override
  Future<void> play(int playerId) async =>
      playerId == 1 ? playing = true : musicPlaying = true;
  @override
  Future<void> pause(int playerId) async {
    if (playerId == 1) {
      playing = false;
    } else {
      musicPlaying = false;
      musicPauses++;
    }
  }

  @override
  Future<void> setLooping(int playerId, bool value) async =>
      playerId == 1 ? looping = value : musicLooping = value;
  @override
  Future<void> setVolume(int playerId, double value) async =>
      playerId == 1 ? volume = value : musicVolume = value;
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
    expect(player.musicPlaying, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(player.playing, isTrue);
    expect(player.looping, isTrue);
    expect(player.volume, 0);
    expect(player.musicVolume, 1);
    expect(player.musicPlaying, isTrue);
    expect(player.musicLooping, isTrue);
    await tester.tap(find.byKey(const ValueKey('welcome-sound-toggle')));
    await tester.pump();
    expect(player.musicVolume, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(player.playing, isFalse);
    expect(player.musicPlaying, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(player.playing, isTrue);
    expect(player.volume, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(find.byType(WelcomeVideoBackground), findsNothing);
    expect(player.disposed, isTrue);
    expect(player.musicDisposed, isTrue);
  });

  testWidgets('NEXT retains players and mute state behind phone glass', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [welcomeMediaRouteObserver],
          home: LegacyWelcomePage(
            onNext: () => navigator.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => MobileLoginPage(
                  onBack: () => navigator.currentState!.pop(),
                  onVerified: (_) {},
                ),
              ),
            ),
            onOpenTerms: () {},
            onOpenPrivacy: () {},
          ),
        ),
      ),
    );
    player.events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 20),
        size: const Size(960, 2148),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('legacy-welcome-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('legacy-welcome-next')));
    await tester.pumpAndSettle();
    expect(player.created, 2);
    expect(player.musicPlaying, isTrue);
    expect(
      find.byKey(const ValueKey('mobile-login-frosted-glass')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('welcome-sound-toggle')));
    await tester.pump();
    expect(player.musicVolume, 0);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(player.created, 2);
    expect(player.musicPlaying, isTrue);
    expect(player.musicVolume, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
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
