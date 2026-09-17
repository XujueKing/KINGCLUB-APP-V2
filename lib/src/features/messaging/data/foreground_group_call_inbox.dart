import 'dart:async';

import '../../auth/domain/auth_repository.dart';
import 'group_call_repository.dart';

/// Foreground invitation discovery only. Never accepts or captures media.
class ForegroundGroupCallInbox {
  ForegroundGroupCallInbox({
    required this.repository,
    required this.present,
    this.interval = const Duration(seconds: 5),
  });
  final GroupCallRepository repository;
  final Future<bool> Function(GroupCallSnapshot) present;
  final Duration interval;
  Timer? _timer;
  Future<void>? _refreshing;
  bool _refreshQueued = false;
  bool _closed = false, _foreground = false;
  int _generation = 0;
  String? _shown;
  void foreground(bool enabled) {
    if (_closed || enabled == _foreground) return;
    _foreground = enabled;
    _generation++;
    _timer?.cancel();
    if (enabled) {
      _timer = Timer.periodic(interval, (_) => notify());
      notify();
    }
  }

  void notify() => unawaited(refresh().catchError((Object _) {}));
  Future<void> refresh() {
    if (_closed || !_foreground) return Future.value();
    if (_refreshing != null) {
      _refreshQueued = true;
      return _refreshing!;
    }
    _refreshQueued = false;
    return _refreshing = _read().whenComplete(() {
      _refreshing = null;
      if (_refreshQueued && !_closed && _foreground) notify();
    });
  }

  Future<void> _read() async {
    final generation = _generation;
    GroupCallSnapshot? call;
    try {
      call = await repository.current();
    } on AuthFailure catch (error) {
      if (_closed || !_foreground || generation != _generation) return;
      if (error.code == 'INTERFACE_DISABLED' ||
          error.code == 'INTERFACE_NOT_FOUND') {
        foreground(false);
        return;
      }
      rethrow;
    }
    if (_closed || !_foreground || generation != _generation) return;
    if (call == null) {
      _shown = null;
      return;
    }
    if (call.endedAtMs != null ||
        call.participants
                .singleWhere((p) => p.account == repository.messaging.account)
                .phase !=
            GroupCallPhase.invited ||
        _shown == call.id) {
      return;
    }
    _shown = call.id;
    try {
      if (!await present(call) && !_closed) _shown = null;
    } catch (_) {
      if (!_closed) _shown = null;
      rethrow;
    }
  }

  void close() {
    _closed = true;
    _generation++;
    _timer?.cancel();
  }
}
