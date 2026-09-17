import 'dart:async';

import 'call_launch_coordinator.dart';
import '../../auth/domain/auth_repository.dart';

/// One foreground inbox per login session. Presentation owns its route until
/// its returned future finishes; duplicate notifications cannot stack routes.
class ForegroundCallInbox {
  ForegroundCallInbox({
    required this.launcher,
    required this.present,
    this.interval = const Duration(seconds: 5),
  });
  final CallLaunchCoordinator launcher;
  final Future<bool> Function(PreparedCall) present;
  final Duration interval;
  Timer? _timer;
  Future<void>? _refreshing;
  bool _refreshQueued = false;
  bool _closed = false, _foreground = false;
  int _generation = 0;
  String? _shown;

  void foreground(bool enabled) {
    if (_closed || _foreground == enabled) return;
    _foreground = enabled;
    _generation++;
    _timer?.cancel();
    _timer = null;
    if (enabled) {
      _timer = Timer.periodic(interval, (_) => notify());
      notify();
    }
  }

  void notify() {
    unawaited(refresh().catchError((Object _) {}));
  }

  Future<void> refresh() {
    if (_closed || !_foreground) return Future.value();
    if (_refreshing != null) {
      _refreshQueued = true;
      return _refreshing!;
    }
    _refreshQueued = false;
    return _refreshing = _refresh().whenComplete(() {
      _refreshing = null;
      if (_refreshQueued && !_closed && _foreground) notify();
    });
  }

  Future<void> _refresh() async {
    final generation = _generation;
    PreparedCall? ready;
    try {
      ready = await launcher.incoming();
    } on AuthFailure catch (error) {
      if (_closed || !_foreground || generation != _generation) return;
      if (error.code == 'INTERFACE_NOT_FOUND' ||
          error.code == 'INTERFACE_DISABLED') {
        foreground(false);
        return;
      }
      rethrow;
    }
    if (_closed || !_foreground || generation != _generation) return;
    if (ready == null) {
      _shown = null;
      return;
    }
    if (_shown == ready.call.id) return;
    // Set before awaiting presentation, which may run until hangup.
    _shown = ready.call.id;
    try {
      final displayed = await present(ready);
      if (!displayed && !_closed) _shown = null;
    } catch (_) {
      if (!_closed) _shown = null;
      rethrow;
    }
  }

  void close() {
    _closed = true;
    _generation++;
    _timer?.cancel();
    launcher.close();
  }
}
