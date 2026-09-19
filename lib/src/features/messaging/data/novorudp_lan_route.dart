import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'novorudp_frame.dart';
import 'novorudp_secure_packet.dart';
import 'novorudp_secure_session.dart';
import 'novorudp_stun_binding.dart';
import 'novorudp_route_probe.dart';

typedef _Endpoint = ({InternetAddress address, int port});

/// An optional local-network carriage for an already authenticated channel.
/// Addresses arrive only through that channel; they never establish identity.
class NovoRudpLanRoute {
  static const stunHost = String.fromEnvironment('KINGCLUB_NOVORUDP_STUN_HOST');
  static const stunPort = int.fromEnvironment(
    'KINGCLUB_NOVORUDP_STUN_PORT',
    defaultValue: 3478,
  );
  static bool _public(InternetAddress ip) {
    if (ip.type != InternetAddressType.IPv4 || _private(ip)) return false;
    final b = ip.rawAddress;
    return b[0] != 0 &&
        b[0] != 127 &&
        b[0] < 224 &&
        !(b[0] == 169 && b[1] == 254) &&
        !(b[0] == 100 && b[1] >= 64 && b[1] <= 127);
  }

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
    String observerHost = stunHost,
    int observerPort = stunPort,
  }) async {
    final addresses = await _localAddresses();
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    return NovoRudpLanRoute._(
      socket,
      channel,
      addresses,
      sendControl,
      deliver,
      observerHost,
      observerPort,
    );
  }

  NovoRudpLanRoute._(
    this._socket,
    this.channel,
    this.addresses,
    this.sendControl,
    this.deliver,
    this.observerHost,
    this.observerPort,
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
    unawaited(_discover());
  }

  final RawDatagramSocket _socket;
  final NovoRudpSecureChannel channel;
  final List<String> addresses;
  final Future<void> Function(NovoRudpFrame) sendControl, deliver;
  late final StreamSubscription<RawSocketEvent> _events;
  late final Timer _timer;
  _Endpoint? _peer, _mapped;
  List<_Endpoint> _candidates = [];
  final String observerHost;
  final int observerPort;
  InternetAddress? _observer;
  NovoRudpStunBinding? _binding;
  Stopwatch? _bindingAge, _mappedAge;
  bool _discovering = false;
  Stopwatch? _confirmed;
  bool _closed = false, _reading = false, _ticking = false;
  int _advertisements = 0;
  int _endpointEpoch = 0;
  final _probes = NovoRudpRouteProbe();
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
        if (_mapped != null)
          'public': {
            'address': _mapped!.address.address,
            'port': _mapped!.port,
          },
      }),
    );
  }

  /// Called only for frames authenticated by the parent member channel.
  Future<void> acceptControl(
    NovoRudpFrame frame, {
    bool datagram = false,
    InternetAddress? source,
    int? sourcePort,
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
        final candidates = <_Endpoint>[];
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
          if (!candidates.any((a) => a.address.address == ip.address)) {
            candidates.add((address: ip, port: port));
          }
        }
        final external = body['public'];
        if (observerHost.isNotEmpty && external is Map) {
          final host = external['address'], mappedPort = external['port'];
          final ip = host is String ? InternetAddress.tryParse(host) : null;
          if (ip != null &&
              _public(ip) &&
              mappedPort is int &&
              mappedPort > 0 &&
              mappedPort <= 65535) {
            candidates.add((address: ip, port: mappedPort));
          }
        }
        final unchanged =
            candidates.map((a) => '${a.address.address}:${a.port}').join(',') ==
            _candidates.map((a) => '${a.address.address}:${a.port}').join(',');
        if (!unchanged) {
          _endpointEpoch++;
          _probes.clear();
          _confirmed = null;
          _peer = null;
          _candidates = candidates;
        }
        await _probe();
      } else if (datagram &&
          source != null &&
          sourcePort != null &&
          body['op'] == 'ping') {
        if (!NovoRudpRouteProbe.validNonce(body['nonce'])) return;
        await _send(
          _control({'op': 'pong', 'nonce': body['nonce']}),
          target: (address: source, port: sourcePort),
        );
      } else if (datagram &&
          source != null &&
          sourcePort != null &&
          body['op'] == 'pong') {
        if (!_probes.accept('${source.address}:$sourcePort', body['nonce'])) {
          return;
        }
        if (ready &&
            (_peer?.address.address != source.address ||
                _peer?.port != sourcePort)) {
          return;
        }
        _peer = (address: source, port: sourcePort);
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
          _probes.clear();
          addresses
            ..clear()
            ..addAll(current);
          _peer = null;
          _candidates = [];
          _mapped = null;
          _binding = null;
          _confirmed = null;
        }
      }
      unawaited(_discover());
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
        final nonce = _probes.issue(
          '${candidate.address.address}:${candidate.port}',
        );
        await _send(
          _control({'op': 'ping', 'nonce': nonce}),
          target: candidate,
        );
      } on SocketException {
        // One unavailable interface must not prevent probing the others.
      }
    }
  }

  Future<void> _send(NovoRudpFrame frame, {_Endpoint? target}) async {
    final destination = target ?? _peer;
    if (_closed || destination == null) {
      throw StateError('LAN route unavailable');
    }
    final epoch = _endpointEpoch;
    final wire = NovoRudpSecurePacket.encode(await channel.seal(frame));
    if (_closed ||
        epoch != _endpointEpoch ||
        _socket.send(wire, destination.address, destination.port) !=
            wire.length) {
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
        if (_binding != null &&
            packet.address.address == _observer?.address &&
            packet.port == observerPort) {
          final mapped = _binding!.parseResponse(packet.data);
          if (mapped != null &&
              _public(mapped.address) &&
              _bindingAge!.elapsed < const Duration(seconds: 8)) {
            _mapped = mapped;
            _mappedAge = Stopwatch()..start();
            _binding = null;
            unawaited(advertise().catchError((Object _) {}));
          }
          continue;
        }
        if (!_candidates.any(
          (a) =>
              a.address.address == packet.address.address &&
              a.port == packet.port,
        )) {
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
            await acceptControl(
              frame,
              datagram: true,
              source: packet.address,
              sourcePort: packet.port,
            );
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
    _probes.clear();
    _timer.cancel();
    _socket.close();
    return _closing ??= _events.cancel();
  }

  Future<void> _discover() async {
    if (_closed ||
        _discovering ||
        observerHost.isEmpty ||
        observerPort < 1 ||
        observerPort > 65535) {
      return;
    }
    _discovering = true;
    try {
      if (_mappedAge != null &&
          _mappedAge!.elapsed >= const Duration(seconds: 60)) {
        _mapped = null;
      }
      if (_binding == null &&
          _mapped != null &&
          _mappedAge!.elapsed < const Duration(seconds: 30)) {
        return;
      }
      if (_binding == null ||
          _bindingAge!.elapsed >= const Duration(seconds: 30)) {
        final servers = await InternetAddress.lookup(
          observerHost,
          type: InternetAddressType.IPv4,
        ).timeout(const Duration(seconds: 2));
        if (_closed || servers.isEmpty) return;
        _observer = servers.first;
        _binding = NovoRudpStunBinding();
        _bindingAge = Stopwatch()..start();
      }
      if (_closed || _bindingAge!.elapsed >= const Duration(seconds: 8)) return;
      _socket.send(_binding!.request, _observer!, observerPort);
    } catch (_) {
      // Discovery never blocks the existing authenticated relay route.
    } finally {
      _discovering = false;
    }
  }
}
