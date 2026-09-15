import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_secure_datagram_link.dart';
import 'novorudp_secure_session.dart';

/// Direct LAN handshake for an independently confirmed device key. No HTTP.
/// Discovery hints alone must never be used as [expectedPeer].
class NearbyPeerConnector {
  NearbyPeerConnector({
    required RawDatagramSocket socket,
    required this.identity,
    required this.expectedPeer,
    required this.address,
    required this.port,
  }) : _socket = socket {
    if (address.type != socket.address.type ||
        port < 1 ||
        port > 65535 ||
        expectedPeer == identity.peerId ||
        !RegExp(r'^novovm-ed25519:[0-9a-f]{64}$').hasMatch(expectedPeer)) {
      throw ArgumentError('Invalid nearby peer');
    }
  }
  final RawDatagramSocket _socket;
  final NovoRudpSecureSession identity;
  final String expectedPeer;
  final InternetAddress address;
  final int port;
  final int _generation = MemberQrMemory.generation;
  final String _id = const Uuid().v4();
  StreamSubscription<RawSocketEvent>? _events;
  StreamSubscription<void>? _session;
  Completer<NovoRudpSecureDatagramLink>? _result;
  NovoRudpHandshake? _offer;
  Timer? _retry, _deadline;
  bool _closed = false, _transferred = false;

  Future<NovoRudpSecureDatagramLink> connect() {
    if (_closed || _transferred || _generation != MemberQrMemory.generation) {
      throw StateError('Nearby connector closed');
    }
    if (_result != null) return _result!.future;
    final result = _result = Completer<NovoRudpSecureDatagramLink>();
    try {
      _socket.writeEventsEnabled = false;
      _events = _socket.listen(
        _read,
        onError: (Object e) => close(),
        onDone: close,
      );
      _session = SecureSessionStore.changes.stream.listen((_) => close());
      _deadline = Timer(
        const Duration(seconds: 8),
        () => close(TimeoutException('Nearby handshake timed out')),
      );
      // Both peers can connect concurrently without creating two channels.
      if (identity.peerId.compareTo(expectedPeer) < 0) {
        _offer = identity.start(expectedPeer);
        final wire = utf8.encode(
          jsonEncode({
            'kind': 'kingclub_nearby_offer_v1',
            'id': _id,
            'offer': _offer!.offer,
          }),
        );
        void send() {
          if (_closed || _transferred) return;
          try {
            _socket.send(wire, address, port);
          } on SocketException {
            close();
          }
        }

        _retry = Timer.periodic(
          const Duration(milliseconds: 250),
          (_) => send(),
        );
        send();
      }
    } catch (error) {
      close(error);
    }
    return result.future;
  }

  void _read(RawSocketEvent event) {
    if (_closed || _transferred) return;
    if (event == RawSocketEvent.closed) {
      close();
      return;
    }
    if (event != RawSocketEvent.read) return;
    for (var i = 0; i < 32 && !_closed && !_transferred; i++) {
      final packet = _socket.receive();
      if (packet == null) break;
      if (packet.address.address != address.address ||
          packet.port != port ||
          packet.data.length > 4096) {
        continue;
      }
      try {
        if (_generation != MemberQrMemory.generation) {
          close();
          return;
        }
        final text = utf8.decode(packet.data);
        final value = jsonDecode(text);
        if (value is! Map<String, dynamic>) continue;
        if (_offer != null &&
            value['kind'] == 'kingclub_nearby_answer_v1' &&
            value['id'] == _id &&
            value['response'] is Map<String, dynamic>) {
          final channel = identity.complete(
            _offer!,
            value['response'] as Map<String, dynamic>,
          );
          _offer = null;
          _handoff(channel);
        } else if (identity.peerId.compareTo(expectedPeer) > 0 &&
            value['kind'] == 'kingclub_nearby_offer_v1' &&
            value['id'] is String &&
            (value['id'] as String).length == 36 &&
            value['offer'] is Map<String, dynamic>) {
          final accepted = identity.respond(
            value['offer'] as Map<String, dynamic>,
            expectedPeer: expectedPeer,
          );
          final wire = utf8.encode(
            jsonEncode({
              'kind': 'kingclub_nearby_answer_v1',
              'id': value['id'],
              'response': accepted.response,
            }),
          );
          final until = DateTime.now().add(const Duration(seconds: 10));
          void resend(Datagram retry) {
            if (DateTime.now().isAfter(until)) return;
            try {
              if (utf8.decode(retry.data) == text) {
                _socket.send(wire, address, port);
              }
            } on FormatException {
              return;
            } on SocketException {
              return;
            }
          }

          // Attach first so follow-up encrypted data cannot be consumed here.
          _handoff(accepted.channel, onControl: resend);
          resend(packet);
        }
      } on FormatException {
        continue;
      } on StateError {
        continue;
      }
    }
  }

  void _handoff(
    NovoRudpSecureChannel channel, {
    void Function(Datagram)? onControl,
  }) {
    final link = NovoRudpSecureDatagramLink.attach(
      socket: _socket,
      peer: address,
      peerPort: port,
      channel: channel,
      existingEvents: _events,
      onControlPacket: onControl,
    );
    _transferred = true;
    _retry?.cancel();
    _deadline?.cancel();
    unawaited(_session?.cancel());
    _result!.complete(link);
  }

  void close([Object? error]) {
    if (_closed || _transferred) return;
    _closed = true;
    _retry?.cancel();
    _deadline?.cancel();
    if (_offer != null) {
      try {
        identity.cancel(_offer!);
      } on StateError {
        /* Already released by native completion or logout. */
      }
    }
    _socket.close();
    unawaited(_events?.cancel());
    unawaited(_session?.cancel());
    if (_result != null && !_result!.isCompleted) {
      _result!.completeError(error ?? StateError('Nearby connector closed'));
    }
  }
}
