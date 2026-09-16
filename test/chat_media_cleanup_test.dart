import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';

void main() {
  test(
    'deletes owned image copies and preserves other accounts and messages',
    () async {
      final dir = await Directory.systemTemp.createTemp('chat-cleanup-');
      addTearDown(() => dir.delete(recursive: true));
      final cache = MediaCache(directory: () async => dir);
      for (final account in ['a', 'b']) {
        for (final key in [
          'chat-image-sent:c',
          'chat-image-message:false:m:image',
          'avatar',
        ]) {
          await cache.importBytes(
            Uint8List.fromList([1, 2, 3]),
            scope: 'member:$account',
            contentKey: key,
            kind: MediaKind.image,
          );
        }
      }
      await ChatMediaCleanup(media: cache).remove(
        account: 'a',
        group: false,
        message: {
          'messageType': 'image',
          'sender': 'a',
          'messageId': 'm',
          'clientMessageId': 'c',
        },
      );
      final reopened = MediaCache(directory: () async => dir);
      await expectLater(
        reopened.cached(
          scope: 'member:a',
          contentKey: 'chat-image-sent:c',
          kind: MediaKind.image,
        ),
        throwsStateError,
      );
      await expectLater(
        reopened.cached(
          scope: 'member:a',
          contentKey: 'chat-image-message:false:m:image',
          kind: MediaKind.image,
        ),
        throwsStateError,
      );
      expect(
        await reopened.cached(
          scope: 'member:a',
          contentKey: 'avatar',
          kind: MediaKind.image,
        ),
        isNotNull,
      );
      expect(
        await reopened.cached(
          scope: 'member:b',
          contentKey: 'chat-image-sent:c',
          kind: MediaKind.image,
        ),
        isNotNull,
      );
    },
  );
}
