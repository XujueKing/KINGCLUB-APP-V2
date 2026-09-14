import 'dart:async';
import 'dart:io';

import 'novorudp_frame.dart';

/// A single fixed-endpoint UDP lane, not a reliable or authenticated session.
/// Caller must provide identity/key negotiation, replay rules and repair logic
/// before this can carry real chat traffic. No production route uses it yet.
class NovoRudpDatagramLink {
  NovoRudpDatagramLink._(
    this._socket,
    this.peer,
    this.peerPort,
    List<int> session,
  ) : _session = List<int>.unmodifiable(session) {
    _events = _socket.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          unawaited(_read());
        } else if (event == RawSocketEvent.closed) {
          unawaited(close());
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!_closed) _frames.addError(error, stack);
        unawaited(close());
      },
    );
  }
  // Conservative lane budget. Large objects require framing/repair above this.
  static const maxDatagramBytes = 1200;
  static Future<NovoRudpDatagramLink> bind({
    required InternetAddress peer,
    required int peerPort,
    required List<int> sessionId,
    InternetAddress? localAddress,
    int localPort = 0,
  }) async {
    if (peerPort < 1 ||
        peerPort > 65535 ||
        localPort < 0 ||
        localPort > 65535 ||
        sessionId.length != 16 ||
        sessionId.any((v) => v < 0 || v > 255)) {
      throw ArgumentError('Invalid NovoRUDP endpoint or session');
    }
    final session = List<int>.of(sessionId);
    final socket = await RawDatagramSocket.bind(
      localAddress ??
          (peer.type == InternetAddressType.IPv6
              ? InternetAddress.anyIPv6
              : InternetAddress.anyIPv4),
      localPort,
    );
    socket.writeEventsEnabled = false;
    return NovoRudpDatagramLink._(socket, peer, peerPort, session);
  }

  final RawDatagramSocket _socket;
  final InternetAddress peer;
  final int peerPort;
  final List<int> _session;
  final _frames = StreamController<NovoRudpFrame>.broadcast();
  late final StreamSubscription<RawSocketEvent> _events;
  bool _closed = false, _reading = false;
  Future<void>? _closing;
  Stream<NovoRudpFrame> get frames => _frames.stream;
  int get localPort => _socket.port;
  bool _sameSession(List<int> value) {
    for (var i = 0; i < 16; i++) {
      if (_session[i] != value[i]) return false;
    }
    return true;
  }

  Future<void> send(NovoRudpFrame frame) async {
    if (_closed) throw StateError('NovoRUDP lane closed');
    if (!_sameSession(frame.sessionId)) {
      throw ArgumentError('Different session');
    }
    if (frame.payload.length + NovoRudpFrame.headerSize > maxDatagramBytes) {
      throw ArgumentError('Object must be split before UDP transmission');
    }
    final wire = await frame.encode();
    if (_closed) throw StateError('NovoRUDP lane closed');
    if (_socket.send(wire, peer, peerPort) != wire.length) {
      throw const SocketException('UDP send buffer unavailable');
    }
  }

  Future<void> _read() async {
    if (_reading || _closed) return;
    _reading = true;
    try {
      while (!_closed) {
        final packet = _socket.receive();
        if (packet == null) break;
        if (packet.address.address != peer.address ||
            packet.port != peerPort ||
            packet.data.length > maxDatagramBytes) {
          continue;
        }
        try {
          final frame = await NovoRudpFrame.decode(packet.data);
          if (!_closed && _sameSession(frame.sessionId)) _frames.add(frame);
        } on FormatException {
          // Bad datagrams do not terminate a lane or become application data.
        }
      }
    } catch (error, stack) {
      if (!_closed) _frames.addError(error, stack);
      unawaited(close());
    } finally {
      _reading = false;
    }
  }

  Future<void> close() {
    _closed = true;
    return _closing ??= _close();
  }

  Future<void> _close() async {
    _socket.close();
    await _events.cancel();
    await _frames.close();
  }
}
