import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  test('native domain-separated proof verifies with Dart Ed25519 and closes with session', () async {
    final session = NovoRudpSecureSession.fromSeed(
      library: DynamicLibrary.open(path!),
      seed: Uint8List.fromList(List.filled(32, 31)),
    );
    addTearDown(session.dispose);
    final hex = session.peerId.split(':').last;
    final public = [
      for (var i = 0; i < 64; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
    final scope = Uint8List.fromList(List.filled(32, 171));
    final nonce = Uint8List.fromList(List.filled(32, 205));
    final proof = session.bindingProof(scope: scope, nonce: nonce);
    final payload = [
      ...utf8.encode('kingclub-device-binding-v1\u0000'),
      ...scope,
      ...nonce,
      ...public,
    ];
    final signature = Signature(
      proof,
      publicKey: SimplePublicKey(public, type: KeyPairType.ed25519),
    );
    expect(await Ed25519().verify(payload, signature: signature), true);
    payload[0] ^= 1;
    expect(await Ed25519().verify(payload, signature: signature), false);
    expect(
      () => session.bindingProof(scope: Uint8List(31), nonce: nonce),
      throwsArgumentError,
    );
    session.dispose();
    expect(
      () => session.bindingProof(scope: scope, nonce: nonce),
      throwsStateError,
    );
  }, skip: path == null ? 'Set NOVORUDP_NATIVE_LIBRARY' : false);
}
