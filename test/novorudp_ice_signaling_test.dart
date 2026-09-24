import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_ice_signaling.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_packet.dart';

void main() {
  test('large UTF8 SDP survives out of order and duplicate fragments once', () {
    final value = {'sdp': '候选地址' * 2200};
    final chunks = NovoRudpIceSignaling.encode(value);
    final decoder = NovoRudpIceSignaling();
    expect(
      chunks.every((c) => c.length <= NovoRudpSecurePacket.maxFramePayload),
      isTrue,
    );
    Map<String, dynamic>? completed;
    for (final chunk in chunks.reversed) {
      completed = decoder.accept(chunk) ?? completed;
      expect(decoder.accept(chunk), isNull);
    }
    expect(completed, value);
  });
  test('conflicting fragment cannot replace valid assembly', () {
    final chunks = NovoRudpIceSignaling.encode({'sdp': 'a' * 900});
    final decoder = NovoRudpIceSignaling();
    decoder.accept(chunks.first);
    final altered =
        jsonDecode(utf8.decode(chunks.first)) as Map<String, dynamic>;
    altered['b'] = base64Encode(List.filled(512, 98));
    expect(
      () => decoder.accept(utf8.encode(jsonEncode(altered))),
      throwsFormatException,
    );
    expect(decoder.accept(chunks.last), {'sdp': 'a' * 900});
  });
  test('bounded incomplete messages expire on monotonic deadline', () {
    var now = Duration.zero;
    final decoder = NovoRudpIceSignaling(clock: () => now);
    for (var i = 0; i < 4; i++) {
      decoder.accept(NovoRudpIceSignaling.encode({'sdp': 'a' * 900}).first);
    }
    final fifth = NovoRudpIceSignaling.encode({'sdp': 'a' * 900});
    expect(() => decoder.accept(fifth.first), throwsFormatException);
    now = const Duration(seconds: 10);
    decoder.accept(fifth.first);
    expect(decoder.accept(fifth.last), {'sdp': 'a' * 900});
  });
  test('rejects oversized messages and malformed chunks', () {
    expect(
      () => NovoRudpIceSignaling.encode({'sdp': 'a' * 32768}),
      throwsFormatException,
    );
    final decoder = NovoRudpIceSignaling();
    for (final bytes in [
      <int>[255],
      List.filled(977, 1),
      utf8.encode('[]'),
    ]) {
      expect(() => decoder.accept(bytes), throwsFormatException);
    }
    final bad = jsonDecode(
      utf8.decode(NovoRudpIceSignaling.encode({'x': 1}).first),
    ) as Map;
    bad['n'] = 65;
    expect(
      () => decoder.accept(utf8.encode(jsonEncode(bad))),
      throwsFormatException,
    );
  });
}
