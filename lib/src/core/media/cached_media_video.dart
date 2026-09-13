import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'media_cache.dart';

/// Remote playback downloads once on activation and reuses the on-disk file.
/// The caller supplies a public or current-member scope and an immutable version key.
class CachedMediaVideo extends StatefulWidget {
  const CachedMediaVideo({
    super.key,
    required this.url,
    required this.scope,
    required this.active,
    required this.contentKey,
    this.muted = true,
    this.headers,
  });
  final String url, scope, contentKey;
  final bool active, muted;
  final Map<String, String>? headers;
  @override
  State<CachedMediaVideo> createState() => _CachedMediaVideoState();
}

class _CachedMediaVideoState extends State<CachedMediaVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _foreground = true, _loading = false, _error = false;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void didUpdateWidget(CachedMediaVideo old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url ||
        old.scope != widget.scope ||
        old.contentKey != widget.contentKey) {
      _epoch++;
      _controller?.dispose();
      _controller = null;
      _loading = false;
      _error = false;
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  Future<void> _sync() async {
    if (widget.active &&
        _foreground &&
        _controller == null &&
        !_loading &&
        !_error) {
      _loading = true;
      final epoch = ++_epoch;
      VideoPlayerController? controller;
      try {
        final file = await MediaCache.shared.get(
          widget.url,
          scope: widget.scope,
          contentKey: widget.contentKey,
          kind: MediaKind.video,
          headers: widget.headers,
        );
        if (!mounted || epoch != _epoch) return;
        controller = VideoPlayerController.file(file);
        await controller.initialize();
        await controller.setLooping(true);
        if (!mounted || epoch != _epoch) {
          await controller.dispose();
          return;
        }
        setState(() {
          _controller = controller;
          _loading = false;
        });
      } catch (_) {
        await controller?.dispose();
        if (mounted && epoch == _epoch) {
          setState(() {
            _loading = false;
            _error = true;
          });
        }
      }
    }
    final controller = _controller;
    if (controller == null) return;
    await controller.setVolume(widget.muted ? 0 : 1);
    if (widget.active && _foreground) {
      await controller.play();
    } else {
      await controller.pause();
    }
  }

  @override
  void dispose() {
    _epoch++;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() => _error = false);
            _sync();
          },
          child: const Text('视频加载失败，点击重试'),
        ),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 1));
    }
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }
}
