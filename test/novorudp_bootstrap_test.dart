import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_directory.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  test(
    'upstream multisignature bootstrap populates authorized relay directory',
    () {
      final lib = DynamicLibrary.open(path!);
      final a = NovoRudpSecureSession.fromSeed(
        library: lib,
        seed: Uint8List.fromList(List.filled(32, 91)),
      );
      final b = NovoRudpSecureSession.fromSeed(
        library: lib,
        seed: Uint8List.fromList(List.filled(32, 92)),
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final record = a.signRelayRecord(
        recordId: 'relay-record',
        sequence: 1,
        endpoints: [
          {
            'transport': 'udp',
            'uri': 'udp://127.0.0.1:45123',
            'priority': 1,
            'max_sessions': 2,
            'max_bytes_per_minute': 65536,
          },
        ],
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      var manifest = a.signBootstrapManifest({
        'version': 1,
        'manifest_id': 'test-bootstrap',
        'issued_at_ms': now,
        'expires_at_ms': now + 30000,
        'candidate_limit': 1,
        'full_raw_ip_directory_embedded': false,
        'requires_single_official_relay': false,
        'requires_single_official_domain': false,
        'relay_records': [record],
        'signatures': [],
      });
      NovoRudpRelayDirectory open() => NovoRudpRelayDirectory.fromManifest(
        identity: a,
        manifest: manifest,
        trustedSignerPeerIds: {a.peerId, b.peerId},
        minimumSignatures: 2,
      );
      expect(open, throwsStateError);
      manifest = b.signBootstrapManifest(manifest);
      final directory = open();
      addTearDown(directory.close);
      expect(directory.candidates.single['relay_peer_id'], a.peerId);
      expect(directory.trustedUntil!.millisecondsSinceEpoch, now + 30000);
      expect(
        () => a.validateBootstrapManifest(
          manifest,
          trustedSignerPeerIds: {a.peerId},
          minimumSignatures: 2,
        ),
        throwsStateError,
      );
      manifest['expires_at_ms'] = now + 60000;
      expect(open, throwsStateError);
      final expired = NovoRudpRelayDirectory(
        identity: a,
        trustedPeers: {a.peerId},
        trustedUntil: DateTime.fromMillisecondsSinceEpoch(now - 1),
      );
      expect(() => expired.accept(record), throwsStateError);
      expired.close();
    },
    skip: path == null ? 'Requires real native library' : false,
  );
}
