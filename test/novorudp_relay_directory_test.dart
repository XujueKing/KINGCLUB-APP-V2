import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_directory.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  test('real signed relay records enforce trust, capacity, sequence and tamper rejection', () {
    final lib = DynamicLibrary.open(path!);
    final a = NovoRudpSecureSession.fromSeed(
      library: lib,
      seed: Uint8List.fromList(List.filled(32, 12)),
    );
    final b = NovoRudpSecureSession.fromSeed(
      library: lib,
      seed: Uint8List.fromList(List.filled(32, 13)),
    );
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    Map<String, dynamic> record(
      NovoRudpSecureSession owner,
      int sequence, {
      int port = 45123,
    }) => owner.signRelayRecord(
      recordId: 'test-record',
      sequence: sequence,
      endpoints: [
        {
          'transport': 'udp',
          'uri': 'udp://127.0.0.1:$port',
          'priority': 1,
          'max_sessions': 2,
          'max_bytes_per_minute': 65536,
        },
      ],
    );
    final cache = NovoRudpRelayDirectory(
      identity: a,
      trustedPeers: {a.peerId, b.peerId},
      capacity: 1,
    );
    addTearDown(cache.close);
    final first = record(b, 1);
    cache.accept(first);
    cache.accept(first);
    expect(cache.candidates.length, 1);
    expect(() => cache.accept(record(a, 1)), throwsStateError);
    cache.accept(record(b, 2));
    expect(() => cache.accept(first), throwsStateError);
    expect(() => cache.accept(record(b, 2, port: 45124)), throwsStateError);
    final copied = cache.candidates.single;
    copied['expires_at_ms'] = 0;
    expect(cache.candidates.single['expires_at_ms'], greaterThan(0));
    final bad = record(b, 3);
    (bad['signature'] as List)[0] ^= 1;
    expect(() => cache.accept(bad), throwsStateError);
    expect(
      () => a.validateRelayRecord(first, expectedPeer: a.peerId),
      throwsStateError,
    );
    final untrusted = NovoRudpRelayDirectory(identity: a, trustedPeers: {});
    addTearDown(untrusted.close);
    expect(() => untrusted.accept(first), throwsStateError);
    cache.close();
    expect(() => cache.candidates, throwsStateError);
  }, skip: path == null ? 'Requires real native library' : false);
}
