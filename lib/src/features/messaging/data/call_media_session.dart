import '../../auth/domain/auth_repository.dart';

import 'dart:collection';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import 'call_repository.dart';
import 'native_call_media.dart';

typedef CallMediaFactory = NativeCallMedia Function(
  void Function(RTCIceCandidate) candidate,
);

/// Negotiates one accepted call. The owner supplies server-authorized state,
/// refreshes it on notifications, and closes this session on logout or hangup.
/// Transport failures leave immutable signals queued for an explicit retry.
class CallMediaSession {
  CallMediaSession({
    required this.repository,
    required this.call,
    required CallMediaFactory mediaFactory,
  }) {
    if (call.phase != CallPhase.connecting ||
        (call.caller != repository.messaging.account &&
            call.callee != repository.messaging.account)) {
      throw StateError('Media requires an accepted call');
    }
    media = mediaFactory(_candidate);
  }

  final CallRepository repository;
  final CallSnapshot call;
  late final NativeCallMedia media;
  final _outgoing = Queue<CallSignal>();
  final _earlyCandidates = <RTCIceCandidate>[];
  Future<void>? _starting, _flushing, _syncing, _closing;
  bool _closed = false, _localDescriptionQueued = false;
  bool _remoteDescriptionApplied = false;
  int _cursor = 0, _generation = 0;
  Future<void>? _restarting;
  int get generation => _generation;
  Object? _candidateFailure;
  bool get _caller => call.caller == repository.messaging.account;
  bool get isClosed => _closed;
  int get pendingSignals => _outgoing.length;

  void _check() {
    if (_closed) throw StateError('Call media session closed');
    if (_candidateFailure != null) throw _candidateFailure!;
  }

  CallSignal _signal(Map<String, dynamic> payload) => CallSignal({
    'callId': call.id,
    'clientSignalId': const Uuid().v4(),
    'generation': _generation,
    ...payload,
  });

  void _candidate(RTCIceCandidate candidate) {
    if (_closed || _candidateFailure != null) return;
    try {
      if (_outgoing.length + _earlyCandidates.length >= 256) {
        throw StateError('Too many outgoing call signals');
      }
      if (!_localDescriptionQueued) {
        _earlyCandidates.add(candidate);
      } else {
        _queueCandidate(candidate);
      }
    } catch (error) {
      // Native callbacks must not leak asynchronous exceptions into the engine.
      _candidateFailure = error;
    }
  }

  void _queueCandidate(RTCIceCandidate candidate) {
    _outgoing.add(
      _signal({
        'kind': 'ice',
        'candidate': candidate.candidate ?? '',
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }),
    );
  }

  void _queueDescription(RTCSessionDescription description, String kind) {
    _outgoing.add(_signal({'kind': kind, 'sdp': description.sdp}));
    _localDescriptionQueued = true;
    for (final candidate in _earlyCandidates) {
      _queueCandidate(candidate);
    }
    _earlyCandidates.clear();
  }

  Future<void> start() {
    _check();
    return _starting ??= _start();
  }

  Future<void> _start() async {
    try {
      await media.open();
      _check();
      if (_caller) {
        final description = await media.offer();
        _check();
        _queueDescription(description, 'offer');
      }
    } catch (_) {
      _closed = true;
      await media.close();
      rethrow;
    }
  }

  Future<void> flush() {
    _check();
    if (_restarting != null) {
      return Future.error(StateError('ICE restart in progress'));
    }
    return _flushing ??= _flush().whenComplete(() => _flushing = null);
  }

  Future<void> _flush() async {
    await start();
    _check();
    while (_outgoing.isNotEmpty) {
      final next = _outgoing.first;
      await repository.sendSignal(next);
      _check();
      _outgoing.removeFirst();
    }
  }

  Future<void> sync() {
    _check();
    if (_restarting != null) {
      return Future.error(StateError('ICE restart in progress'));
    }
    return _syncing ??= _sync().whenComplete(() => _syncing = null);
  }

  Future<void> _sync() async {
    await start();
    AuthFailure? oldGenerationConflict;
    try {
      await flush();
    } on AuthFailure catch (error) {
      if (_caller || error.code != 'CHAT_CALL_NEGOTIATION_CONFLICT') rethrow;
      oldGenerationConflict = error;
    }
    _check();
    while (true) {
      final page = await repository.readSignals(
        callId: call.id,
        after: _cursor,
      );
      _check();
      if (page.generation != _generation) {
        if (_caller ||
            page.generation != _generation + 1 ||
            !_remoteDescriptionApplied ||
            page.items.isEmpty ||
            page.items.first.signal.data['kind'] != 'offer') {
          await close();
          throw StateError('Unexpected call negotiation generation');
        }
        final relay = await repository.readRelay(callId: call.id);
        _check();
        try {
          await media.prepareRemoteRestart(callId: call.id, relay: relay);
        } catch (_) {
          await close();
          rethrow;
        }
        _check();
        _beginGeneration(page.generation);
      } else if (oldGenerationConflict != null) {
        throw oldGenerationConflict;
      }
      oldGenerationConflict = null;
      for (final item in page.items) {
        final data = item.signal.data, kind = data['kind'];
        try {
          if (kind == 'ice') {
            await media.remoteCandidate(
              RTCIceCandidate(
                data['candidate'] as String,
                data['sdpMid'] as String?,
                data['sdpMLineIndex'] as int?,
              ),
            );
          } else {
            if (_remoteDescriptionApplied ||
                kind != (_caller ? 'answer' : 'offer')) {
              throw StateError('Unexpected remote session description');
            }
            await media.remoteDescription(
              RTCSessionDescription(data['sdp'] as String, kind as String),
            );
            _check();
            if (!_caller) {
              final answer = await media.answer();
              _check();
              _queueDescription(answer, 'answer');
            }
            _remoteDescriptionApplied = true;
          }
          _check();
          _cursor = item.sequence;
        } catch (_) {
          // Native partial application is not safely replayable. End local
          // capture instead of pretending its negotiation state is intact.
          await close();
          rethrow;
        }
      }
      await flush();
      if (!page.hasMore) return;
    }
  }

  void _beginGeneration(int generation) {
    _generation = generation;
    _outgoing.clear();
    _earlyCandidates.clear();
    _localDescriptionQueued = false;
    _remoteDescriptionApplied = false;
  }

  Future<void> restart() {
    _check();
    if (_restarting != null) return _restarting!;
    if (!_caller ||
        !_remoteDescriptionApplied ||
        _generation >= 65535 ||
        _syncing != null ||
        _flushing != null) {
      return Future.error(StateError('Cannot restart this negotiation'));
    }
    return _restarting = _restart().whenComplete(() => _restarting = null);
  }

  Future<void> _restart() async {
    final current = await repository.read(callId: call.id);
    _check();
    if (current?.phase != CallPhase.active) {
      throw StateError('Call is not active');
    }
    final relay = await repository.readRelay(callId: call.id);
    _check();
    await _flush();
    _check();
    _beginGeneration(_generation + 1);
    try {
      final description = await media.restartOffer(
        callId: call.id,
        relay: relay,
      );
      _check();
      _queueDescription(description, 'offer');
    } catch (_) {
      await close();
      rethrow;
    }
    // Transport failure retains exactly this offer and its ID. The next sync
    // flushes it; it must never generate another restart offer to retry an ACK.
    await _flush();
  }

  Future<void> close() {
    _closed = true;
    _outgoing.clear();
    _earlyCandidates.clear();
    return _closing ??= media.close();
  }
}
