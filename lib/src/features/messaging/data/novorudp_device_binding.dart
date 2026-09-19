import 'dart:ffi';
import 'dart:typed_data';

import '../../../core/session/member_qr_memory.dart';
import '../../auth/domain/auth_repository.dart';
import 'messaging_repository.dart';
import 'group_file_device_scope.dart';
import 'nearby_peer_identity_store.dart';
import 'novorudp_device_identity_store.dart';
import 'novorudp_secure_session.dart';

final _hexKey = RegExp(r'^[a-f0-9]{64}$');
final _uuid = RegExp(
  r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
);

class NetworkDeviceKey {
  NetworkDeviceKey._(this.bindingId, this.publicKey);
  final String bindingId, publicKey;
  String get peerId => 'novovm-ed25519:$publicKey';
  factory NetworkDeviceKey.parse(dynamic raw) {
    if (raw is! Map ||
        raw['bindingId'] is! String ||
        raw['publicKey'] is! String ||
        !_uuid.hasMatch(raw['bindingId'] as String) ||
        !_hexKey.hasMatch(raw['publicKey'] as String) ||
        raw['peerId'] != 'novovm-ed25519:${raw['publicKey']}') {
      throw const FormatException('Invalid device key directory entry');
    }
    return NetworkDeviceKey._(
      raw['bindingId'] as String,
      raw['publicKey'] as String,
    );
  }
}

/// Server-verified membership binding around one locally persisted identity.
/// Production callers use open(); injected sessions are for embedding/tests.
/// It does not start a UDP lane or silently rotate a revoked/lost device key.
class BoundNetworkHandshake {
  BoundNetworkHandshake._(
    this._binding,
    this.peer,
    this.key,
    this._native, [
    this._verifyScope,
  ]);
  final Future<void> Function()? _verifyScope;
  final NovoRudpDeviceBinding _binding;
  final String peer;
  final NetworkDeviceKey key;
  final NovoRudpHandshake _native;
  Map<String, dynamic> get offer => _native.offer;
  bool _closed = false, _completing = false;

  Future<NovoRudpSecureChannel> complete(Map<String, dynamic> response) async {
    if (_closed || _completing) throw StateError('Handshake closed');
    _completing = true;
    var nativeAttempted = false;
    try {
      if (_verifyScope != null) {
        await _verifyScope();
      } else {
        await _binding._requirePeerKey(peer, key.bindingId, key.publicKey);
      }
      if (_closed) throw StateError('Handshake cancelled');
      nativeAttempted = true;
      return _binding.identity.complete(_native, response);
    } catch (error) {
      if (error is! AuthFailure || error.code != 'NETWORK_ERROR') {
        _closed = true;
      }
      rethrow;
    } finally {
      _completing = false;
      if (nativeAttempted) _closed = true;
      if (_closed) {
        try {
          _binding.identity.cancel(_native);
        } catch (_) {}
      }
    }
  }

  void cancel() {
    if (_closed) return;
    _closed = true;
    try {
      _binding.identity.cancel(_native);
    } catch (_) {}
  }
}

class NovoRudpDeviceBinding {
  NovoRudpDeviceBinding({
    required this.messaging,
    required this.identity,
    this.offlineIdentities,
  }) : _publicKey = identity.peerId.substring('novovm-ed25519:'.length);
  static Future<NovoRudpDeviceBinding> open({
    required DynamicLibrary library,
  }) async {
    final generation = MemberQrMemory.generation;
    final messaging = await MessagingRepository.open();
    final identity = await NovoRudpDeviceIdentityStore().open(
      account: messaging.account,
      library: library,
    );
    if (generation != MemberQrMemory.generation) {
      identity.dispose();
      throw StateError('Device binding session changed');
    }
    return NovoRudpDeviceBinding(
      messaging: messaging,
      identity: identity,
      offlineIdentities: NearbyPeerIdentityStore(
        account: messaging.account,
        ownPeerId: identity.peerId,
      ),
    );
  }

  final NearbyPeerIdentityStore? offlineIdentities;
  final MessagingRepository messaging;
  final NovoRudpSecureSession identity;
  final String _publicKey;
  final int _generation = MemberQrMemory.generation;
  bool _disposed = false, _revoked = false;
  Future<NetworkDeviceKey>? _binding;
  Map<String, dynamic>? _pending;
  Stopwatch? _challengeAge;

