import 'dart:async';

import 'package:flutter/material.dart';

/// Global lightweight feedback; actionable snackbars retain their interaction.
class KingNotice {
  KingNotice._(this.context);
  final BuildContext context;
  static OverlayEntry? _entry;
  static KingNotice of(BuildContext context) => KingNotice._(context);
  void hideCurrentSnackBar() {
    _entry?.remove();
    _entry = null;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  }

  void show(String message) => showSnackBar(SnackBar(content: Text(message)));
  void showSnackBar(SnackBar snackBar) {
    if (!context.mounted) return;
    hideCurrentSnackBar();
    if (snackBar.action != null) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }
    final overlay =
        Overlay.maybeOf(context, rootOverlay: true) ??
        Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NoticeCard(
        content: snackBar.content,
        onDisposed: () {
          if (identical(_entry, entry)) _entry = null;
        },
        onDone: () {
          if (identical(_entry, entry)) {
            _entry = null;
            entry.remove();
          }
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

class _NoticeCard extends StatefulWidget {
  const _NoticeCard({
    required this.content,
    required this.onDone,
    required this.onDisposed,
  });
  final Widget content;
  final VoidCallback onDone, onDisposed;
  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 180),
  );
  Timer? _timer;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _animation.value = 1;
    } else {
      _animation.forward();
    }
    _timer = Timer(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      if (!reduceMotion) {
        await _animation.reverse();
      }
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    widget.onDisposed();
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: const Alignment(0, -.15),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) => Opacity(
              opacity: _animation.value,
              child: Transform.scale(
                scale: _animation.status == AnimationStatus.reverse
                    ? 1
                    : 1.10 -
                          .10 * Curves.easeOutCubic.transform(_animation.value),
                child: child,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                key: const ValueKey('king-global-notice'),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .72,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xB328231C),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Color(0xFFC9B69E),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    child: widget.content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
