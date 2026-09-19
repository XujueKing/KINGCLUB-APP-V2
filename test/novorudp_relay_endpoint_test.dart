import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_connection.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class UnusedIdentity implements NovoRudpSecureSession {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final peer = 'novovm-ed25519:${'0' * 64}';
  for (final path in ['/novovm', '/supervm/relay']) {
    test('accepts reviewed relay path $path without opening a socket', () {
      final connection = NovoRudpRelayConnection(
        identity: UnusedIdentity(),
        endpoint: Uri.parse('wss://relay.example$path'),
        expectedRelay: peer,
      );
      connection.close();
    });
  }
  for (final url in [
    'ws://relay.example/supervm/relay',
    'wss://user:password@relay.example/supervm/relay',
    'wss://relay.example/supervm/relay?token=secret',
    'wss://relay.example/supervm/relay#fragment',
    'wss://relay.example/supervm/relay/extra',
    'wss://relay.example/SUPERVM/relay',
  ]) {
    test('rejects unreviewed relay endpoint $url', () {
      expect(
        () => NovoRudpRelayConnection(
          identity: UnusedIdentity(),
          endpoint: Uri.parse(url),
          expectedRelay: peer,
        ),
        throwsArgumentError,
      );
    });
  }
}
