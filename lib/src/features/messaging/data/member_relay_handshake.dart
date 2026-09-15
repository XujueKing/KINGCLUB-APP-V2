import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_device_binding.dart';
import 'novorudp_relay_connection.dart';
import 'novorudp_relay_frame_link.dart';
import 'novorudp_secure_session.dart';

/// Uses the authoritative member/device binding for both sides of relay peer
/// authentication. A relay identity or discovery advertisement is not sufficient.
class MemberRelayHandshake {
  MemberRelayHandshake({
    required this.binding,
    required this.relay,
    required this.peer,
    required this.peerBindingId,
  }) : _ownPeerId = binding.identity.peerId {
    if (!identical(binding.identity, relay.identity) ||
        peer == binding.messaging.account) {
      throw ArgumentError('Relay and binding must share an identity');
    }
  }
  final NovoRudpDeviceBinding binding;
  final NovoRudpRelayConnection relay;
  final String peer, peerBindingId;
  final String _ownPeerId;
  final int _generation = MemberQrMemory.generation;
  final _early = <Map<String, dynamic>>[];
  Completer<NovoRudpRelayFrameLink>? _result;
  StreamSubscription<Map<String, dynamic>>? _messages;
  StreamSubscription<void>? _session;
  Timer? _deadline;
  NetworkDeviceKey? _key;
  BoundNetworkHandshake? _offer;
  bool _closed = false, _receiving = false;

  Future<NovoRudpRelayFrameLink> connect() {
    if (_closed) throw StateError('Member relay handshake closed');
    if (_result != null) return _result!.future;
    final result = _result = Completer<NovoRudpRelayFrameLink>();
    _messages = relay.messages.listen(
      (event) {
        if (_closed || event['kind'] != 'peer_handshake_delivery') return;
        if (_key == null) {
          if (_early.length < 4) _early.add(event);
        } else {
          unawaited(_receive(event));
        }
      },
      onDone: () => close(),
      onError: (Object error) => close(error),
    );
    _session = SecureSessionStore.changes.stream.listen((_) => close());
    _deadline = Timer(
      const Duration(seconds: 8),
      () => close(TimeoutException('Member handshake timed out')),
    );
    unawaited(_start());
    return result.future;
  }

  void _check() {
    if (_closed || _generation != MemberQrMemory.generation) {
      throw StateError('Member relay handshake closed');
    }
  }

  Future<void> _start() async {
    try {
      final keys = await binding.directory(peer);
      _check();
      final key = keys.where((key) => key.bindingId == peerBindingId).single;
      _key = key;
      if (_ownPeerId.compareTo(key.peerId) < 0) {
        final offer = await binding.startPeer(peer, peerBindingId);
        if (_closed) {
          offer.cancel();
          return;
        }
        _offer = offer;
        _check();
        relay.sendPeerHandshake(key.peerId, {
          'kind': 'offer',
          'body': offer.offer,
        });
      }
      final early = List<Map<String, dynamic>>.of(_early);
      _early.clear();
      for (final event in early) {
        await _receive(event);
      }
    } catch (error) {
      close(error);
    }
  }

  Future<void> _receive(Map<String, dynamic> event) async {
    if (_closed || _receiving) return;
    final body = event['body'];
    if (body is! Map ||
        body['source_peer_id'] != _key?.peerId ||
        body['handshake'] is! Map) {
      return;
    }
    final wire = body['handshake'] as Map;
    if (wire['body'] is! Map<String, dynamic>) {
      return;
    }
    final payload = wire['body'] as Map<String, dynamic>;
    final offer = _offer;
    final initiator = _ownPeerId.compareTo(_key!.peerId) < 0;
    if (initiator && (wire['kind'] != 'response' || offer == null)) {
      return;
    }
    if (initiator &&
        (payload['session_id'] is! List ||
            !listEquals(
              payload['session_id'] as List,
              offer!.offer['session_id'] as List,
            ))) {
      return;
    }
    if (!initiator && wire['kind'] != 'offer') return;
    _receiving = true;
    NovoRudpSecureChannel? channel;
    try {
      _check();
      if (initiator) {
        channel = await offer!.complete(wire['body'] as Map<String, dynamic>);
      } else {
        final answer = await binding.respondPeer(
          peer,
          peerBindingId,
          wire['body'] as Map<String, dynamic>,
        );
        channel = answer.channel;
        _check();
        relay.sendPeerHandshake(_key!.peerId, {
          'kind': 'response',
          'body': answer.response,
        });
      }
      _check();
      final link = NovoRudpRelayFrameLink(
        relay: relay,
        channel: channel,
        expectedPeer: _key!.peerId,
      );
      channel = null;
      _result!.complete(link);
      close();
    } catch (error) {
      channel?.close();
      close(error);
    } finally {
      _receiving = false;
    }
  }

  void close([Object? error]) {
    if (_closed) return;
    _closed = true;
    _deadline?.cancel();
    unawaited(_messages?.cancel());
    unawaited(_session?.cancel());
    _offer?.cancel();
    _early.clear();
    if (_result != null && !_result!.isCompleted) {
      _result!.completeError(
        error ?? StateError('Member relay handshake closed'),
      );
    }
  }
}
