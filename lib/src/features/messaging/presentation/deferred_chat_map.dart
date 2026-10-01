import 'package:flutter/material.dart';

/// Platform map initialization must not compete with the page slide animation.
/// Its preview remains opaque until the native map has positioned and rendered.
class DeferredChatMap extends StatefulWidget {
  const DeferredChatMap({
    super.key,
    required this.map,
    required this.ready,
    required this.placeholder,
  });
  final Widget map;
  final bool ready;
  final Widget placeholder;
  @override
  State<DeferredChatMap> createState() => _DeferredChatMapState();
}

class _DeferredChatMapState extends State<DeferredChatMap> {
  bool _started = false;
  bool _revealed = false;
  bool _checking = false;
  Animation<double>? _routeAnimation;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkRoute();
  }

  void _checkRoute() {
    if (_started || _routeAnimation != null || _checking) return;
    _checking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checking = false;
      if (!mounted) return;
      final route = ModalRoute.of(context);
      // Navigator's offstage measurement temporarily presents a completed
      // animation. It is not the end of the actual incoming page transition.
      if (route?.offstage == true) {
        _checkRoute();
        return;
      }
      final animation = route?.animation;
      if (animation != null && animation.status != AnimationStatus.completed) {
        _routeAnimation = animation;
        animation.addStatusListener(_status);
      } else {
        setState(() => _started = true);
      }
    });
  }

  void _status(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _routeAnimation?.removeStatusListener(_status);
    _routeAnimation = null;
    setState(() => _started = true);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_status);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ready) _revealed = true;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_started) widget.map,
        IgnorePointer(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child: _started && _revealed
                ? const SizedBox.expand(key: ValueKey('map-ready'))
                : SizedBox.expand(
                    key: const ValueKey('map-preview'),
                    child: widget.placeholder,
                  ),
          ),
        ),
      ],
    );
  }
}
