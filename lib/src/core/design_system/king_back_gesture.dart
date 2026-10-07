import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Edge return for guarded pages and presentations with their own animation.
/// Normal routes use Flutter's interactive Cupertino back gesture instead.
class KingEdgeBackGesture extends StatefulWidget {
  const KingEdgeBackGesture({
    super.key,
    required this.child,
    this.route,
    this.onBack,
    this.enabled = true,
    this.allowRoot = false,
    this.fallbackOnly = false,
  });

  final Widget child;
  final Route<dynamic>? route;
  final VoidCallback? onBack;
  final bool enabled;
  final bool allowRoot;
  final bool fallbackOnly;

  @override
  State<KingEdgeBackGesture> createState() => _KingEdgeBackGestureState();
}

class _KingEdgeBackGestureState extends State<KingEdgeBackGesture> {
  late final HorizontalDragGestureRecognizer _drag;
  double _distance = 0;
  double _width = 1;
  Route<dynamic>? _startedRoute;

  Route<dynamic>? get _route => widget.route ?? ModalRoute.of(context);

  bool _canStart(Route<dynamic>? route) {
    if (!widget.enabled || route == null || !route.isCurrent) return false;
    if (route.isFirst && !widget.allowRoot) return false;
    if (route.navigator?.userGestureInProgress == true) return false;
    if (route is PageRoute) {
      if (route.animation?.isCompleted != true) return false;
      if (route.secondaryAnimation?.isDismissed != true) return false;
      if (widget.fallbackOnly && route.popGestureEnabled) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _drag = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = (_) {
        _distance = 0;
      }
      ..onUpdate = (details) {
        _distance += details.primaryDelta ?? 0;
      }
      ..onEnd = _end
      ..onCancel = () {
        _startedRoute = null;
      };
  }

  void _pointerDown(PointerDownEvent event) {
    final route = _route;
    if (!_canStart(route)) return;
    final edge = math.max(24.0, MediaQuery.paddingOf(context).left);
    if (event.localPosition.dx < 0 || event.localPosition.dx > edge) return;
    _startedRoute = route;
    _width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    _drag.addPointer(event);
  }

  void _end(DragEndDetails details) {
    final route = _startedRoute;
    _startedRoute = null;
    if (!identical(route, _route) || !_canStart(route)) return;
    final velocity = details.primaryVelocity ?? 0;
    // A deliberate drag or rightward flick; reversing the drag cancels it.
    final commit = velocity.abs() >= _width
        ? velocity > 0 && _distance > 20
        : _distance >= _width * .35;
    if (!commit) return;
    if (widget.onBack case final onBack?) {
      onBack();
    } else {
      // maybePop delivers blocked attempts to PopScope, preserving its guard.
      unawaited(route!.navigator?.maybePop());
    }
  }

  @override
  Widget build(BuildContext context) =>
      Listener(onPointerDown: _pointerDown, child: widget.child);

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }
}
