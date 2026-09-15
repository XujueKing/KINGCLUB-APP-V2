import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/relay_security_context.dart';

void main() {
  test('omitted relay CA retains platform trust', () {
    expect(relaySecurityContext(''), isNull);
  });
  test('invalid, oversized and private key data never disables TLS', () {
    for (final encoded in [
      '!',
      'a' * 65537,
      base64Encode(
        utf8.encode(
          '-----BEGIN PRIVATE KEY-----\nkey\n-----END PRIVATE KEY-----',
        ),
      ),
      base64Encode(
        utf8.encode(
          '-----BEGIN CERTIFICATE-----\nPRIVATE KEY\n-----END CERTIFICATE-----',
        ),
      ),
    ]) {
      expect(() => relaySecurityContext(encoded), throwsFormatException);
    }
  });
  test(
    'malformed certificate is rejected by the native certificate parser',
    () {
      expect(
        () => relaySecurityContext(
          base64Encode(
            utf8.encode(
              '-----BEGIN CERTIFICATE-----\nYWJj\n-----END CERTIFICATE-----',
            ),
          ),
        ),
        throwsA(anything),
      );
    },
  );
}
