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
  int _cursor = 0;
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
    'generation': 0,
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
    return _syncing ??= _sync().whenComplete(() => _syncing = null);
  }

  Future<void> _sync() async {
    await start();
    await flush();
    _check();
    while (true) {
      final page = await repository.readSignals(
        callId: call.id,
        after: _cursor,
      );
      _check();
      // Resume/ICE restart needs a fresh native session and explicit ownership;
      // never apply a different generation to the original peer silently.
      if (page.generation != 0) {
        await close();
        throw StateError('Call renegotiation required');
      }
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

  Future<void> close() {
    _closed = true;
    _outgoing.clear();
    _earlyCandidates.clear();
    return _closing ??= media.close();
  }
}
