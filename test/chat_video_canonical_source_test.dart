import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/canonical_voice_container.dart';
import 'package:kingclub/src/features/messaging/data/chat_video_canonical_source.dart';

void main() {
  test('HEVC dependency and field boxes match the server golden', () async {
    final bytes = await File('test/fixtures/chat-video-hevc-synthetic.mp4')
        .readAsBytes();
    final result = canonicalVideoContainer(bytes)!;
    final digest = (await Sha256().hash(result)).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    expect(
      digest,
      'fee8f958626fd05cf6b3d22102f892ffe9a0dd420902f5dc73fa105af3b0e437',
    );
  });
  test(
    'video golden matches server while voice rejects video tracks',
    () async {
      final bytes = await File('test/fixtures/chat-video-synthetic.mp4')
          .readAsBytes();
      final clean = canonicalVideoContainer(bytes)!;
      expect(canonicalVoiceContainer(bytes), isNull);
      expect(canonicalVideoContainer(clean), clean);
      final hash = (await Sha256().hash(clean)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(
        hash,
        'c34ac97fad8cda46a3046bcd75e4dfccc63bdd59b63e0b0bd3b09ad693342c48',
      );
    },
  );
  test(
    'private copy leaves original intact and is removed after ownership ends',
    () async {
      final original = File('test/fixtures/chat-video-synthetic.mp4');
      final bytes = await original.readAsBytes();
      final source = ChatVideoCanonicalSource();
      final copy = await source.prepare(original);
      expect(copy.path, isNot(original.path));
      expect(await copy.readAsBytes(), canonicalVideoContainer(bytes));
      expect(await original.readAsBytes(), bytes);
      await source.close();
      expect(await copy.exists(), false);
      expect(await original.exists(), true);
      await expectLater(source.prepare(original), throwsStateError);
    },
  );
}
