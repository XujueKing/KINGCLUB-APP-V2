import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/auth_repository.dart';
import 'group_call_repository.dart';

/// State coordination only. Watching never accepts a call or renews its lease.
/// Media ownership and capture authorization belong to the media controller.
class GroupCallController extends ChangeNotifier {
  GroupCallController({
    required this.repository,
    required GroupCallSnapshot initial,
    required Stream<void> sessionChanges,
    required Stream<void> invalidations,
    this.pollInterval = const Duration(seconds: 2),
    String Function()? requestId,
  }) : _call = initial,
       _requestId = requestId ?? const Uuid().v4 {
    if (pollInterval <= Duration.zero ||
        !initial.participants.any(
          (p) => p.account == repository.messaging.account,
        )) {
      throw ArgumentError('Invalid group call controller');
    }
    _sessionChanges = sessionChanges.listen((_) => close());
    _invalidations = invalidations.listen((_) {
      if (_watching) {
        unawaited(refresh().catchError((Object _) {}));
      }
    });
    _adopt(initial);
  }

  final GroupCallRepository repository;
  final Duration pollInterval;
  final String Function() _requestId;
  late final StreamSubscription<void> _sessionChanges, _invalidations;
  GroupCallSnapshot _call;
  GroupCallSnapshot get call => _call;
  Object? _error;
  Object? get error => _error;
  bool _closed = false, _disposed = false, _watching = false;
  bool get isClosed => _closed;
  Timer? _timer;
  Future<void> _tail = Future.value();
  Future<void>? _refreshing;
  bool _refreshAgain = false;
  final _pending = <GroupCallAction, ({GroupCallSnapshot call, String id})>{};

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _serialize(Future<void> Function() work) {
    final result = _tail.then((_) async {
      if (_closed) {
        return;
      }
      try {
        await work();
        if (!_closed) {
          _error = null;
        }
      } catch (error) {
        if (!_closed) {
          _error = error;
          if (error is AuthFailure &&
              {
                'SESSION_CHANGED',
                'SESSION_EXPIRED',
                'ACCESS_DENIED',
                'CHAT_GROUP_CALL_ACCESS_DENIED',
                'CHAT_GROUP_CALL_MEMBER_CHANGED',
              }.contains(error.code)) {
            close();
          }
        }
        rethrow;
      } finally {
        _notify();
      }
    });
    _tail = result.catchError((Object _) {});
    return result;
  }

  void _adopt(GroupCallSnapshot next) {
    if (_closed) {
      return;
    }
    final accounts = _call.participants.map((p) => p.account).toSet();
    if (next.id != _call.id ||
        next.groupId != _call.groupId ||
        next.media != _call.media ||
        next.version < _call.version ||
        next.participants.length != accounts.length ||
        !next.participants.every((p) => accounts.contains(p.account))) {
      throw const FormatException('Group call refresh mismatch');
    }
    _call = next;
    if (next.endedAtMs != null ||
        !next.participants
            .singleWhere((p) => p.account == repository.messaging.account)
            .isActive) {
      close();
    }
  }

  void watch() {
    if (_closed || _watching) {
      return;
    }
    _watching = true;
    _timer = Timer.periodic(pollInterval, (_) {
      unawaited(refresh().catchError((Object _) {}));
    });
    unawaited(refresh().catchError((Object _) {}));
  }

  Future<void> refresh() {
    if (_closed) {
      return Future.value();
    }
    if (_refreshing != null) {
      _refreshAgain = true;
      return _refreshing!;
    }
    return _refreshing = _serialize(() async {
      // Bound follow-up work so slow reads cannot starve a queued user action.
      for (var pass = 0; pass < 2; pass++) {
        _refreshAgain = false;
        _adopt(await repository.read(_call.id));
        if (!_refreshAgain || _closed) {
          break;
        }
      }
    }).whenComplete(() => _refreshing = null);
  }

  /// The owner calls heartbeat only while its real media connection is alive.
  Future<void> act(GroupCallAction action) => _serialize(() async {
    final attempt = _pending.putIfAbsent(
      action,
      () => (call: _call, id: _requestId()),
    );
    try {
      final result = await repository.act(
        call: attempt.call,
        action: action,
        requestId: attempt.id,
      );
      if (_closed) {
        return;
      }
      _adopt(result.call);
      _pending.remove(action);
    } on AuthFailure catch (error) {
      if (error.code == 'CHAT_GROUP_CALL_VERSION_CONFLICT' && !_closed) {
        // This response proves the command did not apply. Sync before a new
        // user attempt; never silently accept or start capture on their behalf.
        _pending.remove(action);
        _adopt(await repository.read(_call.id));
      }
      rethrow;
    }
  });

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _timer?.cancel();
    _pending.clear();
    unawaited(_sessionChanges.cancel());
    unawaited(_invalidations.cancel());
    _notify();
  }

  @override
  void dispose() {
    close();
    _disposed = true;
    super.dispose();
  }
}
