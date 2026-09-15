import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_secure_datagram_link.dart';
import 'novorudp_secure_session.dart';

/// Explicitly authorized peer only. Keeps the bound UDP port through handoff.
/// Does not establish member authorization or decide whether to trust an observer.
class NovoRudpNatSocket {
  NovoRudpNatSocket.attach({
    required RawDatagramSocket socket,
    required this.identity,
    required this.expectedPeer,
  }) : _socket = socket {
    _socket.writeEventsEnabled = false;
    _events = socket.listen(
      _event,
      onError: (Object error) => close(),
      onDone: close,
    );
    _session = SecureSessionStore.changes.stream.listen((_) => close());
  }
  final RawDatagramSocket _socket;
  final NovoRudpSecureSession identity;
  final String expectedPeer;
  final int _generation = MemberQrMemory.generation;
  late final StreamSubscription<RawSocketEvent> _events;
  late final StreamSubscription<void> _session;
  Completer<String>? _pending;
  NovoRudpNatProbe? _probe;
  InternetAddress? _target, _verified;
  int? _targetPort, _verifiedPort;
  Timer? _retry, _deadline;
  bool _closed = false, _transferred = false;
  int get localPort => _socket.port;

  void _check() {
    if (_closed || _transferred || _generation != MemberQrMemory.generation) {
      throw StateError('NAT socket unavailable');
    }
  }

  Future<String> probe(InternetAddress address, int port, {bool punch = true}) {
    _check();
    if (_pending != null) throw StateError('NAT probe already pending');
    if (address.type != _socket.address.type || port < 1 || port > 65535) {
      throw ArgumentError('Invalid NAT destination');
    }
    if (punch) {
      _verified = null;
      _verifiedPort = null;
    }
    final request = identity.natProbe(targetPeer: punch ? expectedPeer : null);
    final bytes = utf8.encode(jsonEncode(request.packet));
    final result = Completer<String>();
    _pending = result;
    _probe = request;
    _target = address;
    _targetPort = port;
    void send() {
      if (_closed || _transferred) return;
      try {
        _socket.send(bytes, address, port);
      } on SocketException {
        _finish(error: const SocketException('NAT probe send failed'));
      }
    }

    _deadline = Timer(
      const Duration(seconds: 8),
      () => _finish(error: TimeoutException('NAT probe timed out')),
    );
    _retry = Timer.periodic(const Duration(milliseconds: 250), (_) => send());
    send();
    return result.future.then((endpoint) {
      _check();
      if (punch) {
        _verified = address;
        _verifiedPort = port;
      }
      return endpoint;
    });
  }

  void _event(RawSocketEvent event) {
    if (_closed || _transferred) return;
    if (event == RawSocketEvent.closed) {
      close();
      return;
    }
    if (event != RawSocketEvent.read) return;
    // Bound work per event; malformed traffic never becomes application data.
    for (var n = 0; n < 32; n++) {
      final packet = _socket.receive();
      if (packet == null) break;
      if (packet.data.length > 4096) continue;
      try {
        _check();
        final value = jsonDecode(utf8.decode(packet.data));
        if (value is! Map<String, dynamic>) continue;
        final kind = value['kind'];
        if (kind == 'observed_probe' || kind == 'punch_request') {
          final host = packet.address.type == InternetAddressType.IPv6
              ? '[${packet.address.address}]'
              : packet.address.address;
          final ack = identity.respondNat(
            value,
            expectedPeer: expectedPeer,
            observedEndpoint: '$host:${packet.port}',
          );
          _socket.send(
            utf8.encode(jsonEncode(ack)),
            packet.address,
            packet.port,
          );
        } else if (_pending != null &&
            packet.address.address == _target?.address &&
            packet.port == _targetPort) {
          final endpoint = identity.validateNat(
            _probe!,
            value,
            expectedPeer: expectedPeer,
          );
          _finish(endpoint: endpoint);
        }
      } on FormatException {
        continue;
      } on StateError {
        continue;
      } on SocketException {
        continue;
      }
    }
  }

  void _finish({String? endpoint, Object? error}) {
    final pending = _pending;
    _pending = null;
    _probe = null;
    _retry?.cancel();
    _deadline?.cancel();
    if (pending == null) return;
    if (error != null) {
      pending.completeError(error);
    } else {
      pending.complete(endpoint!);
    }
  }

  NovoRudpSecureDatagramLink handoff(NovoRudpSecureChannel channel) {
    _check();
    if (_pending != null || _verified == null) {
      throw StateError('Peer punch not verified');
    }
    final link = NovoRudpSecureDatagramLink.attach(
      socket: _socket,
      peer: _verified!,
      peerPort: _verifiedPort!,
      channel: channel,
      existingEvents: _events,
      onControlPacket: _respondControl,
    );
    _transferred = true;
    unawaited(_session.cancel());
    return link;
  }

  void _respondControl(Datagram packet) {
    try {
      final value = jsonDecode(utf8.decode(packet.data));
      if (value is! Map<String, dynamic>) return;
      if (value['kind'] != 'punch_request') return;
      final host = packet.address.type == InternetAddressType.IPv6
          ? '[${packet.address.address}]'
          : packet.address.address;
      final ack = identity.respondNat(
        value,
        expectedPeer: expectedPeer,
        observedEndpoint: '$host:${packet.port}',
      );
      _socket.send(utf8.encode(jsonEncode(ack)), packet.address, packet.port);
    } on FormatException {
      return;
    } on StateError {
      return;
    } on SocketException {
      return;
    }
  }

  void close() {
    if (_closed || _transferred) return;
    _closed = true;
    _finish(error: StateError('NAT socket closed'));
    _socket.close();
    unawaited(_events.cancel());
    unawaited(_session.cancel());
  }
}
