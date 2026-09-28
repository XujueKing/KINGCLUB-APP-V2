import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

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
  test(
    'foreground heartbeat encrypts payload with independent outbound sequence',
    () async {
      final c = codec();
      final frame = jsonDecode(await c.foregroundHeartbeat()) as Map;
      expect(frame['seq'], 1);
      expect(frame['eventType'], 'client.foreground');
      final session = fixture['session'] as Map;
      final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(utf8.encode(session['apiKey'] as String)),
        nonce: utf8.encode('1789200000000:fixture-nonce'),
        info: utf8.encode('ccsop:websocket:client-to-server:fixture-request'),
      );
      List<int> decode(String value) =>
          base64Url.decode(base64Url.normalize(value));
      final data = frame['data'] as Map;
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          decode(data['ciphertext'] as String),
          nonce: decode(data['iv'] as String),
          mac: Mac(decode(data['tag'] as String)),
        ),
        secretKey: key,
      );
      expect(jsonDecode(utf8.decode(clear)), {'active': true});
      await c.decode(jsonEncode(fixture['frame']));
      expect((jsonDecode(await c.foregroundHeartbeat()) as Map)['seq'], 2);
    },
  );
  test(
    'call receipts share heartbeat sequence and keep IDs encrypted',
    () async {
      final c = codec();
      await c.foregroundHeartbeat();
      final raw = await c.encode('client.callNoticeShown', {
        'scope': 'direct',
        'callId': 'private-call-id',
      });
      final frame = jsonDecode(raw) as Map;
      expect(frame['seq'], 2);
      expect(frame['eventType'], 'client.callNoticeShown');
      expect(raw, isNot(contains('private-call-id')));
      expect((jsonDecode(await c.foregroundHeartbeat()) as Map)['seq'], 3);
    },
  );
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
