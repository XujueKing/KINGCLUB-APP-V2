import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_device_binding.dart';
import 'novorudp_relay_connection.dart';
import 'novorudp_relay_frame_link.dart';
import 'member_relay_handshake.dart';

typedef MemberRelayArrival = ({String peer, NovoRudpRelayFrameLink link});

/// Foreground/session ownership for an explicitly trusted relay. Does not
/// select chat routes or interpret a relay identity as a member permission.
class MemberRelayRuntime with WidgetsBindingObserver {
  MemberRelayRuntime({
    required this.binding,
    required this.endpoint,
    required this.expectedRelay,
    this.securityContext,
  });
  final NovoRudpDeviceBinding binding;
  final Uri endpoint;
  final String expectedRelay;
  final SecurityContext? securityContext;
  final int _generation = MemberQrMemory.generation;
  final _connections = StreamController<NovoRudpRelayConnection?>.broadcast();
  final _offers = StreamController<Map<String, dynamic>>.broadcast();
  final _arrivals = StreamController<MemberRelayArrival>.broadcast();

  /// Subscribe before connecting. The consumer takes ownership of the link;
  /// this runtime also closes it when its foreground relay is disconnected.
  Stream<MemberRelayArrival> get incomingChannels => _arrivals.stream;
  final _pendingPeers = <String>{};
  final _handshakes = <String, MemberRelayHandshake>{};
  final _peerLinks = <String, NovoRudpRelayFrameLink>{};
  final _peerSubscriptions = <String, StreamSubscription>{};
  final _arrivalWindow = Stopwatch()..start();
  int _arrivalAttempts = 0;

  /// Consumers must resolve the source to a member and invoke the bound
  /// handshake; receipt here is not permission to exchange chat messages.
  Stream<Map<String, dynamic>> get incomingHandshakes => _offers.stream;
  Stream<NovoRudpRelayConnection?> get connections => _connections.stream;
  NovoRudpRelayConnection? get connection {
    if (_generation != MemberQrMemory.generation) close();
    return _ready;
  }

  NovoRudpRelayConnection? _opening, _ready;
  StreamSubscription<Map<String, dynamic>>? _receiver;
  StreamSubscription<void>? _session;
  Timer? _retry;
  int _attempt = 0;
  bool _started = false, _closed = false, _foreground = false;

  void start() {
    if (_closed || _started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) => close());
    final state = WidgetsBinding.instance.lifecycleState;
    didChangeAppLifecycleState(state ?? AppLifecycleState.resumed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closed || !_started) return;
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (foreground) {
      unawaited(_connect(++_attempt));
    } else {
      _disconnect();
    }
  }

  bool _current(int attempt) =>
      !_closed &&
      _foreground &&
      attempt == _attempt &&
      _generation == MemberQrMemory.generation;

  Future<void> _connect(int attempt) async {
    NovoRudpRelayConnection? socket;
    try {
      await binding.ensureRegistered().timeout(const Duration(seconds: 5));
      if (!_current(attempt)) return;
      socket = NovoRudpRelayConnection(
        identity: binding.identity,
        endpoint: endpoint,
        expectedRelay: expectedRelay,
        securityContext: securityContext,
      );
      _opening = socket;
      _receiver = socket.messages.listen(
        (event) {
          if (_current(attempt) && event['kind'] == 'peer_handshake_delivery') {
            final body = event['body'];
            if (body is Map &&
                body['handshake'] is Map &&
                body['handshake']['kind'] == 'offer') {
              _offers.add(event);
              unawaited(_acceptOffer(socket!, event, attempt));
            }
          }
        },
        onDone: () => _lost(attempt),
        onError: (Object _) => _lost(attempt),
      );
      await socket.connect();
      if (!_current(attempt)) {
        socket.close();
        return;
      }
      _ready = socket;
      _connections.add(socket);
    } catch (_) {
      socket?.close();
      _lost(attempt);
    }
  }

  void _lost(int attempt) {
    if (_generation != MemberQrMemory.generation) {
      close();
      return;
    }
    if (!_current(attempt)) return;
    _disconnect();
    if (_foreground && !_closed) {
      _retry = Timer(const Duration(seconds: 30), () {
        if (_closed || !_foreground) return;
        if (_generation != MemberQrMemory.generation) {
          close();
          return;
        }
        unawaited(_connect(++_attempt));
      });
    }
  }

  Future<void> _acceptOffer(
    NovoRudpRelayConnection socket,
    Map<String, dynamic> event,
    int attempt,
  ) async {
    if (!_current(attempt) || !_arrivals.hasListener) return;
    final source = (event['body'] as Map)['source_peer_id'] as String;
    if (_pendingPeers.contains(source) ||
        (!_peerLinks.containsKey(source) &&
            _pendingPeers.length + _peerLinks.length >= 8)) {
      return;
    }
    if (_arrivalWindow.elapsed >= const Duration(minutes: 1)) {
      _arrivalWindow.reset();
      _arrivalAttempts = 0;
    }
    if (_arrivalAttempts++ >= 16) return;
    _pendingPeers.add(source);
    MemberRelayHandshake? handshake;
    NovoRudpRelayFrameLink? link;
    try {
      final resolved = await binding
          .resolvePeer(source)
          .timeout(const Duration(seconds: 5));
      if (!_current(attempt)) return;
      handshake = MemberRelayHandshake(
        binding: binding,
        relay: socket,
        peer: resolved.peer,
        peerBindingId: resolved.key.bindingId,
        initialOffer: event,
      );
      _handshakes[source] = handshake;
      link = await handshake.connect();
      if (!_current(attempt) || !_arrivals.hasListener) {
        await link.close();
        return;
      }
      final accepted = link;
      final previous = _peerLinks[source];
      if (previous != null) unawaited(previous.close());
      unawaited(_peerSubscriptions.remove(source)?.cancel());
      _peerLinks[source] = accepted;
      _peerSubscriptions[source] = accepted.frames.listen(
        (_) {},
        onDone: () {
          if (identical(_peerLinks[source], accepted)) {
            _peerLinks.remove(source);
            _peerSubscriptions.remove(source);
          }
        },
      );
      _arrivals.add((peer: resolved.peer, link: accepted));
      link = null;
    } catch (_) {
      // An untrusted/expired request cannot interrupt the relay or UI.
      if (link != null) unawaited(link.close());
    } finally {
      handshake?.close();
      if (_current(attempt)) {
        _pendingPeers.remove(source);
        if (identical(_handshakes[source], handshake)) {
          _handshakes.remove(source);
        }
      }
    }
  }

  void _disconnect() {
    _attempt++;
    for (final handshake in _handshakes.values) {
      handshake.close();
    }
    _handshakes.clear();
    _pendingPeers.clear();
    for (final link in _peerLinks.values) {
      unawaited(link.close());
    }
    _peerLinks.clear();
    for (final subscription in _peerSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _peerSubscriptions.clear();
    _retry?.cancel();
    _opening?.close();
    _opening = null;
    unawaited(_receiver?.cancel());
    _receiver = null;
    if (_ready != null) {
      _ready = null;
      _connections.add(null);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _disconnect();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    unawaited(_session?.cancel());
    unawaited(_connections.close());
    unawaited(_offers.close());
    unawaited(_arrivals.close());
  }
}
