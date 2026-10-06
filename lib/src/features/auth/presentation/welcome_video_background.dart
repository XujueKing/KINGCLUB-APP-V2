import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const welcomeMusicAssets = [
  'assets/legacy/home/welcome_music_20261006.m4a',
  'assets/legacy/home/welcome_music_say_it_back.m4a',
];

final welcomeMediaRouteObserver = RouteObserver<ModalRoute<dynamic>>();

/// The cover and phone page share one playback position and mute setting.
class _WelcomeMedia extends ChangeNotifier with WidgetsBindingObserver {
  static _WelcomeMedia? current;
  final video = VideoPlayerController.asset(
    'assets/legacy/home/welcome_cover.mp4',
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  final music = VideoPlayerController.asset(
    welcomeMusicAssets[Random().nextInt(welcomeMusicAssets.length)],
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  final Set<Object> visiblePages = {};
  int users = 0;
  bool ready = false, failed = false, muted = false, closed = false;
  bool foreground = true;

  _WelcomeMedia() {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    foreground = state == null || state == AppLifecycleState.resumed;
    video.addListener(_checkError);
    music.addListener(_checkError);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await video.initialize();
      if (closed) return;
      await video.setVolume(0);
      await video.setLooping(true);
      await music.initialize();
      if (closed) return;
      await music.setLooping(true);
      await music.setVolume(muted ? 0 : 1);
      if (closed) return;
      ready = true;
      notifyListeners();
      await sync();
    } catch (_) {
      _fail();
    }
  }

  void _checkError() {
    if (video.value.hasError || music.value.hasError) _fail();
  }

  void _fail() {
    if (closed || failed) return;
    failed = true;
    notifyListeners();
    unawaited(sync());
  }

  void visibility(Object page, bool visible) {
    if (visible) {
      visiblePages.add(page);
    } else {
      visiblePages.remove(page);
    }
    // Let the destination register in the same frame before pausing the source.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(sync());
    });
  }

  bool get shouldPlay =>
      !closed && ready && !failed && foreground && visiblePages.isNotEmpty;
  Future<void> sync() async {
    if (closed || !ready) return;
    try {
      if (shouldPlay) {
        await video.play();
        if (shouldPlay) await music.play();
      } else {
        await video.pause();
        if (!closed && !shouldPlay) await music.pause();
      }
    } catch (_) {
      _fail();
    }
  }

  Future<void> toggleSound() async {
    muted = !muted;
    notifyListeners();
    try {
      await music.setVolume(muted ? 0 : 1);
    } catch (_) {
      _fail();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    unawaited(sync());
  }

  void release(Object page) {
    visiblePages.remove(page);
    if (--users > 0) {
      unawaited(sync());
      return;
    }
    closed = true;
    if (identical(current, this)) current = null;
    WidgetsBinding.instance.removeObserver(this);
    video.removeListener(_checkError);
    music.removeListener(_checkError);
    unawaited(video.dispose());
    unawaited(music.dispose());
    dispose();
  }
}

class WelcomeVideoBackground extends StatefulWidget {
  const WelcomeVideoBackground({super.key, this.frosted = false, this.child});
  final bool frosted;
  final Widget? child;
  @override
  State<WelcomeVideoBackground> createState() => _WelcomeVideoBackgroundState();
}

class _WelcomeVideoBackgroundState extends State<WelcomeVideoBackground>
    with RouteAware {
  late final _WelcomeMedia media;
  ModalRoute<dynamic>? _route;
  @override
  void initState() {
    super.initState();
    media = _WelcomeMedia.current ??= _WelcomeMedia();
    media.users++;
    media.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    welcomeMediaRouteObserver.unsubscribe(this);
    _route = route;
    if (route != null) welcomeMediaRouteObserver.subscribe(this, route);
    media.visibility(this, route?.isCurrent ?? true);
  }

  @override
  void didPushNext() => media.visibility(this, false);
  @override
  void didPopNext() => media.visibility(this, true);
  @override
  void didPop() => media.visibility(this, false);
  @override
  void dispose() {
    welcomeMediaRouteObserver.unsubscribe(this);
    media.removeListener(_changed);
    media.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Image(
          key: ValueKey('legacy-welcome-background'),
          image: AssetImage('assets/legacy/home/legacy_login_cover.jpg'),
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
        if (media.ready && !media.failed)
          Positioned.fill(
            child: ExcludeSemantics(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: media.video.value.size.width,
                    height: media.video.value.size.height,
                    child: VideoPlayer(media.video),
                  ),
                ),
              ),
            ),
          ),
        if (widget.frosted)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                key: const ValueKey('mobile-login-frosted-glass'),
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: const ColoredBox(color: Color(0xB8000000)),
              ),
            ),
          ),
        if (widget.child != null) widget.child!,
        if (media.ready && !media.failed)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: 16,
            child: IconButton(
              key: const ValueKey('welcome-sound-toggle'),
              tooltip: media.muted ? '开启声音' : '关闭声音',
              onPressed: media.toggleSound,
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xB3FFFFFF),
                minimumSize: const Size(48, 48),
              ),
              icon: Icon(
                media.muted ? Icons.volume_off : Icons.volume_up,
                size: 18,
              ),
            ),
          ),
      ],
    );
  }
}
