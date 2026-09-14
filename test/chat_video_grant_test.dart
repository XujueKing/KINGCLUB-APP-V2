import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_video_grant.dart';

void main() {
  const id = '12345678-1234-1234-1234-123456789012';
  Map<String, dynamic> media() => {
    'fileId': id,
    'path': '/kingclub/chat-video/$id/video',
    'size': 10,
    'sha256': 'a' * 64,
    'headers': {'authorization': 'Bearer synthetic'},
  };
  test(
    'private video grants reject redirects, wrong scope and malformed metadata',
    () {
      expect(
        ChatVideoGrant.parse(
          {'messageId': id, 'video': media()},
          id,
          group: false,
          full: true,
        ).size,
        10,
      );
      for (final patch in [
        {'path': 'https://other.invalid/video'},
        {'path': '/kingclub/group-chat-video/$id/video'},
        {'fileId': '-' * 36},
        {'size': 33554433},
        {'sha256': 'bad'},
        {'codec': 'av1'},
        {'codec': 'hevc'},
        {'path': '/kingclub/chat-video/$id/hevc'},
        {
          'headers': {'authorization': 'Bearer bad\nheader'},
        },
      ]) {
        expect(
          () => ChatVideoGrant.parse(
            {
              'messageId': id,
              'video': {...media(), ...patch},
            },
            id,
            group: false,
            full: true,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => ChatVideoGrant.parse(
          {'messageId': 'other', 'video': media()},
          id,
          group: false,
          full: true,
        ),
        throwsFormatException,
      );
    },
  );
  test('HEVC grant binds codec to its private route in both scopes', () {
    for (final group in [false, true]) {
      final grant = ChatVideoGrant.parse(
        {
          'messageId': id,
          'video': {
            ...media(),
            'codec': 'hevc',
            'path':
                '/kingclub/${group ? 'group-chat-video' : 'chat-video'}/$id/hevc',
          },
        },
        id,
        group: group,
        full: true,
      );
      expect(grant.codec, 'hevc');
    }
    expect(
      ChatVideoGrant.parse(
        {'messageId': id, 'video': media()},
        id,
        group: false,
        full: true,
      ).codec,
      'h264',
    );
  });
}
