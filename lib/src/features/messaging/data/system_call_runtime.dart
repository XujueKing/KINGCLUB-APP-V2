import 'dart:async';

import 'call_state_controller.dart';
import 'native_system_calls.dart';
import 'system_call_controller_binding.dart';

/// Owns native events independently of routes, including engine cold starts.
/// Preparing a controller must authenticate the explicit call ID; it must not
/// accept the call or capture media. Only an answer action authorizes capture.
class SystemCallRuntime {
  SystemCallRuntime({
    required this.native,
    required this.prepare,
    required this.changed,
    this.prepareTimeout = const Duration(seconds: 10),
    this.tokenChanged,
  });

  static SystemCallRuntime? shared;
  final NativeSystemCalls native;
  final Future<CallStateController> Function(SystemCallEvent) prepare;
  final void Function() changed;
  final Duration prepareTimeout;
  final void Function()? tokenChanged;
  SystemCallControllerBinding? _binding;
  Future<CallStateController>? _preparing;
  String? _preparingId;
  int _generation = 0;
  bool _closed = false;
  bool _pageOwnsController = false;
  final Set<String> _handling = {};

  CallStateController? get active => _binding?.controller;
  void attachPage(CallStateController controller) {
    if (identical(active, controller)) _pageOwnsController = true;
  }

  CallStateController? find(String id) {
    final controller = active;
    return controller != null &&
            !controller.isClosed &&
            controller.call.id.toLowerCase() == id.toLowerCase()
        ? controller
        : null;
  }

  void start() {
    native.listen(
      changed: drain,
      audio: (_) async {},
      tokenChanged: tokenChanged,
    );
    unawaited(drain());
  }

  void adopt(CallStateController controller) {
    if (_closed) throw StateError('System call runtime closed');
    if (identical(active, controller)) return;
    if (active != null && !active!.isClosed) {
      throw StateError('Call already active');
    }
    final previous = active;
    final pageOwned = _pageOwnsController;
    _binding?.close();
    if (previous != null && !pageOwned) previous.dispose();
    _pageOwnsController = false;
    _binding = SystemCallControllerBinding(
      controller: controller,
      native: native,
    );
    controller.watch();
    changed();
  }

  Future<CallStateController> _resolve(SystemCallEvent event) async {
    final current = find(event.callId);
    if (current != null) return current;
    if (_preparing != null) {
      if (_preparingId != event.callId) throw StateError('Call setup busy');
      return _preparing!;
    }
    if (active != null && !active!.isClosed) {
      throw StateError('Call already active');
    }
    final generation = _generation;
    var expired = false;
    _preparingId = event.callId;
    final work = prepare(event).then((controller) {
      if (_closed || expired || generation != _generation) {
        controller.dispose();
        throw StateError('Call setup superseded');
      }
      // A foreground inbox may have won the race while HTTP was pending.
      final existing = find(event.callId);
      if (existing != null) {
        controller.dispose();
        return existing;
      }
      if (controller.call.id.toLowerCase() != event.callId ||
          controller.call.callee != event.account ||
          controller.repository.messaging.account != event.account) {
        controller.dispose();
        throw StateError('Call identity mismatch');
      }
      adopt(controller);
      return controller;
    });
    _preparing = work.timeout(
      prepareTimeout,
      onTimeout: () {
        expired = true;
        throw TimeoutException('Call setup timed out');
      },
    );
    try {
      return await _preparing!;
    } finally {
      if (generation == _generation) {
        _preparing = null;
        _preparingId = null;
      }
    }
  }

  Future<void> drain() async {
    if (_closed) return;
    try {
      for (final event in await native.pending()) {
        if (_closed) return;
        if (_handling.add(event.id)) {
          // Do not block end/timeout actions behind an answer waiting for ICE.
          unawaited(
            _handle(event).whenComplete(() => _handling.remove(event.id)),
          );
        }
      }
    } catch (_) {
      /* Native deadlines remain authoritative if bridge fails. */
    }
  }

  Future<void> _handle(SystemCallEvent event) async {
    try {
      if (event.group) throw StateError('Group system call not enabled');
      if (event.kind == SystemCallEventKind.ended &&
          find(event.callId) == null) {
        // Invalidate a fetch still in flight after a native timeout.
        if (_preparingId == event.callId) reset();
        await native.acknowledge(event);
        return;
      }
      await _resolve(event);
      if (_closed || _binding?.owns(event) != true) {
        throw StateError('Call changed');
      }
      await _binding!.handle(event);
      changed();
    } catch (_) {
      try {
        if (event.actionId != null) {
          await native.completeAction(event, success: false);
        }
        await native.end(event.callId, failed: true);
        await native.acknowledge(event);
      } catch (_) {}
    }
  }

  void release(CallStateController controller) {
    if (!identical(active, controller)) return;
    _binding?.close();
    _binding = null;
    unawaited(native.end(controller.call.id).catchError((Object _) {}));
  }

  void reset() {
    _generation++;
    _preparing = null;
    _preparingId = null;
    final controller = active;
    if (controller != null) {
      final pageOwned = _pageOwnsController;
      release(controller);
      if (pageOwned) {
        unawaited(controller.close().catchError((Object _) {}));
      } else {
        controller.dispose();
      }
    }
  }

  void close() {
    _closed = true;
    reset();
    native.detach();
    if (identical(shared, this)) shared = null;
  }
}