  void _check({bool revoking = false}) {
    if (_disposed || _generation != MemberQrMemory.generation) {
      dispose();
      throw StateError('Device binding session ended');
    }
    if (_revoked && !revoking) throw StateError('Device key revoked');
    if (!revoking) identity.peerId; // Also checks native/session ownership.
  }

  Future<Map<String, dynamic>> _call(
    String id,
    Map<String, dynamic> params, {
    bool revoking = false,
  }) async {
    _check(revoking: revoking);
    final result = await messaging.call(id, params);
    _check(revoking: revoking);
    return result;
  }

  Future<NetworkDeviceKey> _requirePeerKey(
    String peer,
    String bindingId, [
    String? expectedPublicKey,
  ]) async {
    if (peer == messaging.account) {
      throw ArgumentError('Peer must be another member');
    }
    await ensureRegistered();
    final keys = await directory(peer);
    _check();
    for (final key in keys) {
      if (key.bindingId == bindingId &&
          (expectedPublicKey == null || key.publicKey == expectedPublicKey)) {
        return key;
      }
    }
    throw const AuthFailure(
      'NETWORK_KEY_DENIED',
      'Peer device binding unavailable',
    );
  }

  Future<BoundNetworkHandshake> startPeer(String peer, String bindingId) async {
    final key = await _requirePeerKey(peer, bindingId);
    return BoundNetworkHandshake._(this, peer, key, identity.start(key.peerId));
  }

  /// Revalidates an established channel against live membership and the exact
  /// public key authenticated during its handshake.
  Future<void> verifyPeer(String peer, NetworkDeviceKey key) async {
    await _requirePeerKey(peer, key.bindingId, key.publicKey);
  }

  Future<({NovoRudpSecureChannel channel, Map<String, dynamic> response})>
  respondPeer(String peer, String bindingId, Map<String, dynamic> offer) async {
    final key = await _requirePeerKey(peer, bindingId);
    return identity.respond(offer, expectedPeer: key.peerId);
  }

  Future<({GroupFileDeviceScope scope, List<NetworkDeviceKey> keys})>
  groupFileDirectory(
    String peer, {
    required String messageId,
    required String groupId,
    String? media,
  }) async {
    if (peer == messaging.account) {
      throw ArgumentError('Peer must be another member');
    }
    final result = await _call('K260915000672', {
      'peer': peer,
      'groupFileMessageId': messageId,
      'media': ?media,
    });
    if (result['peer'] != peer) {
      throw const FormatException('Group file owner mismatch');
    }
    final scope = GroupFileDeviceScope.parse(
      result['scope'],
      messageId: messageId,
      groupId: groupId,
      media: media,
      account: messaging.account,
      peer: peer,
    );
    final keys = _directoryKeys(result);
    _check();
    return (scope: scope, keys: keys);
  }

  Future<NetworkDeviceKey> _requireGroupFileKey(
    String peer,
    String bindingId,
    GroupFileDeviceScope scope, [
    String? publicKey,
  ]) async {
    await ensureRegistered();
    final current = await groupFileDirectory(
      peer,
      messageId: scope.messageId,
      groupId: scope.groupId,
      media: scope.media,
    );
    if (!scope.samePermission(current.scope)) {
      throw const AuthFailure(
        'NETWORK_KEY_DENIED',
        'Group file membership changed',
      );
    }
    for (final key in current.keys) {
      if (key.bindingId == bindingId &&
          (publicKey == null || key.publicKey == publicKey)) {
        return key;
      }
    }
    throw const AuthFailure(
      'NETWORK_KEY_DENIED',
      'Group file device unavailable',
    );
  }

  Future<BoundNetworkHandshake> startGroupFilePeer(
    String peer,
    String bindingId,
    GroupFileDeviceScope scope,
  ) async {
    final key = await _requireGroupFileKey(peer, bindingId, scope);
    return BoundNetworkHandshake._(
      this,
      peer,
      key,
      identity.start(key.peerId),
      () => verifyGroupFilePeer(peer, key, scope),
    );
  }

