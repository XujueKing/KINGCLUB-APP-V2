import 'dart:ffi';
import 'dart:typed_data';

import '../../../core/session/member_qr_memory.dart';
import '../../auth/domain/auth_repository.dart';
import 'messaging_repository.dart';
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
  BoundNetworkHandshake._(this._binding, this.peer, this.key, this._native);
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
      await _binding._requirePeerKey(peer, key.bindingId, key.publicKey);
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

  Future<List<NetworkDeviceKey>> directory(String peer) async {
    final result = await _call('K260915000672', {'peer': peer});
    final raw = result['keys'];
    if (raw is! List || raw.length > 8 || result['cacheSeconds'] != 0) {
      throw const FormatException('Invalid device key directory');
    }
    final keys = raw.map(NetworkDeviceKey.parse).toList(growable: false);
    if (keys.map((k) => k.bindingId).toSet().length != keys.length ||
        keys.map((k) => k.publicKey).toSet().length != keys.length) {
      throw const FormatException('Duplicate device key binding');
    }
    // Historical key observations do not change the API's cacheSeconds=0
    // authorization contract. Storage failure must not break online chat.
    try {
      await offlineIdentities?.save(
        peer,
        keys.map((key) => key.peerId).toList(),
      );
    } catch (_) {
      /* Offline observation unavailable; live authorization remains authoritative. */
    }
    _check();
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
