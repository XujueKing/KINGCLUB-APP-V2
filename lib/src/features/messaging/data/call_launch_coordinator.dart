import '../../auth/domain/auth_repository.dart';

import 'package:uuid/uuid.dart';

import 'call_relay_configuration.dart';
import 'call_repository.dart';

class PreparedCall {
  const PreparedCall(this.call, this.relay, {this.outgoingAttempt = false});
  final bool outgoingAttempt;
  final CallSnapshot call;
  final CallRelayConfiguration relay;
}

/// Account-scoped setup shared by the dial action and foreground call inbox.
/// Preparing a route never captures media or accepts an incoming call.
class CallLaunchCoordinator {
  CallLaunchCoordinator(this.repository);
  final CallRepository repository;
  ({String peer, CallMedia media, String requestId})? _attempt;
  Future<PreparedCall>? _outgoing;
  Future<PreparedCall?>? _incoming;
  Future<void>? _abandoning;
  bool _closed = false;
  String? _callId;

  void _check() {
    if (_closed) throw StateError('Call launcher closed');
  }

  Future<PreparedCall> outgoing({
    required String peer,
    required CallMedia media,
  }) {
    _check();
    if (peer.isEmpty || peer == repository.messaging.account) {
      throw ArgumentError('Invalid call peer');
    }
    final pending = _attempt;
    if (pending != null && (pending.peer != peer || pending.media != media)) {
      throw StateError('Another call attempt is pending');
    }
    _attempt ??= (peer: peer, media: media, requestId: const Uuid().v4());
    return _outgoing ??= _prepareOutgoing().whenComplete(
      () => _outgoing = null,
    );
  }

  Future<PreparedCall> _prepareOutgoing() async {
    final attempt = _attempt!;
    final call = await repository.start(
      peer: attempt.peer,
      media: attempt.media,
      requestId: attempt.requestId,
    );
    _callId = call.id;
    _check();
    if (call.phase == CallPhase.ended) {
      _attempt = null;
      throw StateError('Call attempt already ended');
    }
    if (call.phase != CallPhase.ringing && call.phase != CallPhase.connecting) {
      throw StateError('Call was already accepted; cannot reopen capture');
    }
    final relay = await repository.readRelay(callId: call.id);
    _check();
    final current = await repository.read(callId: call.id);
    _check();
    if (current!.phase != CallPhase.ringing &&
        current.phase != CallPhase.connecting) {
      if (current.phase == CallPhase.ended) _attempt = null;
      throw StateError('Call state changed while preparing');
    }
    relay.requireUsable(current.id);
    return PreparedCall(current, relay, outgoingAttempt: true);
  }

  Future<PreparedCall?> incoming() {
    _check();
    return _incoming ??= _prepareIncoming().whenComplete(
      () => _incoming = null,
    );
  }

  Future<PreparedCall?> _prepareIncoming() async {
    final call = await repository.read();
    _check();
    if (call == null ||
        call.callee != repository.messaging.account ||
        call.phase != CallPhase.ringing) {
      return null;
    }
    final relay = await repository.readRelay(callId: call.id);
    _check();
    final current = await repository.read(callId: call.id);
    _check();
    if (current!.phase != CallPhase.ringing ||
        current.callee != repository.messaging.account) {
      return null;
    }
    relay.requireUsable(current.id);
    return PreparedCall(current, relay);
  }

  /// Clear only after the route has finished AND the server confirms terminal
  /// state. A network error must not turn a retry into a second dial request.
  Future<void> finishOutgoing(String callId) async {
    _check();
    if (callId != _callId) throw StateError('Wrong outgoing call');
    if (_outgoing != null) throw StateError('Call setup still running');
    final call = await repository.read(callId: callId);
    _check();
    if (call!.caller != repository.messaging.account ||
        call.phase != CallPhase.ended ||
        (_attempt != null &&
            (call.callee != _attempt!.peer || call.media != _attempt!.media))) {
      throw StateError('Outgoing call is not finished');
    }
    _attempt = null;
  }

  /// Close immediately, then cancel only this launcher's known outgoing call.
  /// Never redial to discover a lost start acknowledgement, or touch an
  /// unrelated current call. The bound repository rejects a changed login.
  Future<void> abandonOutgoing() {
    final pending = _outgoing;
    close();
    return _abandoning ??= _cancelAfterSetup(pending);
  }

  Future<void> _cancelAfterSetup(Future<PreparedCall>? pending) async {
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // Closing intentionally rejects setup; its validated start response
        // still records the exact call ID for cleanup.
      }
    }
    final id = _callId;
    if (id == null) return;
    for (var attempt = 0; attempt < 3; attempt++) {
      final call = await repository.read(callId: id);
      if (call == null || call.caller != repository.messaging.account) {
        throw StateError('Abandoned call identity mismatch');
      }
      if (call.phase == CallPhase.ended) return;
      try {
        final ended = await repository.act(
          call: call,
          action: call.phase == CallPhase.ringing
              ? CallAction.cancel
              : CallAction.hangup,
          requestId: const Uuid().v4(),
        );
        if (ended.phase != CallPhase.ended) {
          throw StateError('Abandoned call did not end');
        }
        return;
      } on AuthFailure catch (error) {
        // The recipient may accept between read and cancel. Only a definitive
        // version rejection permits a new action with a fresh request ID.
        if (error.code != 'CHAT_CALL_VERSION_CONFLICT' || attempt == 2) rethrow;
      }
    }
  }

  void close() {
    _closed = true;
    _attempt = null;
  }
}
