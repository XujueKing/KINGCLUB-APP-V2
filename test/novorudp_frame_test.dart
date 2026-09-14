import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';

void main() {
  final fixtures = (jsonDecode(
    File('test/fixtures/novorudp-rust-frames.json').readAsStringSync(),
  ) as List).map((v) => Uint8List.fromList((v as List).cast<int>())).toList();
  test(
    'all five Rust frames decode and reencode byte for byte, preserving u64',
    () async {
      for (var i = 0; i < fixtures.length; i++) {
        final frame = await NovoRudpFrame.decode(fixtures[i]);
        expect(frame.kind, NovoRudpFrameKind.values[i]);
        expect(frame.streamId, (BigInt.one << 64) - BigInt.one);
        expect(frame.objectId, BigInt.one << 63);
        expect(frame.sequence, BigInt.from(i));
        expect(frame.ackEpoch, BigInt.parse('0102030405060708', radix: 16));
        expect(frame.payload, [0, 1, 127, 128, 255]);
        expect(await frame.encode(), fixtures[i]);
      }
    },
  );
  test(
    'invalid version, kind, length, session and payload corruption rejected',
    () async {
      for (final offset in [0, 8, 10, 12, 28, 44, 60, 64, 100]) {
        final bytes = Uint8List.fromList(fixtures[0]);
        bytes[offset] ^= 255;
        await expectLater(NovoRudpFrame.decode(bytes), throwsFormatException);
      }
      await expectLater(
        NovoRudpFrame.decode(Uint8List(95)),
        throwsFormatException,
      );
      await expectLater(
        NovoRudpFrame.decode(Uint8List(65508)),
        throwsFormatException,
      );
    },
  );
  test('caller mutation during hashing cannot change decoded data', () async {
    final bytes = Uint8List.fromList(fixtures[0]);
    final pending = NovoRudpFrame.decode(bytes);
    bytes.fillRange(0, bytes.length, 0);
    final frame = await pending;
    expect(await frame.encode(), fixtures[0]);
    expect(() => frame.payload[0] = 33, throwsUnsupportedError);
  });
  test('constructor rejects invalid unsigned fields and payload bytes', () {
    NovoRudpFrame frame(BigInt n, List<int> data) => NovoRudpFrame(
      kind: NovoRudpFrameKind.data,
      sessionId: List.filled(16, 0),
      streamId: n,
      objectId: BigInt.zero,
      sequence: BigInt.zero,
      ackEpoch: BigInt.zero,
      payload: data,
    );
    expect(() => frame(-BigInt.one, []), throwsFormatException);
    expect(() => frame(BigInt.one << 64, []), throwsFormatException);
    expect(() => frame(BigInt.zero, [256]), throwsFormatException);
    expect(
      () => frame(BigInt.zero, List.filled(NovoRudpFrame.maxPayload + 1, 0)),
      throwsFormatException,
    );
  });
}
