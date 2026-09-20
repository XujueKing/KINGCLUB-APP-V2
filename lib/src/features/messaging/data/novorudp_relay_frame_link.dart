import 'dart:async';
import 'dart:math';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_frame.dart';
import 'novorudp_frame_link.dart';
import 'novorudp_relay_connection.dart';
import 'novorudp_secure_packet.dart';
import 'novorudp_secure_session.dart';
import 'novorudp_lan_route.dart';

typedef NovoRudpLanRouteFactory = Future<NovoRudpLanRoute?> Function({
  required NovoRudpSecureChannel channel,
  required Future<void> Function(NovoRudpFrame) sendControl,
  required Future<void> Function(NovoRudpFrame) deliver,
});

/// Owns one authenticated peer channel, not the shared relay connection.
/// Relay acceptance never substitutes for the upper layer's durable receipt.
class NovoRudpRelayFrameLink
    implements
        NovoRudpFrameLink,
        NovoRudpRouteRecovery,
        NovoRudpRouteObservations {
  NovoRudpRelayFrameLink({
    required this.relay,
    required this.channel,
    required this.expectedPeer,
    this.authorize,
    this.openLanRoute = NovoRudpLanRoute.open,
    bool enableLan = const bool.fromEnvironment('KINGCLUB_NOVORUDP_LAN'),
  }) : _localPeer = relay.identity.peerId {
    if (!RegExp(r'^novovm-ed25519:[0-9a-f]{64}$').hasMatch(expectedPeer) ||
        expectedPeer == _localPeer) {
      throw ArgumentError('Invalid peer');
    }
    _incoming = relay.messages.listen(
      (message) {
        if (_closed || message['kind'] != 'delivery' || _queued >= 32) return;
        final body = message['body'];
        if (body is! Map ||
            body['source_peer_id'] != expectedPeer ||
            body['target_peer_id'] != _localPeer ||
            body['envelope'] is! Map<String, dynamic>) {
          return;
        }
        final envelope = body['envelope'] as Map<String, dynamic>;
        _queued++;
        _tail = _tail
            .then((_) async {
              if (_closed) return;
              try {
                _check();
                final frame = await channel.open(envelope);
                await _authorization;
                _check();
                if (frame.payload.length <=
                    NovoRudpSecurePacket.maxFramePayload) {
                  if (frame.streamId == _livenessStream) {
                    if (frame.payload.length == 1 &&
                        frame.payload.single == 0) {
                      await send(_livenessFrame(frame.objectId, 1));
                    } else if (frame.payload.length == 1 &&
                        frame.payload.single == 1 &&
                        frame.objectId == _probeId) {
                      if (!(_probeReply?.isCompleted ?? true)) {
                        _probeReply!.complete();
                      }
                    }
                  } else if (frame.streamId == NovoRudpLanRoute.controlStream) {
                    await _lan?.acceptControl(frame);
                  } else {
                    _recordRoute(frame, false);
                    _frames.add(frame);
                  }
                }
              } on StateError {
                // Bad authentication/replays are discarded, never delivered.
              } on FormatException {
                // A malformed packet cannot terminate a valid peer lane.
              }
            })
            .catchError((Object _) {
              unawaited(close());
            })
            .whenComplete(() {
              _queued--;
            });
      },
      onDone: () => unawaited(close()),
      onError: (Object _) => unawaited(close()),
    );
    _session = SecureSessionStore.changes.stream.listen(
      (_) => unawaited(close()),
    );
    if (enableLan || NovoRudpLanRoute.stunHost.isNotEmpty) {
      unawaited(_openLan());
    }
    if (authorize != null) {
      _authorizationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        unawaited(Future<void>.sync(revalidate).catchError((Object _) {}));
      });
    }
  }
  final NovoRudpRelayConnection relay;
  final String _localPeer;
  final String expectedPeer;
  final Future<void> Function()? authorize;
  final NovoRudpLanRouteFactory openLanRoute;
  NovoRudpLanRoute? _lan;
  bool get directLanReady => _lan?.ready ?? false;

  static final _livenessStream = BigInt.from(0x4b434c56);
  Future<void>? _probe;
  Completer<void>? _probeReply;
  BigInt? _probeId;

  NovoRudpFrame _livenessFrame(BigInt id, int operation) => NovoRudpFrame(
    kind: NovoRudpFrameKind.endpoint,
    sessionId: channel.sessionId,
    streamId: _livenessStream,
    objectId: id,
    sequence: BigInt.zero,
    ackEpoch: BigInt.zero,
    payload: [operation],
  );

  /// Authority alone cannot prove the other process still owns this session.
  /// Probe over relay so an obsolete UDP mapping cannot hide a live session.
  Future<void> ensureRemoteSession() => _probe ??= _probeRemoteSession();

  Future<void> _probeRemoteSession() async {
    final random = Random.secure();
    final id =
        (BigInt.from(random.nextInt(1 << 30)) << 30) |
        BigInt.from(random.nextInt(1 << 30));
    final reply = Completer<void>();
    _probeId = id;
    _probeReply = reply;
    try {
      await (() async {
        await send(_livenessFrame(id, 0));
        await reply.future;
      })().timeout(const Duration(milliseconds: 900));
    } finally {
      _probeReply = null;
      _probeId = null;
      _probe = null;
    }
  }

  @override
  void reportDeliveryStall() {
    if (!_closed) _lan?.reprobeAfterStall();
  }

  Future<void> _openLan() async {
    try {
      final route = await openLanRoute(
        channel: channel,
        sendControl: send,
        deliver: (frame) async {
          await _authorization;
          _check();
          _recordRoute(frame, true);
          _frames.add(frame);
        },
      );
      if (_closed) {
        await route?.close();
        return;
      }
      _lan = route;
      // The parent relay may still be connecting; periodic offers retry it.
      try {
        await route?.advertise();
      } catch (_) {}
    } catch (_) {
      await _lan?.close();
      _lan = null;
    }
  }

  Timer? _authorizationTimer;
  Future<void>? _authorization;
  @override
  final NovoRudpSecureChannel channel;
  final _frames = StreamController<NovoRudpFrame>.broadcast();
  final _routes = StreamController<NovoRudpReceivedRoute>.broadcast();
  @override
  Stream<NovoRudpReceivedRoute> get receivedRoutes => _routes.stream;

  void _recordRoute(NovoRudpFrame frame, bool direct) {
    if (!_routes.hasListener) return;
    _routes.add((
      streamId: frame.streamId,
      objectId: frame.objectId,
      kind: frame.kind,
      bytes: frame.payload.length,
      direct: direct,
    ));
  }

  final _generation = MemberQrMemory.generation;
  late final StreamSubscription<Map<String, dynamic>> _incoming;
  late final StreamSubscription<void> _session;
  Future<void> _tail = Future.value();
  Future<void>? _closing;
  bool _closed = false;
  int _queued = 0;
  @override
  Stream<NovoRudpFrame> get frames => _frames.stream;

  /// Also called by the owner when a relationship/device event arrives.
  /// Failed/unavailable authority closes the lane; durable messages remain
  /// available to the transport owner's recovery policy.
  Future<void> revalidate() {
    _check();
    return _authorization ??= _revalidate();
  }

  Future<void> _revalidate() async {
    try {
      await authorize?.call().timeout(const Duration(seconds: 5));
      _check();
    } catch (_) {
      unawaited(close());
      rethrow;
    } finally {
      _authorization = null;
    }
  }

  void _check() {
    if (_closed || _generation != MemberQrMemory.generation) {
      unawaited(close());
      throw StateError('Relay peer lane closed');
    }
  }

  @override
  Future<void> send(NovoRudpFrame frame) async {
    await _authorization;
    _check();
    if (frame.payload.length > NovoRudpSecurePacket.maxFramePayload) {
      throw ArgumentError('Split payload before relay transmission');
    }
    if (frame.streamId != NovoRudpLanRoute.controlStream &&
        frame.streamId != _livenessStream &&
        await _lan?.trySend(frame) == true) {
      return;
    }
    _check();
    final envelope = await channel.seal(frame);
    await _authorization;
    _check();
    if (envelope['recipient_peer_id'] != expectedPeer) {
      throw StateError('Peer channel does not match route');
    }
    relay.sendEnvelope(envelope);
  }

  @override
  Future<void> close() {
    _closed = true;
    _authorizationTimer?.cancel();
    return _closing ??= _close();
  }

  Future<void> _close() async {
    await _lan?.close();
    channel.close();
    await _incoming.cancel();
    await _session.cancel();
    await _routes.close();
    await _frames.close();
  }
}
