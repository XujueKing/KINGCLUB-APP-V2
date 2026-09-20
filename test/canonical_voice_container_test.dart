import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/canonical_voice_container.dart';

void main() {
  final source = File('test/fixtures/chat-voice-synthetic.m4a')
      .readAsBytesSync();
  test(
    'matches server golden and preserves packet bytes while stripping metadata',
    () async {
      final result = canonicalVoiceContainer(source)!;
      expect(result.length, source.length);
      final digest = (await Sha256().hash(result)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(
        digest,
        '42be6b80acdc4507054528968d084185fd83a03934ed64172fc7ae8b7cbe25d0',
      );
      expect(canonicalVoiceContainer(result), result);
      expect(
        String.fromCharCodes(result),
        isNot(contains('synthetic-private-title')),
      );
      final offset = String.fromCharCodes(source).indexOf('mdat');
      final size = ByteData.sublistView(source).getUint32(offset - 4);
      expect(
        result.sublist(offset + 4, offset - 4 + size),
        source.sublist(offset + 4, offset - 4 + size),
      );
    },
  );
  test('malformed and external-reference containers use the normalization fallback', () {
    final external = Uint8List.fromList(source);
    final offset = String.fromCharCodes(source).indexOf('url ');
    ByteData.sublistView(external).setUint32(offset + 4, 0);
    for (final input in [
      source.sublist(0, source.length - 1),
      Uint8List(20),
      external,
    ]) {
      expect(canonicalVoiceContainer(input), isNull);
    }
  });
}
