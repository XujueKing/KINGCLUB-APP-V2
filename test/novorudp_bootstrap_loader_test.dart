import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_bootstrap_loader.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  final library = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  late NovoRudpSecureSession identity;
  late Map<String, dynamic> manifest;
  setUp(() {
    if (library == null) return;
    identity = NovoRudpSecureSession.fromSeed(
      library: DynamicLibrary.open(library),
      seed: Uint8List.fromList(List.filled(32, 101)),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    manifest = identity.signBootstrapManifest({
      'version': 1,
      'manifest_id': 'http-bootstrap',
      'issued_at_ms': now,
      'expires_at_ms': now + 30000,
      'candidate_limit': 1,
      'full_raw_ip_directory_embedded': false,
      'requires_single_official_relay': false,
      'requires_single_official_domain': false,
      'relay_records': [
        identity.signRelayRecord(
          recordId: 'http-relay',
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
        ),
      ],
      'signatures': [],
    });
    addTearDown(identity.dispose);
  });

  test(
    'real HTTP fails over timeout, redirect, oversized and forged sources',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final releaseSlow = Completer<void>();
      addTearDown(() {
        if (!releaseSlow.isCompleted) releaseSlow.complete();
      });
      final visits = <String>[];
      final forged = {
        ...manifest,
        'expires_at_ms': (manifest['issued_at_ms'] as int) + 60000,
      };
      server.listen((request) async {
        visits.add(request.uri.path);
        switch (request.uri.path) {
          case '/slow':
            await releaseSlow.future;
            break;
          case '/redirect':
            request.response.statusCode = 302;
            request.response.headers.set('location', '/must-not-follow');
            break;
          case '/large':
            request.response.add(List.filled(13000, 32));
            break;
          case '/forged':
            request.response.write(jsonEncode(forged));
            break;
          default:
            request.response.write(jsonEncode(manifest));
        }
        try {
          await request.response.close();
        } on IOException {
          /* client timed out */
        }
      });
      final loader = NovoRudpBootstrapLoader();
      addTearDown(loader.close);
      final base = 'http://127.0.0.1:${server.port}';
      final directory = await loader.load(
        identity: identity,
        sources: [
          'slow',
          'redirect',
          'large',
          'forged',
          'good',
        ].map((path) => Uri.parse('$base/$path')).toList(),
        trustedSignerPeerIds: {identity.peerId},
        minimumSignatures: 1,
        sourceTimeout: const Duration(milliseconds: 250),
      );
      addTearDown(directory.close);
      expect(directory.candidates.single['relay_peer_id'], identity.peerId);
      expect(visits, ['/slow', '/redirect', '/large', '/forged', '/good']);
      releaseSlow.complete();
      await expectLater(
        loader.load(
          identity: identity,
          sources: [Uri.parse('$base/forged')],
          trustedSignerPeerIds: {identity.peerId},
          minimumSignatures: 1,
        ),
        throwsStateError,
      );
    },
    skip: library == null ? 'Requires real native library' : false,
  );

  test('close aborts an actual pending request and rejects insecure remote sources', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requested = Completer<HttpRequest>();
    server.listen(requested.complete);
    final loader = NovoRudpBootstrapLoader();
    addTearDown(loader.close);
    await expectLater(
      loader.load(
        identity: identity,
        sources: [Uri.parse('http://192.168.1.5/bootstrap')],
        trustedSignerPeerIds: {identity.peerId},
        minimumSignatures: 1,
      ),
      throwsArgumentError,
    );
    final pending = loader.load(
      identity: identity,
      sources: [Uri.parse('http://127.0.0.1:${server.port}/wait')],
      trustedSignerPeerIds: {identity.peerId},
      minimumSignatures: 1,
    );
    final rejected = expectLater(pending, throwsStateError);
    final request = await requested.future.timeout(const Duration(seconds: 2));
    loader.close();
    await rejected.timeout(const Duration(seconds: 2));
    request.response.write(jsonEncode(manifest));
    try {
      await request.response.close();
    } on IOException {
      /* aborted client */
    }
  }, skip: library == null ? 'Requires real native library' : false);
}
