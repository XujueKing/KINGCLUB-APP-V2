import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  test(
    'upstream signed discovery and punch verify identity, nonce and content',
    () {
      final library = DynamicLibrary.open(path!);
      final a = NovoRudpSecureSession.fromSeed(
        library: library,
        seed: Uint8List.fromList(List.filled(32, 17)),
      );
      final b = NovoRudpSecureSession.fromSeed(
        library: library,
        seed: Uint8List.fromList(List.filled(32, 29)),
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      for (final punch in [false, true]) {
        final probe = a.natProbe(targetPeer: punch ? b.peerId : null);
        final ack = b.respondNat(
          probe.packet,
          expectedPeer: a.peerId,
          observedEndpoint: '127.0.0.1:49152',
        );
        expect(
          a.validateNat(probe, ack, expectedPeer: b.peerId),
          '127.0.0.1:49152',
        );
        expect(
          () => a.validateNat(probe, ack, expectedPeer: a.peerId),
          throwsStateError,
        );
        expect(
          () => b.validateNat(probe, ack, expectedPeer: b.peerId),
          throwsStateError,
        );
        final other = a.natProbe(targetPeer: punch ? b.peerId : null);
        expect(
          () => a.validateNat(other, ack, expectedPeer: b.peerId),
          throwsStateError,
        );
        expect(
          () => b.respondNat(
            probe.packet,
            expectedPeer: b.peerId,
            observedEndpoint: '127.0.0.1:49152',
          ),
          throwsStateError,
        );
        final body = ack['body'] as Map<String, dynamic>;
        (body['signature'] as List)[0] ^= 1;
        expect(
          () => a.validateNat(probe, ack, expectedPeer: b.peerId),
          throwsStateError,
        );
        // Callers cannot mutate the retained signed request through its getter.
        final copy = probe.packet;
        (copy['body'] as Map<String, dynamic>)['version'] = 99;
        final valid = b.respondNat(
          probe.packet,
          expectedPeer: a.peerId,
          observedEndpoint: '[::1]:49153',
        );
        expect(
          a.validateNat(probe, valid, expectedPeer: b.peerId),
          '[::1]:49153',
        );
      }
      final wrongTarget = a.natProbe(targetPeer: a.peerId);
      expect(
        () => b.respondNat(
          wrongTarget.packet,
          expectedPeer: a.peerId,
          observedEndpoint: '127.0.0.1:49152',
        ),
        throwsStateError,
      );
    },
    skip: path == null ? 'Requires real native library' : false,
  );
}
