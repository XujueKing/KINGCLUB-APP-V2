import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_relay_configuration.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

const id = '00000000-0000-4000-8000-000000000001';
Map<String, dynamic> response(int expiry) => {
  'expiresAtMs': expiry,
  'iceServers': [
    {
      'urls': [
        'turn:relay.example:3478?transport=udp',
        'turns:relay.example:5349?transport=tcp',
      ],
      'username': '${expiry ~/ 1000}:0123456789abcdef0123456789abcdef',
      'credential': 'AAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    },
  ],
};
void main() {
  test('relay descriptors are deeply copied and immutable, call and expiry checked again before capture', () {
    final raw = response(600000);
    final config = CallRelayConfiguration.parse(id, raw, nowMs: 1000);
    final server = (raw['iceServers'] as List).single as Map;
    (server['urls'] as List).clear();
    server['credential'] = 'changed';
    expect((config.iceServers.single['urls'] as List).length, 2);
    expect(
      () => config.iceServers.single['credential'] = 'changed',
      throwsUnsupportedError,
    );
    expect(
      () =>
          (config.iceServers.single['urls'] as List).add('turn:other.example'),
      throwsUnsupportedError,
    );
    config.requireUsable(id, nowMs: 1000);
    expect(() => config.requireUsable(id, nowMs: 585000), throwsStateError);
    expect(
      () => config.requireUsable('other-call', nowMs: 1000),
      throwsStateError,
    );
  });
  test('invalid addresses, credentials and timestamp mismatches are rejected without exposing values', () {
    for (final url in [
      'https://relay.example',
      'turn:name:password@relay.example',
      'turn:relay.example:0',
      'turn:relay.example:65536',
      'turns:relay.example?transport=udp',
      'turn:relay.example/path',
    ]) {
      final raw = response(600000);
      ((raw['iceServers'] as List).single as Map)['urls'] = [url];
      expect(
        () => CallRelayConfiguration.parse(id, raw, nowMs: 1000),
        throwsFormatException,
      );
    }
    for (final expiry in [0, 16000, 9999999999999]) {
      expect(
        () => CallRelayConfiguration.parse(id, response(expiry), nowMs: 1000),
        throwsFormatException,
      );
    }
    final raw = response(600000);
    ((raw['iceServers'] as List).single as Map)['username'] =
        '601:0123456789abcdef0123456789abcdef';
    expect(
      () => CallRelayConfiguration.parse(id, raw, nowMs: 1000),
      throwsFormatException,
    );
  });
  test(
    'repository uses authenticated relay interface for the requested call',
    () async {
      final repository = CallRepository(
        MessagingRepository(
          account: 'me',
          call: (method, params) async {
            expect(method, 'K260914000648');
            expect(params, {'callId': id});
            return response(
              (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600) * 1000,
            );
          },
        ),
      );
      final result = await repository.readRelay(callId: id);
      result.requireUsable(id);
      expect(result.iceServers.length, 1);
    },
  );
}
