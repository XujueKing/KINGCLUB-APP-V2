import 'dart:async';

import 'package:flutter/material.dart';

import '../data/call_presentation_lease.dart';
import '../../../core/session/secure_session_store.dart';

/// Lives above the navigator so navigation never owns active capture.
class CallPresentationHost extends StatefulWidget {
  const CallPresentationHost({super.key, required this.child});
  final Widget child;
  @override
  State<CallPresentationHost> createState() => _CallPresentationHostState();
}

class CallPresentationControls extends InheritedWidget {
  const CallPresentationControls._(this._host, {
    required this.minimized,
    required super.child,
  });
  final _CallPresentationHostState _host;
  final bool minimized;
  static CallPresentationControls? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CallPresentationControls>();
  void minimize() => _host.minimize();
  void restore() => _host.restore();
  void close() => _host.close();
  set onBack(VoidCallback value) => _host.onBack = value;
  @override
  bool updateShouldNotify(CallPresentationControls oldWidget) =>
      minimized != oldWidget.minimized;
}

class _CallPresentationHostState extends State<CallPresentationHost> {
  Widget? _page;
  NavigatorState? _navigator;
  Route<void>? _route;
  bool _minimized = false;
  Offset _position = const Offset(16, 100);
  VoidCallback? onBack;
  StreamSubscription<void>? _login;

  @override
  void initState() {
    super.initState();
    _login = SecureSessionStore.changes.stream.listen((_) => close());
  }

  Future<void> show(
    NavigatorState navigator,
    Widget page,
    CallPresentationLease lease,
    VoidCallback? onDisposed,
  ) {
    if (_page != null) throw StateError('Another call is visible');
    final done = Completer<void>();
    _navigator = navigator;
    setState(() {
      _minimized = false;
      _page = CallPresentationScope(
        key: ObjectKey(lease),
        lease: lease,
        child: page,
        onDisposed: () {
          onDisposed?.call();
          if (!done.isCompleted) done.complete();
        },
      );
    });
    _pushBackRoute();
    return done.future;
  }

  void _pushBackRoute() {
    final route = PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) (onBack ?? minimize)();
        },
        child: const SizedBox.expand(),
      ),
    );
    _route = route;
    unawaited(
      _navigator!.push<void>(route).then((_) {
        // Router replacement must not destroy a call along with a chat route.
        if (mounted && identical(_route, route)) {
          _route = null;
          setState(() => _minimized = true);
        }
      }),
    );
  }

  void _removeBackRoute() {
    final route = _route;
    _route = null;
    if (route != null && route.navigator != null) {
      route.navigator!.removeRoute(route);
    }
  }

  void minimize() {
    if (_page == null || _minimized) return;
    _removeBackRoute();
    setState(() => _minimized = true);
  }

  void restore() {
    if (_page == null || !_minimized || _navigator?.mounted != true) return;
    setState(() => _minimized = false);
    _pushBackRoute();
  }

  void close() {
    if (!mounted || _page == null) return;
    _removeBackRoute();
    setState(() {
      _page = null;
      onBack = null;
    });
  }

  @override
  void dispose() {
    unawaited(_login?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final left = _position.dx.clamp(
      0.0,
      (size.width - 148).clamp(0.0, double.infinity),
    );
    final top = _position.dy.clamp(
      padding.top,
      (size.height - padding.bottom - 188).clamp(padding.top, double.infinity),
    );
    return _CallHostAccess(
      host: this,
      child: Overlay.wrap(
        child: Stack(
          children: [
            widget.child,
            if (_page != null)
              Positioned(
                left: _minimized ? left : 0,
                top: _minimized ? top : 0,
                width: _minimized ? 148 : size.width,
                height: _minimized ? 188 : size.height,
                child: GestureDetector(
                  onPanUpdate: _minimized
                      ? (details) => setState(() {
                          _position = Offset(left, top) + details.delta;
                        })
                      : null,
                  child: CallPresentationControls._(
                    this,
                    minimized: _minimized,
                    child: _page!,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CallHostAccess extends InheritedWidget {
  const _CallHostAccess({required this.host, required super.child});
  final _CallPresentationHostState host;
  @override
  bool updateShouldNotify(_CallHostAccess oldWidget) => false;
}

class CallMiniWindow extends StatelessWidget {
  const CallMiniWindow({
    super.key,
    required this.title,
    required this.status,
    required this.onRestore,
    required this.onHangUp,
    this.video,
  });
  final String title, status;
  final VoidCallback onRestore, onHangUp;
  final Widget? video;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF202020),
    elevation: 8,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Expanded(
          child: InkWell(
            key: const ValueKey('call-restore'),
            onTap: onRestore,
            child: Stack(
              fit: StackFit.expand,
              children: [
                video ?? const Icon(Icons.call, color: Colors.white, size: 36),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    color: Colors.black54,
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  status,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
            IconButton(
              tooltip: '挂断',
              onPressed: onHangUp,
              icon: const Icon(Icons.call_end, color: Colors.redAccent),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Navigator destruction may dispose a route without completing push().
/// Keep presentation ownership tied to the route, not its awaiting caller.
class CallPresentationScope extends StatefulWidget {
  const CallPresentationScope({
    super.key,
    required this.lease,
    required this.child,
    this.onDisposed,
  });
  final CallPresentationLease lease;
  final Widget child;
  final VoidCallback? onDisposed;

  @override
  State<CallPresentationScope> createState() => _CallPresentationScopeState();
}

class _CallPresentationScopeState extends State<CallPresentationScope> {
  @override
  void didUpdateWidget(CallPresentationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lease, widget.lease)) {
      oldWidget.lease.release();
      oldWidget.onDisposed?.call();
    }
  }

  @override
  void dispose() {
    widget.lease.release();
    widget.onDisposed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Also completes the awaiting inbox when the navigator itself disappears.
Future<void> pushCallPresentation(
  NavigatorState navigator,
  Widget page,
  CallPresentationLease lease, {
  VoidCallback? onDisposed,
}) async {
  final host = navigator.context
      .getInheritedWidgetOfExactType<_CallHostAccess>()
      ?.host;
  if (host != null) {
    await host.show(navigator, page, lease, onDisposed);
    return;
  }
  final disposed = Completer<void>();
  await Future.any<void>([
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => CallPresentationScope(
          lease: lease,
          onDisposed: () {
            onDisposed?.call();
            if (!disposed.isCompleted) disposed.complete();
          },
          child: page,
        ),
      ),
    ),
    disposed.future,
  ]);
}
