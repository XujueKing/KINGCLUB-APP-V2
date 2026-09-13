import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/auth_repository.dart';
import 'call_media_session.dart';
import 'call_repository.dart';

typedef CallSessionFactory = CallMediaSession Function(
  CallSnapshot call,
  void Function(RTCPeerConnectionState) onConnection,
);

/// Owns one explicitly opened call attempt, not background call discovery.
/// A caller may watch only their newly created ringing attempt. A callee must
/// explicitly accept before this controller is allowed to open native media.
class CallStateController extends ChangeNotifier {
  CallStateController({
    required this.repository,
    required CallSnapshot initial,
    required this.sessionFactory,
    required Stream<void> sessionChanges,
    this.pollInterval = const Duration(seconds: 2),
  }) : _call = initial {
    if (initial.phase != CallPhase.ringing ||
        (initial.caller != repository.messaging.account &&
            initial.callee != repository.messaging.account)) {
      throw StateError('A new ringing call is required');
    }
    _captureAuthorized = initial.caller == repository.messaging.account;
    _sessionChanges = sessionChanges.listen((_) {
      unawaited(
        close().catchError((Object error) {
          _error = error;
        }),
      );
    });
  }

  final CallRepository repository;
  final CallSessionFactory sessionFactory;
  final Duration pollInterval;
  late final StreamSubscription<void> _sessionChanges;
  CallSnapshot _call;
  CallSnapshot get call => _call;
  Object? _error;
  Object? get error => _error;
  CallMediaSession? _media;
  CallMediaSession? get media => _media;
  bool get isClosed => _closed;
  bool get isEnding => _ending;
  bool get needsAccept =>
      !_closed &&
      !_ending &&
      !_captureAuthorized &&
      _call.callee == repository.messaging.account;
  RTCPeerConnectionState? _connectionState;
  RTCPeerConnectionState? get connectionState => _connectionState;
  Timer? _timer;
  Future<void> _tail = Future.value();
  Future<void>? _refreshing, _closing;
  final _pending = <CallAction, ({CallSnapshot call, String id})>{};
  bool _captureAuthorized = false, _ending = false, _closed = false;
  bool _connected = false, _connectionReported = false, _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _tail.then((_) async {
      if (_closed) return;
      try {
        await operation();
        _error = null;
      } catch (error) {
        _error = error;
        if (error is AuthFailure &&
            {
              'SESSION_CHANGED',
              'SESSION_EXPIRED',
              'ACCESS_DENIED',
              'CHAT_CALL_SIGNAL_STATE',
            }.contains(error.code)) {
          await close();
        }
        rethrow;
      } finally {
        _notify();
      }
    });
    _tail = result.catchError((Object _) {});
    return result;
  }

  void watch() {
    if (_closed || _timer != null) return;
    if (pollInterval <= Duration.zero) {
      throw ArgumentError('Invalid poll interval');
    }
    _timer = Timer.periodic(pollInterval, (_) {
      unawaited(refresh().catchError((Object _) {}));
    });
    unawaited(refresh().catchError((Object _) {}));
  }

  Future<void> refresh() => _refreshing ??= _serialize(() async {
    final next = await repository.read(callId: _call.id);
    if (_closed) return;
    await _adopt(next!);
    if (_ending && _call.phase != CallPhase.ended) {
      await _endOnServer();
    } else if (!_ending && !_closed) {
      await _ensureMedia();
      if (_connected &&
          !_connectionReported &&
          _call.phase == CallPhase.connecting) {
        await _act(CallAction.connected);
        _connectionReported = true;
      }
      if (!_closed && !_ending && _media != null) await _syncMedia();
    }
  }).whenComplete(() => _refreshing = null);

  Future<void> _adopt(CallSnapshot next) async {
    if (next.id != _call.id ||
        next.caller != _call.caller ||
        next.callee != _call.callee ||
        next.media != _call.media ||
        next.version < _call.version) {
      throw const FormatException('Call refresh mismatch');
    }
    _call = next;
    if (next.phase == CallPhase.ended) await close();
  }

  Future<void> accept() => _serialize(() async {
    if (_ending || _call.callee != repository.messaging.account) {
      throw StateError('Cannot accept this call');
    }
    if (_captureAuthorized) return;
    // An uncertain accept response is retried with the same expected version
    // and ID even if a poll has already observed connecting in the meantime.
    await _act(CallAction.accept);
    if (_closed || _ending) return;
    _captureAuthorized = true;
    await _ensureMedia();
    if (!_closed && !_ending) await _syncMedia();
  });

  Future<void> _syncMedia() async {
    try {
      await _media?.sync();
    } catch (_) {
      // A native negotiation error can already have stopped capture. The next
      // refresh must terminate the server call instead of retrying a dead peer.
      if (_media?.isClosed == true) _ending = true;
      rethrow;
    }
  }

  Future<void> _ensureMedia() async {
    if (_closed ||
        _ending ||
        !_captureAuthorized ||
        _media != null ||
        _call.phase != CallPhase.connecting) {
      return;
    }
    final media = sessionFactory(_call, _onConnection);
    _media = media;
    try {
      await media.start();
    } catch (_) {
      _ending = true;
      await media.close();
      rethrow;
    }
  }

  void _onConnection(RTCPeerConnectionState state) {
    if (_closed || _ending) return;
    _connectionState = state;
    _notify();
    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _connected = true;
      unawaited(refresh().catchError((Object _) {}));
    } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
        state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
      unawaited(end().catchError((Object _) {}));
    }
  }

  Future<void> _act(CallAction action) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final pending = _pending.putIfAbsent(
        action,
        () => (call: _call, id: const Uuid().v4()),
      );
      try {
        final next = await repository.act(
          call: pending.call,
          action: action,
          requestId: pending.id,
        );
        _pending.remove(action);
        if (!_closed) await _adopt(next);
        return;
      } on AuthFailure catch (error) {
        if (error.code != 'CHAT_CALL_VERSION_CONFLICT') rethrow;
        _pending.remove(action);
        final next = await repository.read(callId: _call.id);
        if (_closed) return;
        await _adopt(next!);
        if (_closed ||
            (action == CallAction.connected &&
                _call.phase == CallPhase.active)) {
          return;
        }
        if (action == CallAction.accept && _call.phase != CallPhase.ringing) {
          rethrow;
        }
      }
    }
    throw const AuthFailure('CHAT_CALL_VERSION_CONFLICT', '通话状态已变化，请重试');
  }

  Future<void> end() {
    if (_closed) return Future.value();
    _ending = true;
    // Release local capture immediately, even while a network request is stuck.
    final stopping = _media?.close() ?? Future<void>.value();
    // Attach a handler now; the serialized operation may wait for HTTP.
    final released = stopping.then<Object?>(
      (_) => null,
      onError: (Object error) => error,
    );
    return _serialize(() async {
      final cleanupError = await released;
      await _endOnServer();
      if (cleanupError != null) throw cleanupError;
    });
  }

  Future<void> _endOnServer() async {
    // Refresh first: accept can race with a caller's cancel button.
    final next = await repository.read(callId: _call.id);
    if (_closed) return;
    await _adopt(next!);
    if (_closed) return;
    await _act(
      _call.phase == CallPhase.ringing
          ? (_call.caller == repository.messaging.account
                ? CallAction.cancel
                : CallAction.decline)
          : CallAction.hangup,
    );
  }

  Future<void> close() {
    final wasClosed = _closed;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    if (!wasClosed) _notify();
    return _closing ??= _close();
  }

  Future<void> _close() async {
    await _sessionChanges.cancel();
    await _media?.close();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
