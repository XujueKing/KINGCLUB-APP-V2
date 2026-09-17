import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'novorudp_frame.dart';
import 'novorudp_secure_packet.dart';
import 'novorudp_secure_session.dart';

/// An optional local-network carriage for an already authenticated channel.
/// Addresses arrive only through that channel; they never establish identity.
class NovoRudpLanRoute {
  static final controlStream = BigInt.from(0x4b434c4e);
  static bool _private(InternetAddress ip) {
    if (ip.type != InternetAddressType.IPv4) return false;
    final b = ip.rawAddress;
    return b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168);
  }

  static Future<List<String>> _localAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    final values =
        interfaces
            .expand((i) => i.addresses)
            .where(_private)
            .map((a) => a.address)
            .toSet()
            .toList()
          ..sort();
    return values.take(4).toList();
  }

  static Future<NovoRudpLanRoute?> open({
    required NovoRudpSecureChannel channel,
    required Future<void> Function(NovoRudpFrame) sendControl,
    required Future<void> Function(NovoRudpFrame) deliver,
  }) async {
    final addresses = await _localAddresses();
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    return NovoRudpLanRoute._(socket, channel, addresses, sendControl, deliver);
  }

  NovoRudpLanRoute._(
    this._socket,
    this.channel,
    this.addresses,
    this.sendControl,
    this.deliver,
  ) {
    _socket.writeEventsEnabled = false;
    _events = _socket.listen(
      (event) {
        if (event == RawSocketEvent.read) unawaited(_read());
        if (event == RawSocketEvent.closed) unawaited(close());
      },
      onError: (Object _) => unawaited(close()),
      onDone: () => unawaited(close()),
    );
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_tick()),
    );
  }

  final RawDatagramSocket _socket;
  final NovoRudpSecureChannel channel;
  final List<String> addresses;
  final Future<void> Function(NovoRudpFrame) sendControl, deliver;
  late final StreamSubscription<RawSocketEvent> _events;
  late final Timer _timer;
  InternetAddress? _peer;
  List<InternetAddress> _candidates = [];
  int? _port;
  Stopwatch? _confirmed;
  bool _closed = false, _reading = false, _ticking = false;
  int _advertisements = 0;
  int _endpointEpoch = 0;
  Future<void>? _closing;

  bool get ready =>
      !_closed &&
      _confirmed != null &&
      _confirmed!.elapsed < const Duration(seconds: 6);

  NovoRudpFrame _control(Map<String, dynamic> body) => NovoRudpFrame(
    kind: NovoRudpFrameKind.data,
    sessionId: channel.sessionId,
    streamId: controlStream,
    objectId: BigInt.zero,
    sequence: BigInt.zero,
    ackEpoch: BigInt.zero,
    payload: utf8.encode(jsonEncode(body)),
  );

  Future<void> advertise() async {
    if (_closed) return;
    await sendControl(
      _control({
        'op': 'endpoint',
        'addresses': addresses,
        'port': _socket.port,
      }),
    );
  }

  /// Called only for frames authenticated by the parent member channel.
  Future<void> acceptControl(
    NovoRudpFrame frame, {
    bool datagram = false,
    InternetAddress? source,
  }) async {
    if (_closed ||
        frame.streamId != controlStream ||
        frame.payload.length > 512) {
      return;
    }
    try {
      final body = jsonDecode(utf8.decode(frame.payload));
      if (body is! Map) return;
      if (!datagram && body['op'] == 'endpoint') {
        final raw = body['addresses'], port = body['port'];
        if (raw is! List ||
            raw.length > 4 ||
            port is! int ||
            port < 1 ||
            port > 65535) {
          return;
        }
        final candidates = <InternetAddress>[];
        for (final value in raw) {
          if (value is! String) continue;
          final ip = InternetAddress.tryParse(value);
          if (ip == null || !_private(ip)) continue;
          // Conservative same-/24 candidate only. Other subnet layouts keep relay.
          final prefix = value.substring(0, value.lastIndexOf('.'));
          if (!addresses.any(
            (a) => a.substring(0, a.lastIndexOf('.')) == prefix,
          )) {
            continue;
          }
          if (!candidates.any((a) => a.address == ip.address)) {
            candidates.add(ip);
          }
        }
        final unchanged =
            port == _port &&
            candidates.map((a) => a.address).join(',') ==
                _candidates.map((a) => a.address).join(',');
        if (!unchanged) {
          _endpointEpoch++;
          _confirmed = null;
          _peer = null;
          _candidates = candidates;
          _port = candidates.isEmpty ? null : port;
        }
        await _probe();
      } else if (datagram && source != null && body['op'] == 'ping') {
        await _send(_control({'op': 'pong'}), target: source);
      } else if (datagram && source != null && body['op'] == 'pong') {
        if (ready && _peer?.address != source.address) return;
        _peer = source;
        _confirmed = Stopwatch()..start();
      }
    } on FormatException {
      /* Unrecognized controls are not app data. */
    }
  }

  Future<void> _tick() async {
    if (_closed || _ticking) return;
    _ticking = true;
    try {
      final tick = _advertisements++;
      if (tick % 15 == 0) {
        final current = await _localAddresses();
        if (_closed) return;
        if (jsonEncode(current) != jsonEncode(addresses)) {
          _endpointEpoch++;
          addresses
            ..clear()
            ..addAll(current);
          _peer = null;
          _candidates = [];
          _port = null;
          _confirmed = null;
        }
      }
      // Refresh after joining/changing Wi-Fi, including routes opened on cellular.
      if (tick < 4 || tick % 15 == 0) await advertise();
      await _probe();
    } catch (_) {
      _confirmed = null;
    } finally {
      _ticking = false;
    }
  }

  Future<void> _probe() async {
    final candidates = ready ? [_peer!] : List.of(_candidates);
    for (final candidate in candidates) {
      try {
        await _send(_control({'op': 'ping'}), target: candidate);
      } on SocketException {
        // One unavailable interface must not prevent probing the others.
      }
    }
  }

  Future<void> _send(NovoRudpFrame frame, {InternetAddress? target}) async {
    final destination = target ?? _peer;
    if (_closed || destination == null || _port == null) {
      throw StateError('LAN route unavailable');
    }
    final epoch = _endpointEpoch;
    final wire = NovoRudpSecurePacket.encode(await channel.seal(frame));
    if (_closed ||
        epoch != _endpointEpoch ||
        _socket.send(wire, destination, _port!) != wire.length) {
      throw const SocketException('LAN send unavailable');
    }
  }

  Future<bool> trySend(NovoRudpFrame frame) async {
    if (!ready) return false;
    try {
      await _send(frame);
      return true;
    } catch (_) {
      _confirmed = null;
      return false;
    }
  }

  Future<void> _read() async {
    if (_closed || _reading) return;
    _reading = true;
    _socket.readEventsEnabled = false;
    try {
      for (var i = 0; i < 64 && !_closed; i++) {
        final packet = _socket.receive();
        if (packet == null) break;
        if (!_candidates.any((a) => a.address == packet.address.address) ||
            packet.port != _port) {
          continue;
        }
        try {
          final epoch = _endpointEpoch;
          final frame = await channel.open(
            NovoRudpSecurePacket.decode(packet.data),
          );
          if (_closed) return;
          if (epoch != _endpointEpoch) continue;
          if (frame.streamId == controlStream) {
            await acceptControl(frame, datagram: true, source: packet.address);
          } else if (ready) {
            // Both peers may select different advertised interfaces on a
            // multi-homed host. Source candidate/port, endpoint epoch and AEAD
            // were already verified above; requiring our chosen outbound IP
            // here drops valid traffic from the peer's other signed candidate.
            await deliver(frame);
          }
        } on FormatException {
          /* Ignore invalid packets. */
        } on StateError {
          /* Ignore unauthenticated or replayed packets. */
        }
      }
    } catch (_) {
      _confirmed = null;
    } finally {
      _reading = false;
      if (!_closed) _socket.readEventsEnabled = true;
    }
  }

  Future<void> close() {
    _closed = true;
    _timer.cancel();
    _socket.close();
    return _closing ??= _events.cancel();
  }
}
