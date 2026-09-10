import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

final welcomeMediaRouteObserver = RouteObserver<ModalRoute<dynamic>>();

/// Local opening movie; audio follows both route visibility and app lifecycle.
class WelcomeVideoBackground extends StatefulWidget {
  const WelcomeVideoBackground({super.key});

  @override
  State<WelcomeVideoBackground> createState() => _WelcomeVideoBackgroundState();
}

class _WelcomeVideoBackgroundState extends State<WelcomeVideoBackground>
    with WidgetsBindingObserver, RouteAware {
  late final VideoPlayerController _controller;
  ModalRoute<dynamic>? _route;
  bool _visible = true;
  bool _foreground = true;
  bool _ready = false;
  bool _failed = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _controller = VideoPlayerController.asset(
      'assets/legacy/home/welcome_cover.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _controller.addListener(_checkError);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      await _controller.setLooping(true);
      if (!mounted) return;
      await _controller.setVolume(1);
      if (!mounted) return;
      setState(() => _ready = true);
      await _syncPlayback();
    } catch (_) {
      _fail();
    }
  }

  void _checkError() {
    if (_controller.value.hasError) _fail();
  }

  void _fail() {
    if (!mounted || _failed) return;
    setState(() => _failed = true);
    unawaited(_syncPlayback());
  }

  Future<void> _syncPlayback() async {
    if (!mounted || !_ready) return;
    try {
      if (_visible && _foreground && !_failed) {
        await _controller.play();
      } else {
        await _controller.pause();
      }
    } catch (_) {
      _fail();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    welcomeMediaRouteObserver.unsubscribe(this);
    _route = route;
    _visible = route?.isCurrent ?? true;
    if (route != null) welcomeMediaRouteObserver.subscribe(this, route);
    unawaited(_syncPlayback());
  }

  @override
  void didPushNext() {
    _visible = false;
    unawaited(_syncPlayback());
  }

  @override
  void didPopNext() {
    _visible = true;
    unawaited(_syncPlayback());
  }

  @override
  void didPop() {
    _visible = false;
    unawaited(_syncPlayback());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_syncPlayback());
  }

  Future<void> _toggleSound() async {
    setState(() => _muted = !_muted);
    try {
      await _controller.setVolume(_muted ? 0 : 1);
    } catch (_) {
      _fail();
    }
  }

  @override
  void dispose() {
    welcomeMediaRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_checkError);
    unawaited(_controller.dispose());
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
        if (_ready && !_failed)
          Positioned.fill(
            child: ExcludeSemantics(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            ),
          ),
        if (_ready && !_failed)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: 16,
            child: IconButton.filledTonal(
              key: const ValueKey('welcome-sound-toggle'),
              tooltip: _muted ? '开启声音' : '关闭声音',
              onPressed: _toggleSound,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: const Color(0xFFC9B69E),
                minimumSize: const Size(48, 48),
              ),
              icon: Icon(_muted ? Icons.volume_off : Icons.volume_up, size: 22),
            ),
          ),
      ],
    );
  }
}
