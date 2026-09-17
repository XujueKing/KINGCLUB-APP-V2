import 'package:flutter/widgets.dart';

import '../data/call_presentation_lease.dart';

/// Navigator destruction may dispose a route without completing push().
/// Keep presentation ownership tied to the route, not its awaiting caller.
class CallPresentationScope extends StatefulWidget {
  const CallPresentationScope({
    super.key,
    required this.lease,
    required this.child,
  });
  final CallPresentationLease lease;
  final Widget child;

  @override
  State<CallPresentationScope> createState() => _CallPresentationScopeState();
}

class _CallPresentationScopeState extends State<CallPresentationScope> {
  @override
  void didUpdateWidget(CallPresentationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lease, widget.lease)) oldWidget.lease.release();
  }

  @override
  void dispose() {
    widget.lease.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