  Future<void> verifyGroupFilePeer(
    String peer,
    NetworkDeviceKey key,
    GroupFileDeviceScope scope,
  ) async {
    await _requireGroupFileKey(peer, key.bindingId, scope, key.publicKey);
  }

  Future<({NovoRudpSecureChannel channel, Map<String, dynamic> response})>
  respondGroupFilePeer(
    String peer,
    String bindingId,
    GroupFileDeviceScope scope,
    Map<String, dynamic> offer,
  ) async {
    final key = await _requireGroupFileKey(peer, bindingId, scope);
    return identity.respond(offer, expectedPeer: key.peerId);
  }

  static String _nativeSession(Map<String, dynamic> offer) {
    final bytes = offer['session_id'];
    if (bytes is! List ||
        bytes.length != 16 ||
        bytes.any((v) => v is! int || v < 0 || v > 255)) {
      throw const FormatException('Invalid native handshake session');
    }
    return bytes
        .map((v) => (v as int).toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static void _checkContextExpiry(Object? expiry) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiry is! int || expiry <= now || expiry > now + 47000) {
      throw const FormatException('Expired group handshake context');
    }
  }

  Future<void> publishGroupFileHandshake(
    String peer,
    NetworkDeviceKey key,
    GroupFileDeviceScope scope,
    Map<String, dynamic> offer,
  ) async {
    final session = _nativeSession(offer);
    if (offer['initiator_peer_id'] != identity.peerId ||
        offer['responder_peer_id'] != key.peerId) {
      throw const FormatException('Group handshake identity mismatch');
    }
    await verifyGroupFilePeer(peer, key, scope);
    final own = await ensureRegistered();
    final result = await _call('K260918000709', {
      'operation': 'publish',
      'peer': peer,
      'ownBindingId': own.bindingId,
      'peerBindingId': key.bindingId,
      'messageId': scope.messageId,
      'media': ?scope.media,
      'nativeSessionId': session,
    });
    if (result['published'] != true) {
      throw const FormatException('Group handshake not published');
    }
    _checkContextExpiry(result['expiresAt']);
  }

  Future<({String peer, NetworkDeviceKey key, GroupFileDeviceScope scope})>
  resolveGroupFileHandshake(
    String sourcePeerId,
    Map<String, dynamic> offer,
  ) async {
    final session = _nativeSession(offer);
    if (!RegExp(r'^novovm-ed25519:[a-f0-9]{64}$').hasMatch(sourcePeerId) ||
        offer['initiator_peer_id'] != sourcePeerId ||
        offer['responder_peer_id'] != identity.peerId) {
      throw const FormatException('Group handshake source mismatch');
    }
    final result = await _call('K260918000709', {
      'operation': 'resolve',
      'sourcePeerId': sourcePeerId,
      'nativeSessionId': session,
    });
    final peer = result['peer'],
        bindingId = result['peerBindingId'],
        raw = result['scope'];
    if (peer is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(peer) ||
        peer == messaging.account ||
        bindingId is! String ||
        !_uuid.hasMatch(bindingId) ||
        result['sourcePeerId'] != sourcePeerId ||
        result['nativeSessionId'] != session ||
        raw is! Map ||
        raw['messageId'] is! String ||
        raw['groupId'] is! String) {
      throw const FormatException('Invalid resolved group handshake');
    }
    _checkContextExpiry(result['expiresAt']);
    final scope = GroupFileDeviceScope.parse(
      raw,
      messageId: raw['messageId'],
      groupId: raw['groupId'],
      media: raw['media'] as String?,
      account: messaging.account,
      peer: peer,
    );
    final key = await _requireGroupFileKey(
      peer,
      bindingId,
      scope,
      sourcePeerId.substring('novovm-ed25519:'.length),
    );
    _checkContextExpiry(result['expiresAt']);
    return (peer: peer, key: key, scope: scope);
  }

  Future<List<NetworkDeviceKey>> directory(String peer) async {
    final result = await _call('K260915000672', {'peer': peer});
    final keys = _directoryKeys(result);
    // Historical observations are not cached authorization.
    try {
      await offlineIdentities?.save(
        peer,
        keys.map((key) => key.peerId).toList(),
      );
    } catch (_) {}
    _check();
    return keys;
  }

