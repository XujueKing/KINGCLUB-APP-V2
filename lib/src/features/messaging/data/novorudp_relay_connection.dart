import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_secure_session.dart';

/// WSS carrier. Peer signatures, E2E decryption and durable receipts belong to
/// the peer channel; an authenticated relay is not a member trust authority.
class NovoRudpRelayConnection {
  NovoRudpRelayConnection({
    required this.identity,
    required this.endpoint,
    required this.expectedRelay,
    this.securityContext,
  }) {
    if (endpoint.scheme != 'wss' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        endpoint.path != '/novovm' ||
        !_peer.hasMatch(expectedRelay)) {
      throw ArgumentError('Invalid trusted relay endpoint');
    }
  }
  static final _peer = RegExp(r'^novovm-ed25519:[0-9a-f]{64}$');
  final NovoRudpSecureSession identity;
  final Uri endpoint;
  final String expectedRelay;
  final SecurityContext? securityContext;
  final int _generation = MemberQrMemory.generation;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messages.stream;
  HttpClient? _http;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _incoming;
  StreamSubscription<void>? _session;
  NovoRudpHandshake? _offer;
  Completer<void>? _ready;
  Timer? _deadline, _heartbeat;
  bool _closed = false, _authenticated = false, _heartbeatPending = false;

  void _check() {
    if (_closed || _generation != MemberQrMemory.generation) {
      close();
      throw StateError('Relay connection closed');
    }
  }

  /// Subscribe to [messages] before connecting so early deliveries are retained.
  Future<void> connect() {
    _check();
    if (!_messages.hasListener) {
      throw StateError('Relay receiver must subscribe first');
    }
    if (_ready != null) return _ready!.future;
    final ready = _ready = Completer<void>();
    _session = SecureSessionStore.changes.stream.listen((_) => close());
    _deadline = Timer(
      const Duration(seconds: 8),
      () => close(TimeoutException('Relay authentication timed out')),
    );
    unawaited(_open());
    return ready.future;
  }

  Future<void> _open() async {
    try {
      final http = _http = HttpClient(context: securityContext)
        ..connectionTimeout = const Duration(seconds: 5);
      final socket = await WebSocket.connect(
        endpoint.toString(),
        customClient: http,
        compression: CompressionOptions.compressionOff,
      );
      if (_closed || _generation != MemberQrMemory.generation) {
        unawaited(socket.close());
        close();
        return;
      }
      _socket = socket;
      _incoming = socket.listen(
        _receive,
        onError: (Object error) => close(error),
        onDone: close,
      );
      _offer = identity.start(expectedRelay);
      _write('handshake_offer', _offer!.offer);
    } catch (error) {
      close(error);
    }
  }

  void _receive(dynamic wire) {
    if (_closed) return;
    try {
      _check();
      if (wire is! List<int> || wire.length > 16384) {
        throw const FormatException('Invalid relay packet');
      }
      final value = jsonDecode(utf8.decode(wire));
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid relay message');
      }
      final kind = value['kind'];
      if (!_authenticated) {
        if (kind != 'handshake_response' ||
            value['body'] is! Map<String, dynamic>) {
          throw StateError('Relay authentication required');
        }
        final offer = _offer!;
        _offer = null;
        identity.complete(offer, value['body'] as Map<String, dynamic>).close();
        _authenticated = true;
        _deadline?.cancel();
        _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
          if (_heartbeatPending) {
            close(TimeoutException('Relay heartbeat missing'));
          } else {
            heartbeat();
          }
        });
        _ready!.complete();
        return;
      }
      if (kind == 'heartbeat_ack') {
        if (!_heartbeatPending) {
          throw StateError('Unexpected heartbeat response');
        }
        _heartbeatPending = false;
      } else if (kind == 'delivery' || kind == 'peer_handshake_delivery') {
        final body = value['body'];
        if (body is! Map<String, dynamic> ||
            body['target_peer_id'] != identity.peerId ||
            body['source_peer_id'] is! String ||
            !_peer.hasMatch(body['source_peer_id'] as String)) {
          throw StateError('Invalid relay delivery route');
        }
      } else if (kind != 'forward_outcome') {
        throw StateError('Unexpected relay message');
      }
      _messages.add(value);
    } catch (error) {
      close(error);
    }
  }

  void heartbeat() {
    _checkReady();
    if (_heartbeatPending) return;
    _heartbeatPending = true;
    _write('heartbeat');
  }

  void sendPeerHandshake(String target, Map<String, dynamic> handshake) {
    _checkReady();
    if (!_peer.hasMatch(target) ||
        target == identity.peerId ||
        !['offer', 'response'].contains(handshake['kind'])) {
      throw ArgumentError('Invalid relay peer handshake');
    }
    _write('peer_handshake', {
      'target_peer_id': target,
      'handshake': handshake,
    });
  }

  void sendEnvelope(Map<String, dynamic> envelope) {
    _checkReady();
    if (envelope['sender_peer_id'] != identity.peerId ||
        envelope['recipient_peer_id'] is! String ||
        !_peer.hasMatch(envelope['recipient_peer_id'] as String)) {
      throw ArgumentError('Invalid encrypted relay route');
    }
    _write('data', envelope);
  }

  void _checkReady() {
    _check();
    if (!_authenticated) throw StateError('Relay is not authenticated');
  }

  void _write(String kind, [Map<String, dynamic>? body]) {
    final bytes = utf8.encode(jsonEncode({'kind': kind, 'body': ?body}));
    if (bytes.length > 16384) {
      throw ArgumentError('Relay packet exceeds mobile limit');
    }
    _socket!.add(bytes);
  }

  void close([Object? error]) {
    if (_closed) return;
    _closed = true;
    _deadline?.cancel();
    _heartbeat?.cancel();
    if (_offer != null) {
      try {
        identity.cancel(_offer!);
      } on StateError {
        /* Already released. */
      }
      _offer = null;
    }
    if (_ready != null && !_ready!.isCompleted) {
      _ready!.completeError(error ?? StateError('Relay connection closed'));
    }
    unawaited(_incoming?.cancel());
    unawaited(_session?.cancel());
    unawaited(_socket?.close());
    _http?.close(force: true);
    // Stream completion informs consumers that their route must be replaced.
    unawaited(_messages.close());
  }
}
