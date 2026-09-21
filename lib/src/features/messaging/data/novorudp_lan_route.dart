import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'novorudp_frame.dart';
import 'novorudp_secure_packet.dart';
import 'novorudp_secure_session.dart';
import 'novorudp_stun_binding.dart';
import 'novorudp_route_probe.dart';

typedef _Endpoint = ({InternetAddress address, int port});

/// Optional IPv4 LAN/NAT and global IPv6 carriage for an authenticated channel.
/// Addresses arrive only through that channel; they never establish identity.
class NovoRudpLanRoute {
  static const stunHost = String.fromEnvironment('KINGCLUB_NOVORUDP_STUN_HOST');
  static const stunFallbacks = String.fromEnvironment(
    'KINGCLUB_NOVORUDP_STUN_FALLBACKS',
  );
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

  /// Only global unicast candidates; never advertise scoped/link-local, ULA,
  /// multicast, IPv4-mapped or documentation addresses to a remote peer.
  static bool isGlobalIpv6(InternetAddress ip) {
    if (ip.type != InternetAddressType.IPv6) return false;
    final bytes = ip.rawAddress;
    return (bytes[0] & 0xe0) == 0x20 &&
        !(bytes[0] == 0x20 &&
            bytes[1] == 1 &&
            bytes[2] == 0x0d &&
            bytes[3] == 0xb8);
  }

