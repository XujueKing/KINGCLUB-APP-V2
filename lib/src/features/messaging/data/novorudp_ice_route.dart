import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_route_diagnostics.dart';
import 'novorudp_frame.dart';
import 'novorudp_ice_signaling.dart';
import 'novorudp_secure_packet.dart';
import 'novorudp_secure_session.dart';

typedef NovoIcePeerFactory = Future<RTCPeerConnection> Function(
  Map<String, dynamic>,
);

/// Optional data-only ICE carrier. No microphone, camera, or call lifecycle.
/// SDP and frames retain the parent channel's authenticated peer binding.
/// STUN is used here; the existing SuperVM carrier provides relay fallback.
class NovoRudpIceRoute {
  NovoRudpIceRoute({
    required this.channel,
    required this.offerer,
    required this.sendControl,
    required this.deliver,
    required List<String> stunUrls,
    NovoIcePeerFactory? peerFactory,
  }) : _stunUrls = List.unmodifiable(stunUrls),
       _peerFactory = peerFactory ?? ((config) => createPeerConnection(config));

  static final controlStream = BigInt.from(0x4b434943);
  final NovoRudpSecureChannel channel;
  final bool offerer;
  final Future<void> Function(NovoRudpFrame) sendControl;
  final Future<void> Function(NovoRudpFrame, bool direct) deliver;
  final List<String> _stunUrls;
  final NovoIcePeerFactory _peerFactory;
  final _signaling = NovoRudpIceSignaling();
  final _clock = Stopwatch()..start();
  RTCPeerConnection? _peer;
  RTCDataChannel? _data;
  Timer? _timer;
  Timer? _candidateTimer;
  final _localCandidates = <Map<String, dynamic>>[];
  final _remoteCandidates = <String>{};
  bool _flushingCandidates = false;
  bool _published = false;
  int _candidateCount = 0;
  bool _closed = false, _busy = false, _remoteCapable = false;
  bool _connected = false, _direct = false, _remoteSet = false;
  int _epoch = 0, _attempt = 0, _queued = 0;
  Duration _started = Duration.zero, _retryAt = Duration.zero;
  Map<String, dynamic>? _description;
  Future<void> _operations = Future.value(), _receiving = Future.value();
  Future<void>? _closing;
  bool get ready =>
      !_closed &&
      _connected &&
      _data?.state == RTCDataChannelState.RTCDataChannelOpen;

