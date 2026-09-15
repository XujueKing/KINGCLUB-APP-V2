import 'dart:convert';

import '../../../core/session/member_qr_memory.dart';
import 'messaging_repository.dart';

final _uuid = RegExp(
  r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
);
String _payload(Map<String, dynamic> value) {
  final encoded = jsonEncode(value);
  if (utf8.encode(encoded).length > 8192) {
    throw ArgumentError('Handshake payload too large');
  }
  return encoded;
}

Object? _ordered(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _ordered(value[key])};
  }
  if (value is List) return value.map(_ordered).toList();
  return value;
}

bool _same(Map<String, dynamic> a, Map<String, dynamic> b) =>
    jsonEncode(_ordered(a)) == jsonEncode(_ordered(b));

class NetworkExchange {
  NetworkExchange._(
    this.id,
    this.fromBindingId,
    this.toBindingId,
    this.expiresAtMs,
    this.cancelled,
    this._offer,
    this._answer,
  );
  final String id, fromBindingId, toBindingId, _offer;
  final String? _answer;
  final int expiresAtMs;
  final bool cancelled;
  Map<String, dynamic> get offer => jsonDecode(_offer) as Map<String, dynamic>;
  Map<String, dynamic>? get answer =>
      _answer == null ? null : jsonDecode(_answer) as Map<String, dynamic>;
  void requireUsable() {
    if (cancelled || expiresAtMs <= DateTime.now().millisecondsSinceEpoch) {
      throw StateError('Handshake exchange expired or cancelled');
    }
  }

  factory NetworkExchange.parse(Object? raw) {
    if (raw is! Map ||
        raw['exchangeId'] is! String ||
        !_uuid.hasMatch(raw['exchangeId'] as String) ||
        raw['fromBindingId'] is! String ||
        !_uuid.hasMatch(raw['fromBindingId'] as String) ||
        raw['toBindingId'] is! String ||
        !_uuid.hasMatch(raw['toBindingId'] as String) ||
        raw['fromBindingId'] == raw['toBindingId'] ||
        raw['expiresAtMs'] is! int ||
        raw['cancelled'] is! bool ||
        raw['offer'] is! Map ||
        (raw['answer'] != null && raw['answer'] is! Map)) {
      throw const FormatException('Invalid handshake exchange');
    }
    final expiry = raw['expiresAtMs'] as int;
    if (expiry <= 0 || expiry > DateTime.now().millisecondsSinceEpoch + 60000) {
      throw const FormatException('Invalid handshake expiry');
    }
    return NetworkExchange._(
      raw['exchangeId'] as String,
      raw['fromBindingId'] as String,
      raw['toBindingId'] as String,
      expiry,
      raw['cancelled'] as bool,
      _payload(Map<String, dynamic>.from(raw['offer'] as Map)),
      raw['answer'] == null
          ? null
          : _payload(Map<String, dynamic>.from(raw['answer'] as Map)),
    );
  }
}

/// Account/device-scoped 683 client. No sockets, capture, or implicit retry.
class NetworkRendezvousRepository {
  NetworkRendezvousRepository({
    required this.messaging,
    required this.peer,
    required this.ownBindingId,
    required this.peerBindingId,
  }) {
    if (peer == messaging.account ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(peer) ||
        !_uuid.hasMatch(ownBindingId) ||
        !_uuid.hasMatch(peerBindingId) ||
        ownBindingId == peerBindingId) {
      throw ArgumentError('Invalid handshake participants');
    }
  }
  final MessagingRepository messaging;
  final String peer, ownBindingId, peerBindingId;
  final int _generation = MemberQrMemory.generation;
  bool _closed = false;
  void close() => _closed = true;
  void _check() {
    if (_closed || _generation != MemberQrMemory.generation) {
      throw StateError('Handshake repository closed');
    }
  }

  Future<NetworkExchange?> _call(
    Map<String, dynamic> command, {
    String? id,
  }) async {
    _check();
    if (id != null && !_uuid.hasMatch(id)) {
      throw ArgumentError('Invalid exchange ID');
    }
    final result = await messaging.call('K260915000683', {
      'peer': peer,
      'ownBindingId': ownBindingId,
      'peerBindingId': peerBindingId,
      'command': command,
    });
    _check();
    if (!result.containsKey('exchange')) {
      throw const FormatException('Missing exchange');
    }
    if (result['exchange'] == null) {
      if (command['type'] != 'read') {
        throw StateError('Handshake exchange expired');
      }
      return null;
    }
    final exchange = NetworkExchange.parse(result['exchange']);
    if ((id != null && exchange.id != id) ||
        !((exchange.fromBindingId == ownBindingId &&
                exchange.toBindingId == peerBindingId) ||
            (exchange.fromBindingId == peerBindingId &&
                exchange.toBindingId == ownBindingId))) {
      throw const FormatException('Handshake exchange scope mismatch');
    }
    return exchange;
  }

  Future<NetworkExchange?> read() => _call({'type': 'read'});
  Future<NetworkExchange> offer(String id, Map<String, dynamic> payload) async {
    final copy = jsonDecode(_payload(payload)) as Map<String, dynamic>;
    final result = (await _call({
      'type': 'offer',
      'exchangeId': id,
      'payload': copy,
    }, id: id))!;
    result.requireUsable();
    if (result.fromBindingId != ownBindingId || !_same(result.offer, copy)) {
      throw const FormatException('Offer acknowledgement mismatch');
    }
    return result;
  }

  Future<NetworkExchange> answer(
    NetworkExchange exchange,
    Map<String, dynamic> payload,
  ) async {
    exchange.requireUsable();
    if (exchange.fromBindingId != peerBindingId ||
        exchange.toBindingId != ownBindingId) {
      throw StateError('Only the invited device may answer');
    }
    final copy = jsonDecode(_payload(payload)) as Map<String, dynamic>;
    final result = (await _call({
      'type': 'answer',
      'exchangeId': exchange.id,
      'payload': copy,
    }, id: exchange.id))!;
    result.requireUsable();
    if (result.fromBindingId != peerBindingId ||
        result.answer == null ||
        !_same(result.offer, exchange.offer) ||
        !_same(result.answer!, copy) ||
        result.expiresAtMs != exchange.expiresAtMs) {
      throw const FormatException('Answer acknowledgement mismatch');
    }
    return result;
  }

  Future<void> cancel(String id) async {
    final result = (await _call({'type': 'cancel', 'exchangeId': id}, id: id))!;
    if (!result.cancelled) {
      throw const FormatException('Cancellation not acknowledged');
    }
  }
}