  static Future<List<String>> _globalIpv6Addresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv6,
    );
    final values =
        interfaces
            .expand((i) => i.addresses)
            .where(isGlobalIpv6)
            .map((a) => a.address)
            .toSet()
            .toList()
          ..sort();
    return values.take(2).toList();
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
    String observerFallbacks = stunFallbacks,
    @visibleForTesting Future<RawDatagramSocket> Function()? bindIpv6,
    @visibleForTesting Future<List<String>> Function()? discoverIpv6,
  }) async {
    final observers = parseObservers(
      observerHost,
      observerPort,
      observerFallbacks,
    );
    final addresses = await _localAddresses();
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    RawDatagramSocket? ipv6Socket;
    var ipv6Addresses = <String>[];
    final bind6 =
        bindIpv6 ?? () => RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
    final discover6 = discoverIpv6 ?? _globalIpv6Addresses;
    try {
      ipv6Socket = await bind6();
      ipv6Addresses = await discover6();
    } on SocketException catch (error) {
      ipv6Socket?.close();
      ipv6Socket = null;
      if (!kReleaseMode) {
        debugPrint(
          'NovoRoute ipv6Unavailable code=${error.osError?.errorCode}',
        );
      }
      // IPv6 being unavailable must never disable IPv4/relay.
    }
    return NovoRudpLanRoute._(
      socket,
      ipv6Socket,
      ipv6Addresses,
      bind6,
      discover6,
      channel,
      addresses,
      sendControl,
      deliver,
      observerHost,
      observerPort,
      observers,
    );
  }

  NovoRudpLanRoute._(
    this._socket,
    this._ipv6Socket,
    this._ipv6Addresses,
    this._bindIpv6,
    this._discoverIpv6,
    this.channel,
    this.addresses,
    this.sendControl,
    this.deliver,
    this.observerHost,
    this.observerPort,
    this._observers,
  ) {
    for (final socket in [_socket, ?_ipv6Socket]) {
      _listen(socket);
    }
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_tick()),
    );
    unawaited(_discover());
  }

  void _listen(RawDatagramSocket socket) {
    socket.writeEventsEnabled = false;
    _events[socket] = socket.listen(
      (event) {
        if (event == RawSocketEvent.read) unawaited(_read(socket));
        if (event == RawSocketEvent.closed) _socketEnded(socket);
      },
      onError: (Object error) => _socketError(socket, error),
      onDone: () => _socketEnded(socket),
    );
  }

  final RawDatagramSocket _socket;
  RawDatagramSocket? _ipv6Socket;
  final Future<RawDatagramSocket> Function() _bindIpv6;
  final Future<List<String>> Function() _discoverIpv6;
  bool _ipv6Failed = false;
  final List<String> _ipv6Addresses;
  final NovoRudpSecureChannel channel;
  final List<String> addresses;
  final Future<void> Function(NovoRudpFrame) sendControl, deliver;
  final _events = <RawDatagramSocket, StreamSubscription<RawSocketEvent>>{};
  final _readingSockets = <RawDatagramSocket>{};
  late final Timer _timer;
  _Endpoint? _peer, _mapped;
  List<_Endpoint> _candidates = [];
  final List<_Endpoint> _reflexive = [];
  final _unknownPortWindow = Stopwatch()..start();
  int _unknownPortAttempts = 0;
  final String observerHost;
  final int observerPort;
  final List<({String host, int port})> _observers;
  int _observerIndex = 0;
  int? _activeObserverPort;
  InternetAddress? _observer;
  NovoRudpStunBinding? _binding;
  Stopwatch? _bindingAge, _mappedAge;
  bool _discovering = false;
  Stopwatch? _confirmed;
  bool _closed = false, _ticking = false;
  int _advertisements = 0;
  int _endpointEpoch = 0;
  final _probes = NovoRudpRouteProbe();
  int _stunReplies = 0,
      _probeSends = 0,
      _pingReceives = 0,
      _pongReceives = 0,
      _portMismatches = 0,
      _unknownAddresses = 0,
      _invalidPackets = 0;
  Future<void>? _closing;

  void _socketError(RawDatagramSocket socket, Object error) {
    if (_closed || !_events.containsKey(socket)) return;
    if (error is SocketException) {
      // UDP can report ICMP unreachable for one candidate while the socket is
      // still usable. Only closed/done events retire an address family.
      if (_peer != null &&
          (_peer!.address.type == InternetAddressType.IPv6) ==
              identical(socket, _ipv6Socket)) {
        _confirmed = null;
      }
      return;
    }
    _socketEnded(socket);
  }

  void _socketEnded(RawDatagramSocket socket) {
    if (_closed) return;
    if (identical(socket, _socket)) {
      unawaited(close());
      return;
    }
    if (!identical(socket, _ipv6Socket) || _ipv6Failed) return;
    _ipv6Failed = true;
    _endpointEpoch++;
    _probes.clear();
    _ipv6Addresses.clear();
    _candidates.removeWhere((e) => e.address.type == InternetAddressType.IPv6);
    _reflexive.removeWhere((e) => e.address.type == InternetAddressType.IPv6);
    if (_peer?.address.type == InternetAddressType.IPv6) {
      _peer = null;
      _confirmed = null;
    }
    socket.close();
    unawaited(_events.remove(socket)?.cancel());
    unawaited(advertise().catchError((Object _) {}));
    unawaited(_probe().catchError((Object _) {}));
  }

  bool get isClosed => _closed;

  bool get ready =>
      !_closed &&
      _confirmed != null &&
      _confirmed!.elapsed < const Duration(seconds: 6);

  /// A transfer has missed consecutive receipts. Stop trusting the old path
  /// immediately; the caller can use relay while a fresh nonce probe runs.
  /// A late response to an earlier heartbeat cannot reinstate the route.
  void reprobeAfterStall() {
    if (_closed || !ready) return;
    _confirmed = null;
    _probes.clear();
    unawaited(_probe().catchError((Object _) {}));
  }

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
        if (_ipv6Socket != null && _ipv6Addresses.isNotEmpty)
          'ipv6': {'addresses': _ipv6Addresses, 'port': _ipv6Socket!.port},
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
        if (_observers.isNotEmpty && external is Map) {
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
        final v6 = body['ipv6'];
        if (_ipv6Socket != null &&
            !_ipv6Failed &&
            _ipv6Addresses.isNotEmpty &&
            v6 is Map) {
          final hosts = v6['addresses'], port6 = v6['port'];
          if (hosts is List &&
              hosts.length <= 2 &&
              port6 is int &&
              port6 > 0 &&
              port6 <= 65535) {
            for (final host in hosts) {
              final ip = host is String ? InternetAddress.tryParse(host) : null;
              if (ip != null &&
                  isGlobalIpv6(ip) &&
                  !candidates.any(
                    (a) => a.address.address == ip.address && a.port == port6,
                  )) {
                candidates.add((address: ip, port: port6));
              }
            }
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
          _reflexive.clear();
        }
        await _probe();
      } else if (datagram &&
          source != null &&
          sourcePort != null &&
          body['op'] == 'ping') {
        if (!NovoRudpRouteProbe.validNonce(body['nonce'])) return;
        if (!kReleaseMode) _pingReceives++;
        await _send(
          _control({'op': 'pong', 'nonce': body['nonce']}),
          target: (address: source, port: sourcePort),
        );
        // NAT may allocate a different port for the peer than for STUN.
        // Authentication identifies the peer; a fresh return-path challenge
        // proves reachability before this observed endpoint can carry data.
        if (!_knownEndpoint(source, sourcePort) && !ready) {
          if (_reflexive.length == 2) _reflexive.removeAt(0);
          final endpoint = (address: source, port: sourcePort);
          _reflexive.add(endpoint);
          await _probeEndpoint(endpoint);
        }
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
        if (!kReleaseMode) _pongReceives++;
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
        var current6 = await _discoverIpv6();
        if (_closed) return;
        if (current6.isNotEmpty && (_ipv6Socket == null || _ipv6Failed)) {
          try {
            final restored = await _bindIpv6();
            if (_closed) {
              restored.close();
              return;
            }
            _ipv6Socket = restored;
            _ipv6Failed = false;
            _listen(restored);
          } on SocketException {
            current6 = [];
          }
        }
        if (jsonEncode(current) != jsonEncode(addresses) ||
            jsonEncode(current6) != jsonEncode(_ipv6Addresses)) {
          _endpointEpoch++;
          _probes.clear();
          addresses
            ..clear()
            ..addAll(current);
          _ipv6Addresses
            ..clear()
            ..addAll(current6);
          _peer = null;
          _candidates = [];
          _reflexive.clear();
          _mapped = null;
          _binding = null;
          _confirmed = null;
        }
      }
      unawaited(_discover());
      // Refresh after joining/changing Wi-Fi, including routes opened on cellular.
      if (tick < 4 || tick % 15 == 0) await advertise();
      await _probe();
      if (!kReleaseMode && (tick == 4 || tick % 15 == 14)) {
        debugPrint(
          'NovoRoute mapped=${_mapped != null} stunReplies=$_stunReplies '
          'candidates=${_candidates.length} '
          'publicCandidates=${_candidates.where((e) => _public(e.address)).length} '
          'ipv6Candidates=${_candidates.where((e) => isGlobalIpv6(e.address)).length} '
          'ipv6Socket=${_ipv6Socket != null && !_ipv6Failed} localIpv6=${_ipv6Addresses.length} '
          'probeSends=$_probeSends pingReceives=$_pingReceives '
          'pongReceives=$_pongReceives portMismatches=$_portMismatches '
          'unknownAddresses=$_unknownAddresses '
          'invalidPackets=$_invalidPackets ready=$ready',
        );
      }
    } catch (_) {
      _confirmed = null;
    } finally {
      _ticking = false;
    }
  }

  Future<void> _probe() async {
    final candidates = ready ? [_peer!] : [..._candidates, ..._reflexive];
    for (final candidate in candidates) {
      try {
        await _probeEndpoint(candidate);
      } on SocketException {
        // One unavailable interface must not prevent probing the others.
      }
    }
  }

  bool _knownEndpoint(InternetAddress address, int port) => [
    ..._candidates,
    ..._reflexive,
  ].any((a) => a.address.address == address.address && a.port == port);

  Future<void> _probeEndpoint(_Endpoint candidate) async {
    final nonce = _probes.issue(
      '${candidate.address.address}:${candidate.port}',
    );
    await _send(_control({'op': 'ping', 'nonce': nonce}), target: candidate);
    if (!kReleaseMode) _probeSends++;
  }

  Future<void> _send(NovoRudpFrame frame, {_Endpoint? target}) async {
    final destination = target ?? _peer;
    if (_closed || destination == null) {
      throw StateError('LAN route unavailable');
    }
    final epoch = _endpointEpoch;
    final wire = NovoRudpSecurePacket.encode(await channel.seal(frame));
    final socket = destination.address.type == InternetAddressType.IPv6
        ? (_ipv6Failed ? null : _ipv6Socket)
        : _socket;
    if (_closed ||
        epoch != _endpointEpoch ||
        socket == null ||
        socket.send(wire, destination.address, destination.port) !=
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

  Future<void> _read(RawDatagramSocket socket) async {
    if (_closed || !_readingSockets.add(socket)) return;
    socket.readEventsEnabled = false;
    try {
      for (var i = 0; i < 64 && !_closed; i++) {
        final packet = socket.receive();
        if (packet == null) break;
        if (_binding != null &&
            packet.address.address == _observer?.address &&
            packet.port == _activeObserverPort) {
          final mapped = _binding!.parseResponse(packet.data);
          if (mapped != null &&
              _public(mapped.address) &&
              _bindingAge!.elapsed < const Duration(seconds: 8)) {
            _mapped = mapped;
            if (!kReleaseMode) _stunReplies++;
            _mappedAge = Stopwatch()..start();
            _binding = null;
            unawaited(advertise().catchError((Object _) {}));
          }
          continue;
        }
        final known = _knownEndpoint(packet.address, packet.port);
        if (!known) {
          if (!_candidates.any(
            (a) => a.address.address == packet.address.address,
          )) {
            if (!kReleaseMode) _unknownAddresses++;
            continue;
          }
          if (!kReleaseMode) _portMismatches++;
          if (ready) continue;
          if (_unknownPortWindow.elapsed >= const Duration(seconds: 1)) {
            _unknownPortWindow.reset();
            _unknownPortAttempts = 0;
          }
          if (++_unknownPortAttempts > 8) continue;
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
          } else if (known &&
              ready &&
              (_candidates.any(
                    (a) =>
                        a.address.address == packet.address.address &&
                        a.port == packet.port,
                  ) ||
                  (_peer?.address.address == packet.address.address &&
                      _peer?.port == packet.port))) {
            // Both peers may select different advertised interfaces on a
            // multi-homed host. Source candidate/port, endpoint epoch and AEAD
            // were already verified above; requiring our chosen outbound IP
            // here drops valid traffic from the peer's other signed candidate.
            await deliver(frame);
          }
        } on FormatException {
          if (!kReleaseMode) _invalidPackets++;
          /* Ignore invalid packets. */
        } on StateError {
          if (!kReleaseMode) _invalidPackets++;
          /* Ignore unauthenticated or replayed packets. */
        }
      }
    } catch (_) {
      _confirmed = null;
    } finally {
      _readingSockets.remove(socket);
      if (!_closed && _events.containsKey(socket)) {
        socket.readEventsEnabled = true;
      }
    }
  }

  Future<void> close() {
    _closed = true;
    _probes.clear();
    _timer.cancel();
    _socket.close();
    _ipv6Socket?.close();
    return _closing ??= Future.wait(
      _events.values.map((event) => event.cancel()),
    ).then((_) {});
  }

  Future<void> _discover() async {
    if (_closed || _discovering || _observers.isEmpty) {
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
      if (_binding != null &&
          _bindingAge!.elapsed >= const Duration(seconds: 4)) {
        _binding = null;
        _observerIndex = (_observerIndex + 1) % _observers.length;
      }
      if (_binding == null) {
        final endpoint = _observers[_observerIndex];
        final epoch = _endpointEpoch;
        final servers = await InternetAddress.lookup(
          endpoint.host,
          type: InternetAddressType.IPv4,
        ).timeout(const Duration(seconds: 2));
        if (_closed || epoch != _endpointEpoch) return;
        if (servers.isEmpty) throw const SocketException('No STUN address');
        _observer = servers.first;
        _activeObserverPort = endpoint.port;
        _binding = NovoRudpStunBinding();
        _bindingAge = Stopwatch()..start();
      }
      if (_closed || _bindingAge!.elapsed >= const Duration(seconds: 8)) return;
      _socket.send(_binding!.request, _observer!, _activeObserverPort!);
    } catch (_) {
      _binding = null;
      _observerIndex = (_observerIndex + 1) % _observers.length;
      // Discovery never blocks the existing authenticated relay route.
    } finally {
      _discovering = false;
    }
  }

  /// Deployment-owned IPv4/DNS endpoints only; never learned from peer payloads.
  static List<({String host, int port})> parseObservers(
    String host,
    int port,
    String fallbacks,
  ) {
    final result = <({String host, int port})>[];
    void add(String host, int port) {
      if (host.length > 253 ||
          !RegExp(r'^[A-Za-z0-9][A-Za-z0-9.-]*$').hasMatch(host) ||
          port < 1 ||
          port > 65535) {
        throw const FormatException('Invalid STUN endpoint');
      }
      final endpoint = (host: host.toLowerCase(), port: port);
      if (!result.contains(endpoint)) result.add(endpoint);
    }

    if (host.isNotEmpty) add(host, port);
    if (fallbacks.isNotEmpty) {
      final entries = fallbacks.split(',');
      if (entries.length > 3) {
        throw const FormatException('Too many STUN fallbacks');
      }
      for (final entry in entries) {
        final parts = entry.split(':');
        if (parts.length != 2) {
          throw const FormatException('Invalid STUN fallback');
        }
        add(parts[0], int.tryParse(parts[1]) ?? 0);
      }
    }
    return List.unmodifiable(result);
  }
}
