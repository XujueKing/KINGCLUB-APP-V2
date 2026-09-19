import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_stun_binding.dart';

Uint8List reply(NovoRudpStunBinding binding) {
  final bytes = Uint8List(32)..setRange(0, 20, binding.request);
  final data = ByteData.sublistView(bytes);
  data.setUint16(0, 0x0101);
  data.setUint16(2, 12);
  data.setUint16(20, 0x0020);
  data.setUint16(22, 8);
  bytes[25] = 1;
  data.setUint16(26, 45678 ^ 0x2112);
  data.setUint32(28, 0xcb007109 ^ NovoRudpStunBinding.cookie);
  return bytes;
}

void main() {
  test('binding decodes XOR IPv4 address and translated port', () {
    final binding = NovoRudpStunBinding();
    final mapped = binding.parseResponse(reply(binding))!;
    expect(mapped.address.address, '203.0.113.9');
    expect(mapped.port, 45678);
    expect(binding.request.length, 20);
  });
  test(
    'transaction mismatch and malformed packets do not produce candidates',
    () {
      final binding = NovoRudpStunBinding();
      expect(binding.parseResponse(reply(NovoRudpStunBinding())), isNull);
      final valid = reply(binding);
      for (var length = 0; length < valid.length; length++) {
        expect(
          binding.parseResponse(Uint8List.sublistView(valid, 0, length)),
          isNull,
        );
      }
      for (final offset in [0, 2, 4, 8, 20, 22, 25]) {
        final broken = Uint8List.fromList(valid);
        broken[offset] ^= 0x80;
        expect(binding.parseResponse(broken), isNull);
      }
    },
  );
  test(
    'trailing malformed attributes invalidate an otherwise valid endpoint',
    () {
      final binding = NovoRudpStunBinding();
      final bytes = Uint8List(36)..setRange(0, 32, reply(binding));
      final data = ByteData.sublistView(bytes);
      data.setUint16(2, 16);
      data.setUint16(32, 0x8022);
      data.setUint16(34, 8);
      expect(binding.parseResponse(bytes), isNull);
    },
  );
}