  void start() {
    if (_closed || _timer != null) return;
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_tick()),
    );
    unawaited(_tick());
  }

  Future<void> _tick() async {
    if (_closed || _busy) return;
    _busy = true;
    try {
      await _flushCandidates();
      if (ready) {
        final peer = _peer;
        final reports = await peer!.getStats().timeout(
          const Duration(seconds: 1),
        );
        if (_closed || !identical(peer, _peer)) return;
        final routes = callRouteDiagnostics(reports);
        _direct = routes.any(
          (r) => r.startsWith('route=direct ') && r.contains('succeeded=true'),
        );
        if (!kReleaseMode) {
          for (final route in routes) {
            debugPrint('NOVORUDP_ICE $route');
          }
        }
        return;
      }
      if (_clock.elapsed < _retryAt) return;
      await _signal({'op': 'hello'});
      if (_peer != null &&
          _clock.elapsed - _started > const Duration(seconds: 20)) {
        await _reset();
        _retryAt = _clock.elapsed + const Duration(seconds: 30);
        return;
      }
      if (offerer && _remoteCapable && _peer == null) {
        await _enqueue(() => _offer());
      } else if (_description != null) {
        await _signal(_description!);
      }
    } catch (_) {
      // Optional discovery must not block or close the established carrier.
    } finally {
      _busy = false;
    }
  }

  Future<void> acceptControl(NovoRudpFrame frame) async {
    if (_closed ||
        frame.kind != NovoRudpFrameKind.endpoint ||
        frame.streamId != controlStream) {
      return;
    }
    try {
      final message = _signaling.accept(frame.payload);
      if (message == null) return;
      if (message['op'] == 'hello') {
        _remoteCapable = true;
        return;
      }
      if (message['op'] == 'candidates') {
        final attempt = message['attempt'], candidates = message['candidates'];
        if (attempt is! int ||
            candidates is! List ||
            candidates.length > 16 ||
            _pendingSignals >= 4) {
          return;
        }
        final parsed = <RTCIceCandidate>[];
        for (final item in candidates) {
          if (item is! Map ||
              item['candidate'] is! String ||
              (item['candidate'] as String).length > 2048 ||
              !(item['candidate'] as String).startsWith('candidate:') ||
              item['mid'] is! String ||
              (item['mid'] as String).length > 64 ||
              item['index'] != 0) {
            return;
          }
          parsed.add(RTCIceCandidate(item['candidate'], item['mid'], 0));
        }
        _pendingSignals++;
        unawaited(
          _enqueue(() async {
            final peer = _peer;
            if (peer == null || attempt != _attempt || !_remoteSet) return;
            for (final candidate in parsed) {
              if (!_current(peer) || _remoteCandidates.length >= 64) return;
              if (_remoteCandidates.add(candidate.candidate!)) {
                await peer.addCandidate(candidate);
              }
            }
          }).whenComplete(() => _pendingSignals--),
        );
        return;
      }
      final op = message['op'],
          attempt = message['attempt'],
          sdp = message['sdp'];
      if ((op != 'offer' && op != 'answer') ||
          attempt is! int ||
          attempt < 1 ||
          attempt > 0x7fffffff ||
          sdp is! String ||
          sdp.length > 30000 ||
          !sdp.startsWith('v=0') ||
          !sdp.contains('m=application ') ||
          sdp.contains('m=audio ') ||
          sdp.contains('m=video ')) {
        return;
      }
      // Serialize native SDP operations independently of relay receive delivery.
      // This method returns immediately so a large SDP cannot stall text ACKs.
      if (_pendingSignals >= 4) return;
      _pendingSignals++;
      unawaited(
        _enqueue(() async {
          if (_closed) return;
          if (op == 'offer' && !offerer) {
            if (attempt < _attempt || _clock.elapsed < _retryAt) return;
            if (attempt == _attempt) {
              if (_description != null) await _signal(_description!);
              return;
            }
            await _reset();
            _attempt = attempt;
            final peer = await _create();
            await peer.setRemoteDescription(
              RTCSessionDescription(sdp, 'offer'),
            );
            if (!_current(peer)) return;
            _remoteSet = true;
            await _local(peer, await peer.createAnswer(), 'answer');
          } else if (op == 'answer' &&
              offerer &&
              attempt == _attempt &&
              !_remoteSet) {
            final peer = _peer;
            if (peer == null) return;
            await peer.setRemoteDescription(
              RTCSessionDescription(sdp, 'answer'),
            );
            if (_current(peer)) _remoteSet = true;
          }
        }).whenComplete(() => _pendingSignals--),
      );
    } on FormatException {
      /* Authenticated malformed fragments are ignored. */
    }
  }

  int _pendingSignals = 0;

  Future<void> _enqueue(Future<void> Function() action) {
    return _operations = _operations.then((_) async {
      if (_closed) return;
      try {
        await action();
      } catch (_) {
        await _reset();
        _retryAt = _clock.elapsed + const Duration(seconds: 30);
      }
    });
  }

  Future<void> _offer() async {
    if (_closed || _peer != null || _clock.elapsed < _retryAt) return;
    _attempt++;
    final peer = await _create();
    await _local(peer, await peer.createOffer(), 'offer');
  }

  bool _current(RTCPeerConnection peer) => !_closed && identical(peer, _peer);

  Future<RTCPeerConnection> _create() async {
    final epoch = ++_epoch;
    final peer = await _peerFactory({
      'iceServers': [
        if (_stunUrls.isNotEmpty) {'urls': _stunUrls},
      ],
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': 'all',
    });
    if (_closed || epoch != _epoch) {
      await peer.close();
      await peer.dispose();
      throw StateError('ICE route expired');
    }
    _peer = peer;
    _started = _clock.elapsed;
    peer.onIceCandidate = (candidate) {
      if (!_current(peer) ||
          _candidateCount >= 64 ||
          candidate.candidate == null ||
          candidate.candidate!.isEmpty ||
          candidate.candidate!.length > 2048 ||
          candidate.sdpMLineIndex != 0 ||
          candidate.sdpMid == null) {
        return;
      }
      _candidateCount++;
      _localCandidates.add({
        'candidate': candidate.candidate,
        'mid': candidate.sdpMid,
        'index': 0,
      });
      _candidateTimer ??= Timer(const Duration(milliseconds: 50), () {
        _candidateTimer = null;
        unawaited(_flushCandidates());
      });
    };
    peer.onConnectionState = (state) {
      if (!_current(peer)) return;
      _connected =
          state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      if (!_connected) _direct = false;
    };
    final data = await peer.createDataChannel(
      'novorudp-v1',
      RTCDataChannelInit()
        ..negotiated = true
        ..id = 0
        ..ordered = true
        ..binaryType = 'binary',
    );
    if (!_current(peer)) {
      await data.close();
      throw StateError('ICE closed');
    }
    _data = data;
    data.onMessage = (message) {
      if (!_current(peer) ||
          !message.isBinary ||
          _queued >= 32 ||
          message.binary.length > NovoRudpSecurePacket.maxDatagramBytes) {
        return;
      }
      final bytes = message.binary.toList();
      final direct = _direct;
      _queued++;
      _receiving = _receiving
          .then((_) async {
            if (!_current(peer)) return;
            try {
              final envelope = NovoRudpSecurePacket.decode(
                Uint8List.fromList(bytes),
              );
              final frame = await channel.open(envelope);
              if (!_current(peer) || frame.streamId == controlStream) return;
              await deliver(frame, direct);
            } on FormatException {
              /* Invalid bytes never reach application. */
            } on StateError {
              /* Authentication/replay rejection. */
            }
          })
          .catchError((Object _) {})
          .whenComplete(() => _queued--);
    };
    return peer;
  }

  Future<void> _local(
    RTCPeerConnection peer,
    RTCSessionDescription description,
    String op,
  ) async {
    if (!_current(peer)) return;
    final gathered = Completer<void>();
    peer.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !gathered.isCompleted) {
        gathered.complete();
      }
    };
    await peer.setLocalDescription(description);
    if (!_current(peer)) return;
    if (peer.iceGatheringState !=
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      // Gather before sending SDP; no separate trickle candidates can arrive
      // before their description. Relay delivery remains available meanwhile.
      await gathered.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    }
    if (!_current(peer)) return;
    final local = await peer.getLocalDescription();
    if (!_current(peer) || local?.sdp == null) return;
    _description = {'op': op, 'attempt': _attempt, 'sdp': local!.sdp};
    await _signal(_description!);
    if (!_current(peer)) return;
    _published = true;
    await _flushCandidates();
  }

  Future<void> _flushCandidates() async {
    if (_closed || !_published || _flushingCandidates) return;
    _flushingCandidates = true;
    final epoch = _epoch;
    try {
      while (!_closed && epoch == _epoch && _localCandidates.isNotEmpty) {
        final batch = _localCandidates.take(16).toList();
        await _signal({
          'op': 'candidates',
          'attempt': _attempt,
          'candidates': batch,
        });
        if (epoch != _epoch) return;
        _localCandidates.removeRange(0, batch.length);
      }
    } catch (_) {
      /* Keep candidates for the next bounded retry. */
    } finally {
      _flushingCandidates = false;
    }
  }

  Future<void> _signal(Map<String, dynamic> value) async {
    for (final payload in NovoRudpIceSignaling.encode(value)) {
      if (_closed) return;
      await sendControl(
        NovoRudpFrame(
          kind: NovoRudpFrameKind.endpoint,
          sessionId: channel.sessionId,
          streamId: controlStream,
          objectId: BigInt.zero,
          sequence: BigInt.zero,
          ackEpoch: BigInt.zero,
          payload: payload,
        ),
      ).timeout(const Duration(seconds: 2));
      // Bound pressure on the encrypted relay receive queue.
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
  }

  Future<bool> trySend(NovoRudpFrame frame) async {
    final data = _data, epoch = _epoch;
    if (!ready || data == null) return false;
    try {
      if (await data.getBufferedAmount().timeout(
            const Duration(milliseconds: 250),
          ) >
          65536) {
        return false;
      }
      final envelope = await channel.seal(frame);
      if (!ready || epoch != _epoch) return false;
      await data
          .send(
            RTCDataChannelMessage.fromBinary(
              NovoRudpSecurePacket.encode(envelope),
            ),
          )
          .timeout(const Duration(milliseconds: 250));
      return !_closed && epoch == _epoch;
    } catch (_) {
      if (epoch == _epoch) reportDeliveryStall();
      return false;
    }
  }

  void reportDeliveryStall() {
    _connected = false;
    _retryAt = _clock.elapsed + const Duration(seconds: 30);
    unawaited(_reset());
  }

  Future<void> _reset() async {
    ++_epoch;
    _connected = false;
    _direct = false;
    _remoteSet = false;
    _description = null;
    _published = false;
    _candidateTimer?.cancel();
    _candidateTimer = null;
    _localCandidates.clear();
    _remoteCandidates.clear();
    _candidateCount = 0;
    final data = _data, peer = _peer;
    _data = null;
    _peer = null;
    if (data != null) {
      data.onMessage = null;
      try {
        await data.close();
      } catch (_) {}
    }
    if (peer != null) {
      peer.onConnectionState = null;
      peer.onIceGatheringState = null;
      peer.onIceCandidate = null;
      try {
        await peer.close();
      } catch (_) {}
      try {
        await peer.dispose();
      } catch (_) {}
    }
  }

  Future<void> close() {
    _closed = true;
    _timer?.cancel();
    _signaling.clear();
    return _closing ??= _reset();
  }
}
