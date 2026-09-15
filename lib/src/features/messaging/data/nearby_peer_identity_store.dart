import 'dart:convert';

import 'package:cryptography/dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/session/member_qr_memory.dart';

/// Historical identity observations, NOT cached permission to send messages.
/// Account, own device key and peer account are independently scoped.
class NearbyPeerIdentityStore {
  NearbyPeerIdentityStore({
    required this.account,
    required this.ownPeerId,
    FlutterSecureStorage? storage,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(
               storageNamespace: 'kingclub_novorudp_identity',
               resetOnError: false,
             ),
             iOptions: IOSOptions(
               accountName: 'kingclub_novorudp_identity',
               accessibility: KeychainAccessibility.unlocked_this_device,
               synchronizable: false,
             ),
           ) {
    if (account.isEmpty || !_peerId.hasMatch(ownPeerId)) {
      throw ArgumentError('Invalid identity scope');
    }
  }
  static final _peerId = RegExp(r'^novovm-ed25519:[0-9a-f]{64}$');
  final String account, ownPeerId;
  final FlutterSecureStorage _storage;
  final int _generation = MemberQrMemory.generation;
  Future<void> _tail = Future.value();
  void _check() {
    if (_generation != MemberQrMemory.generation) {
      throw StateError('Identity observation session changed');
    }
  }

  Future<String> _key(String peer) async {
    _check();
    if (peer.isEmpty || peer == account) {
      throw ArgumentError('Invalid peer account');
    }
    final hash = await const DartSha256().hash(
      utf8.encode(jsonEncode([account, ownPeerId, peer])),
    );
    _check();
    return 'nearby.observed.v1.${base64UrlEncode(hash.bytes)}';
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) {
      _check();
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> save(String peer, List<String> peerIds) => _serial(() async {
    if (peerIds.length > 8 ||
        peerIds.toSet().length != peerIds.length ||
        peerIds.any((id) => !_peerId.hasMatch(id))) {
      throw ArgumentError('Invalid verified peer identities');
    }
    final key = await _key(peer);
    await _storage.write(
      key: key,
      value: jsonEncode({
        'version': 1,
        'account': account,
        'ownPeerId': ownPeerId,
        'peer': peer,
        'observedAt': DateTime.now().millisecondsSinceEpoch,
        'peerIds': peerIds,
      }),
    );
    _check();
  });
  Future<({List<String> peerIds, DateTime observedAt})?> read(String peer) =>
      _serial(() async {
        final key = await _key(peer);
        final raw = await _storage.read(key: key);
        _check();
        if (raw == null) return null;
        final value = jsonDecode(raw);
        if (value is! Map ||
            value['version'] != 1 ||
            value['account'] != account ||
            value['ownPeerId'] != ownPeerId ||
            value['peer'] != peer ||
            value['peerIds'] is! List ||
            value['observedAt'] is! int) {
          throw const FormatException('Invalid identity observation');
        }
        final ids = (value['peerIds'] as List).cast<String>();
        final stamp = value['observedAt'] as int;
        if (ids.length > 8 ||
            ids.toSet().length != ids.length ||
            ids.any((id) => !_peerId.hasMatch(id)) ||
            stamp < 1 ||
            stamp > DateTime.now().millisecondsSinceEpoch) {
          throw const FormatException('Invalid identity observation');
        }
        return (
          peerIds: List<String>.unmodifiable(ids),
          observedAt: DateTime.fromMillisecondsSinceEpoch(stamp),
        );
      });
}
