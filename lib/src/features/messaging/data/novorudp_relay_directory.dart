import 'dart:async';
import 'dart:convert';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_secure_session.dart';

/// Small, session-scoped cache of authorized signed relay advertisements.
/// Records describe candidates, not proof of connectivity or permission to relay.
class NovoRudpRelayDirectory {
  NovoRudpRelayDirectory({
    required this.identity,
    required Set<String> trustedPeers,
    this.capacity = 16,
  }) : _trustedPeers = Set.unmodifiable(trustedPeers) {
    if (capacity < 1 || capacity > 32 || trustedPeers.length > 128) {
      throw ArgumentError('Mobile relay directory limits exceeded');
    }
    _session = SecureSessionStore.changes.stream.listen((_) => close());
  }
  final NovoRudpSecureSession identity;
  final int capacity;
  final Set<String> _trustedPeers;
  final _records = <String, String>{};
  final int _generation = MemberQrMemory.generation;
  late final StreamSubscription<void> _session;
  bool _closed = false;

  void _check() {
    if (_closed || _generation != MemberQrMemory.generation) {
      close();
      throw StateError('Relay directory closed');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    _records.removeWhere(
      (_, value) => (jsonDecode(value)['expires_at_ms'] as int) <= now,
    );
  }

  void accept(Map<String, dynamic> record) {
    _check();
    final peer = record['relay_peer_id'];
    if (peer is! String || !_trustedPeers.contains(peer)) {
      throw StateError('Relay is not authorized by the bootstrap trust source');
    }
    final verified = identity.validateRelayRecord(record, expectedPeer: peer);
    final existing = _records[peer];
    if (existing != null) {
      final previous = jsonDecode(existing) as Map<String, dynamic>;
      final oldSequence = previous['sequence'] as int;
      final sequence = verified['sequence'] as int;
      if (sequence < oldSequence) throw StateError('Stale relay record');
      if (sequence == oldSequence) {
        // Signature is over canonical upstream fields, independent of JSON order.
        if (jsonEncode(previous['signature']) !=
            jsonEncode(verified['signature'])) {
          throw StateError('Conflicting relay record sequence');
        }
        return;
      }
    } else if (_records.length >= capacity) {
      throw StateError('Mobile relay directory full');
    }
    _records[peer] = jsonEncode(verified);
  }

  List<Map<String, dynamic>> get candidates {
    _check();
    return _records.values
        .map((value) => jsonDecode(value) as Map<String, dynamic>)
        .toList(growable: false);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _records.clear();
    unawaited(_session.cancel());
  }
}
