import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_device_binding.dart';
import 'novorudp_relay_connection.dart';

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
        (_) {},
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

  void _disconnect() {
    _attempt++;
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
  }
}
