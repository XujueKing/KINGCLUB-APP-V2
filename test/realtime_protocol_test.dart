import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/networking/kingclub_realtime.dart';

void main() {
  final fixture = jsonDecode(
    File('test/realtime_protocol_fixture.json').readAsStringSync(),
  ) as Map;
  RealtimeCodec codec() => RealtimeCodec(
    Map<String, dynamic>.from(fixture['session'] as Map),
    'fixture-device',
    timestamp: '1789200000000',
    nonce: 'fixture-nonce',
    requestId: 'fixture-request',
  );
  test('handshake matches server and signs internal proxy path', () async {
    final uri = await codec().uri('https://fixture.invalid/kingclub-v2');
    expect(uri.scheme, 'wss');
    expect(uri.path, '/kingclub-v2/ws');
    expect(uri.queryParameters['sign'], fixture['sign']);
  });
  test('decrypts server event and rejects replay and tampering', () async {
    final c = codec();
    final raw = jsonEncode(fixture['frame']);
    final result = await c.decode(raw);
    expect(result['eventType'], 'storage.changed');
    expect(result['data']['notificationId'], 'fixture-event');
    await expectLater(c.decode(raw), throwsFormatException);
    final altered = Map<String, dynamic>.from(fixture['frame'] as Map)
      ..['eventType'] = 'auth.session.revoked';
    await expectLater(
      codec().decode(jsonEncode(altered)),
      throwsFormatException,
    );
  });
}
