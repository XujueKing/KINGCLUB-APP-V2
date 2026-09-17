import 'dart:async';

import 'package:flutter/material.dart';

import '../data/call_presentation_lease.dart';

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
