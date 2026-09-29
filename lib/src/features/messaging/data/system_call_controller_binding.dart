import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_state_controller.dart';
import 'native_system_calls.dart';

/// Bridges an already authenticated incoming call to CallKit actions.
/// The page/runtime keeps ownership of the controller and media session.
class SystemCallControllerBinding {
  SystemCallControllerBinding({
    required this.controller,
    required this.native,
    this.connectionTimeout = const Duration(seconds: 20),
  }) {
    controller.addListener(_changed);
  }
  final CallStateController controller;
  final NativeSystemCalls native;
  final Duration connectionTimeout;
  final Map<String, Future<void>> _actions = {};
  bool _closed = false, _ending = false, _reportedEnd = false;

  bool owns(SystemCallEvent event) =>
      !event.group &&
      event.callId == controller.call.id.toLowerCase() &&
      event.account == controller.repository.messaging.account &&
      controller.call.callee == event.account;

  Future<void> handle(SystemCallEvent event) {
    if (_closed || !owns(event)) return Future.value();
    return _actions.putIfAbsent(event.id, () => _handle(event));
  }

  Future<void> _handle(SystemCallEvent event) async {
    switch (event.kind) {
      case SystemCallEventKind.incoming:
        await native.acknowledge(event);
      case SystemCallEventKind.answer:
        var success = false;
        try {
          if (_ending || controller.isClosed) throw StateError('Call ended');
          await controller.accept();
          await _connected();
          success = !_closed && !_ending && !controller.isClosed;
        } catch (_) {
          // End local capture immediately, even if signaling is unavailable.
          _ending = true;
          unawaited(controller.end().catchError((Object _) {}));
        }
        await native.completeAction(event, success: success);
      case SystemCallEventKind.end:
        _ending = true;
        try {
          await controller.end();
          await native.completeAction(event, success: true);
        } catch (_) {
          await native.completeAction(event, success: false);
        }
      case SystemCallEventKind.ended:
        _ending = true;
        // Native timeout/reset must stop capture without waiting for HTTP.
        unawaited(controller.end().catchError((Object _) {}));
        await native.acknowledge(event);
    }
  }

  Future<void> _connected() async {
    final ready = Completer<void>();
    void check() {
      if (ready.isCompleted) return;
      if (_closed || _ending || controller.isClosed || controller.isEnding) {
        ready.completeError(StateError('Call ended before media connected'));
      } else if (controller.connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        ready.complete();
      }
    }

    controller.addListener(check);
    check();
    try {
      await ready.future.timeout(connectionTimeout);
    } finally {
      controller.removeListener(check);
    }
  }

  void _changed() {
    if (_closed || _ending || !controller.isClosed || _reportedEnd) return;
    _reportedEnd = true;
    unawaited(native.end(controller.call.id).catchError((Object _) {}));
  }

  void close() {
    if (_closed) return;
    _closed = true;
    controller.removeListener(_changed);
    _actions.clear();
  }
}
