import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import 'network_rendezvous_repository.dart';
import 'novorudp_device_binding.dart';
import 'novorudp_secure_session.dart';

/// Owns one exchange and its native handles. A completed channel still needs
/// endpoint discovery, an authenticated data link and a delivery protocol.
class NovoRudpPeerHandshake {
  NovoRudpPeerHandshake({required this.binding, required this.repository}) {
    if (!identical(binding.messaging, repository.messaging)) {
      throw ArgumentError('Handshake repositories must share one login');
    }
    _login = SecureSessionStore.changes.stream.listen((_) => close());
  }
  final NovoRudpDeviceBinding binding;
  final NetworkRendezvousRepository repository;
  final _requestId = const Uuid().v4();
  final _generation = MemberQrMemory.generation;
  late final StreamSubscription<void> _login;
  bool _closed = false, _busy = false, _completed = false;
  String? _mode;
  Timer? _expiry;
  int? _deadline;
  BoundNetworkHandshake? _outgoing;
  NetworkExchange? _exchange;
  NovoRudpSecureChannel? _channel;
  Map<String, dynamic>? _answer;

  void _check() {
    if (_closed ||
        _generation != MemberQrMemory.generation ||
        (!_completed &&
            _deadline != null &&
            DateTime.now().millisecondsSinceEpoch >= _deadline!)) {
      close();
      throw StateError('Peer handshake closed');
    }
  }

  void _expireAt(int time) {
    _deadline = _deadline == null || time < _deadline! ? time : _deadline;
    _expiry?.cancel();
    _expiry = Timer(
      Duration(
        milliseconds: (_deadline! - DateTime.now().millisecondsSinceEpoch)
            .clamp(0, 45000),
      ),
      close,
    );
  }

  Future<T> _run<T>(String mode, Future<T> Function() work) async {
    _check();
    if (_busy || (_mode != null && _mode != mode)) {
      throw StateError('Another handshake operation is active');
    }
    _mode = mode;
    _busy = true;
    if (_deadline == null) {
      _expireAt(DateTime.now().millisecondsSinceEpoch + 45000);
    }
    try {
      return await work();
    } catch (error) {
      // Retain the exact native offer/answer only after an uncertain network
      // response. Other failures require a fresh explicitly started exchange.
      if (error is! AuthFailure || error.code != 'NETWORK_ERROR') close();
      rethrow;
    } finally {
      _busy = false;
    }
  }

  void _own(NovoRudpSecureChannel channel) {
    if (_closed) {
      channel.close();
      throw StateError('Peer handshake closed');
    }
    _channel = channel;
    _check();
  }

  NovoRudpSecureChannel _finish() {
    _check();
    _completed = true;
    _expiry?.cancel();
    return _channel!;
  }

  Future<NetworkExchange> offer() => _run('outgoing', () async {
    if (_exchange != null) return _exchange!;
    final started =
        _outgoing ??
        await binding.startPeer(repository.peer, repository.peerBindingId);
    _outgoing = started;
    if (_closed) started.cancel();
    _check();
    final result = await repository.offer(_requestId, started.offer);
    _check();
    _exchange = result;
    _expireAt(result.expiresAtMs);
    return result;
  });

  Future<NovoRudpSecureChannel?> pollAnswer() => _run('outgoing', () async {
    if (_completed) return _channel;
    final offered = _exchange;
    if (offered == null || _outgoing == null) {
      throw StateError('Offer not acknowledged');
    }
    final current = await repository.read();
    _check();
    if (current == null ||
        current.id != offered.id ||
        current.fromBindingId != repository.ownBindingId ||
        current.expiresAtMs != offered.expiresAtMs) {
      throw StateError('Exchange changed');
    }
    current.requireUsable();
    if (current.answer == null) return null;
    final channel = await _outgoing!.complete(current.answer!);
    _own(channel);
    return _finish();
  });

  Future<NovoRudpSecureChannel> answer(NetworkExchange incoming) =>
      _run('incoming', () async {
        if (_completed) {
          if (_exchange?.id != incoming.id) {
            throw StateError('Different exchange');
          }
          return _channel!;
        }
        incoming.requireUsable();
        if (incoming.fromBindingId != repository.peerBindingId ||
            incoming.toBindingId != repository.ownBindingId) {
          throw StateError('Wrong invited device');
        }
        if (_exchange != null &&
            (_exchange!.id != incoming.id ||
                jsonEncode(_exchange!.offer) != jsonEncode(incoming.offer))) {
          throw StateError('Offer changed');
        }
        _exchange ??= incoming;
        _expireAt(incoming.expiresAtMs);
        if (_answer == null) {
          final response = await binding.respondPeer(
            repository.peer,
            repository.peerBindingId,
            incoming.offer,
          );
          _own(response.channel);
          _answer = response.response;
        }
        await repository.answer(_exchange!, _answer!);
        return _finish();
      });

  void close() {
    if (_closed) return;
    _closed = true;
    _expiry?.cancel();
    unawaited(_login.cancel());
    _outgoing?.cancel();
    _channel?.close();
    _channel = null;
    _answer = null;
    repository.close();
  }
}
