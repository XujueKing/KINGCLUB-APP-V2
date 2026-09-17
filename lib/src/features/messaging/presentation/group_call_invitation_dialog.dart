import 'dart:async';

import 'package:flutter/material.dart';

import '../data/call_repository.dart';
import '../data/group_call_controller.dart';
import '../data/group_call_repository.dart';

/// Owns read-only invitation watching. It never accepts or captures media.
class GroupCallInvitationDialog extends StatefulWidget {
  const GroupCallInvitationDialog({
    super.key,
    required this.controller,
    this.onInterrupted,
  });
  final GroupCallController controller;
  final VoidCallback? onInterrupted;
  @override
  State<GroupCallInvitationDialog> createState() => _InvitationState();
}

class _InvitationState extends State<GroupCallInvitationDialog> {
  Timer? _expiry;
  bool _finished = false;
  GroupCallController get _controller => widget.controller;
  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _changed();
      if (!_finished) _controller.watch();
    });
  }

  void _changed() {
    if (!mounted || _finished) return;
    final self = _controller.call.participants.singleWhere(
      (p) => p.account == _controller.repository.messaging.account,
    );
    final remaining = self.deadlineMs - DateTime.now().millisecondsSinceEpoch;
    if (_controller.isClosed ||
        _controller.call.endedAtMs != null ||
        self.phase != GroupCallPhase.invited ||
        remaining <= 0) {
      _finish(null);
      return;
    }
    _expiry?.cancel();
    _expiry = Timer(Duration(milliseconds: remaining), () => _finish(null));
  }

  void _finish(bool? answer) {
    if (!mounted || _finished) return;
    _finished = true;
    _expiry?.cancel();
    final route = ModalRoute.of(context);
    if (route == null) return;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop(answer);
    } else {
      // A session redirect may already cover this dialog. Remove this route
      // specifically, never pop the newly opened login or another page.
      navigator.removeRoute(route);
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _controller.removeListener(_changed);
    _controller.dispose();
    if (!_finished) widget.onInterrupted?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _controller.call.media == CallMedia.video ? '群视频通话邀请' : '群语音通话邀请',
    ),
    content: const Text('是否接听群通话？'),
    actions: [
      TextButton(onPressed: () => _finish(false), child: const Text('拒绝')),
      TextButton(onPressed: () => _finish(true), child: const Text('接听')),
    ],
  );
}