  /// Finds the member behind an incoming relay identity. Server checks live
  /// mutual friendship/blocking; the subsequent handshake still verifies keys.
  Future<({String peer, NetworkDeviceKey key})> resolvePeer(
    String peerId,
  ) async {
    if (!RegExp(r'^novovm-ed25519:[a-f0-9]{64}$').hasMatch(peerId)) {
      throw ArgumentError('Invalid peer identity');
    }
    final result = await _call('K260915000672', {'peerId': peerId});
    final peer = result['peer'];
    if (peer is! String ||
        peer == messaging.account ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(peer)) {
      throw const FormatException('Invalid resolved member');
    }
    final keys = _directoryKeys(result).where((key) => key.peerId == peerId);
    if (keys.length != 1) throw const FormatException('Resolved key mismatch');
    _check();
    return (peer: peer, key: keys.single);
  }

  List<NetworkDeviceKey> _directoryKeys(Map<String, dynamic> result) {
    final raw = result['keys'];
    if (raw is! List || raw.length > 8 || result['cacheSeconds'] != 0) {
      throw const FormatException('Invalid device key directory');
    }
    final keys = raw.map(NetworkDeviceKey.parse).toList(growable: false);
    if (keys.map((k) => k.bindingId).toSet().length != keys.length ||
        keys.map((k) => k.publicKey).toSet().length != keys.length) {
      throw const FormatException('Duplicate device key binding');
    }
    return List.unmodifiable(keys);
  }

  Future<NetworkDeviceKey> ensureRegistered() async {
    _check();
    final running = _binding ??= _register();
    try {
      return await running;
    } finally {
      if (identical(_binding, running)) _binding = null;
    }
  }

  Future<NetworkDeviceKey> _register() async {
    // Re-read on each operation. A previous local success cannot override a
    // later server revocation, and a lost registration response is recoverable.
    for (final key in await directory(messaging.account)) {
      if (key.publicKey == _publicKey) return key;
    }
    if (_pending == null ||
        _challengeAge!.elapsed >= const Duration(seconds: 75)) {
      _pending = null;
      final age = Stopwatch()..start();
      final challenge = await _call('K260915000670', {'publicKey': _publicKey});
      final issued = challenge['issuedAt'], expires = challenge['expiresAt'];
      if (challenge['publicKey'] != _publicKey ||
          challenge['challengeId'] is! String ||
          !_uuid.hasMatch(challenge['challengeId'] as String) ||
          challenge['scopeHash'] is! String ||
          !_hexKey.hasMatch(challenge['scopeHash'] as String) ||
          challenge['nonce'] is! String ||
          !_hexKey.hasMatch(challenge['nonce'] as String) ||
          issued is! int ||
          expires is! int ||
          issued < 0 ||
          expires - issued != 90000) {
        throw const FormatException('Invalid device binding challenge');
      }
      _check();
      Uint8List bytes(String hex) => Uint8List.fromList([
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ]);
      final signature = identity.bindingProof(
        scope: bytes(challenge['scopeHash'] as String),
        nonce: bytes(challenge['nonce'] as String),
      );
      _pending = {
        'challengeId': challenge['challengeId'],
        'signature': signature
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(),
      };
      _challengeAge = age;
    }
    try {
      final result = NetworkDeviceKey.parse(
        await _call('K260915000671', _pending!),
      );
      if (result.publicKey != _publicKey) {
        throw const FormatException(
          'Registered key differs from local identity',
        );
      }
      _pending = null;
      return result;
    } on AuthFailure catch (error) {
      if (error.code == 'NETWORK_KEY_PROOF_INVALID') _pending = null;
      rethrow;
    }
  }

  Future<void> revoke(NetworkDeviceKey binding) async {
    _check(revoking: true);
    if (binding.publicKey != _publicKey) {
      throw ArgumentError('Different device key');
    }
    _revoked = true;
    _pending = null;
    identity
        .dispose(); // Stop local channels even when server revocation retries.
    final result = await _call('K260915000673', {
      'bindingId': binding.bindingId,
    }, revoking: true);
    if (result['revoked'] != true) {
      throw const FormatException('Revocation was not confirmed');
    }
  }

  void dispose() {
    _disposed = true;
    _pending = null;
    identity.dispose();
  }
}
