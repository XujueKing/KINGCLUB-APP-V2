import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_video.dart';

void main() {
  const good = {
    'status': 'ready',
    'assetId': '12345678-1234-1234-1234-123456789012',
    'durationMs': 500,
    'width': 320,
    'height': 240,
    'hasAudio': false,
  };
  test('only complete bounded preparation receipts become video messages', () {
    expect(
      ChatVideo.fromPrepared(good).toMessageFields()['videoHasAudio'],
      false,
    );
    for (final patch in [
      {'status': 'processing'},
      {'assetId': 'file'},
      {'durationMs': 499},
      {'durationMs': 120501},
      {'width': 1281},
      {'height': 1},
      {'hasAudio': 0},
      {'width': 320.0},
    ]) {
      expect(
        () => ChatVideo.fromPrepared({...good, ...patch}),
        throwsFormatException,
      );
    }
  });
}
