import 'dart:async';
import 'dart:io';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_frame.dart';
import 'novorudp_secure_packet.dart';
import 'novorudp_secure_session.dart';

/// Owns a bound socket and an already authenticated channel. Endpoint discovery
/// and member-to-public-key trust must precede attachment. No chat route enables
/// this lane yet; delivery acknowledgement/repair and fallback are still needed.
class NovoRudpSecureDatagramLink {
  NovoRudpSecureDatagramLink.attach({
    required RawDatagramSocket socket,
    required this.peer,
    required this.peerPort,
    required this.channel,
  }) : _socket = socket {
    if (peerPort < 1 || peerPort > 65535 || socket.address.type != peer.type) {
      throw ArgumentError('Invalid secure UDP endpoint');
    }
    _socket.writeEventsEnabled = false;
    _session = SecureSessionStore.changes.stream.listen((_) => close());
    _events = _socket.listen(
      (event) {
        if (event == RawSocketEvent.read) unawaited(_read());
        if (event == RawSocketEvent.closed) unawaited(close());
      },
      onError: (Object error, StackTrace stack) {
        if (!_closed) _frames.addError(error, stack);
        unawaited(close());
      },
    );
  }

  final RawDatagramSocket _socket;
  final NovoRudpSecureChannel channel;
  final InternetAddress peer;
  final int peerPort;
  final int _generation = MemberQrMemory.generation;
  final _frames = StreamController<NovoRudpFrame>.broadcast();
  late final StreamSubscription<RawSocketEvent> _events;
  late final StreamSubscription<void> _session;
  bool _closed = false, _reading = false;
  Future<void>? _closing;
  Stream<NovoRudpFrame> get frames => _frames.stream;
  int get localPort => _socket.port;

  void _check() {
    if (_closed || _generation != MemberQrMemory.generation) {
      unawaited(close());
      throw StateError('Secure UDP lane closed');
    }
  }

  Future<void> send(NovoRudpFrame frame) async {
    _check();
    if (frame.payload.length > NovoRudpSecurePacket.maxFramePayload) {
      throw ArgumentError(
        'Object must be split before secure UDP transmission',
      );
    }
    final envelope = await channel.seal(frame);
    _check();
    final wire = NovoRudpSecurePacket.encode(envelope);
    if (_socket.send(wire, peer, peerPort) != wire.length) {
      throw const SocketException('UDP send buffer unavailable');
    }
  }

  Future<void> _read() async {
    if (_reading || _closed) return;
    _reading = true;
    _socket.readEventsEnabled = false;
    try {
      while (!_closed) {
        _check();
        final packet = _socket.receive();
        if (packet == null) break;
        if (packet.address.address != peer.address || packet.port != peerPort) {
          continue;
        }
        try {
          final frame = await channel.open(
            NovoRudpSecurePacket.decode(packet.data),
          );
          _check();
          _frames.add(frame);
        } on FormatException {
          // Invalid framing is never application data.
        } on StateError {
          // Native authentication, route binding and replay rejection are
          // fail-closed for this packet. A bad packet cannot kill a good lane.
          if (_generation != MemberQrMemory.generation) unawaited(close());
        }
      }
    } catch (error, stack) {
      if (!_closed) _frames.addError(error, stack);
      unawaited(close());
    } finally {
      _reading = false;
      if (!_closed) _socket.readEventsEnabled = true;
    }
  }

  Future<void> close() {
    _closed = true;
    return _closing ??= _close();
  }

  Future<void> _close() async {
    _socket.close();
    channel.close();
    await _events.cancel();
    await _session.cancel();
    await _frames.close();
  }
}
