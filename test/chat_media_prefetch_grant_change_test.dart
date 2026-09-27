import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_image_prefetch.dart';
import 'package:kingclub/src/features/messaging/data/chat_video_prefetch.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_prefetch.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

class RotatingMedia extends MediaCache {
  RotatingMedia(Directory root) : super(directory: () async => root);
  Uint8List bytes = Uint8List.fromList([1, 2, 3]);
  int downloads = 0;

  @override
  Future<File> get(
    String url, {
    required String scope,
    String? contentKey,
    MediaKind kind = MediaKind.image,
    Map<String, String>? headers,
  }) async {
    // Model production's reuse of a completed message-owned transfer.
    try {
      return await cached(scope: scope, contentKey: contentKey!, kind: kind);
    } catch (_) {}
    downloads++;
    return importBytes(
      bytes,
      scope: scope,
      contentKey: contentKey!,
      kind: kind,
    );
  }
}

void main() {
  const id = '11111111-1111-4111-8111-111111111111';
  const asset = '22222222-2222-4222-8222-222222222222';
  const replacement = '33333333-3333-4333-8333-333333333333';
  for (final group in [false, true]) {
    for (final type in ['image', 'voice', 'video']) {
      test('$type group=$group discards changed grant and retries', () async {
        final root = await Directory.systemTemp.createTemp('grant-change-');
        addTearDown(() => root.delete(recursive: true));
        final media = RotatingMedia(root);
        var calls = 0;
        final repo = MessagingRepository(
          account: 'me',
          call: (_, _) async {
            final initial = ++calls == 1;
            final bytes = initial ? [1, 2, 3] : [4, 5, 6];
            return {
              'messageId': id,
              type: {
                'fileId': initial ? asset : replacement,
                'width': 100,
                'height': 100,
                'durationMs': 3000,
                'contentType': 'audio/mp4',
                'size': bytes.length,
                'sha256': (await const DartSha256().hash(bytes)).bytes
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(),
                'codec': 'h264',
                'path':
                    '/kingclub/${group ? 'group-' : ''}chat-$type/$id'
                    '${type == 'voice' ? '' : '/$type'}',
                'headers': {'authorization': 'Bearer fixture'},
              },
            };
          },
        );
        final dynamic worker = switch (type) {
          'image' => ChatImagePrefetch(repo, group: group, media: media),
          'voice' => ChatVoicePrefetch(repo, group: group, media: media),
          _ => ChatVideoPrefetch(repo, group: group, media: media),
        };
        addTearDown(() => worker.dispose());
        final rows = <Map<String, dynamic>>[
          {
            'messageId': id,
            'clientMessageId': asset,
            'voiceAssetId': asset,
            'sender': 'me',
            'messageType': type,
          },
        ];
        final kind = type == 'voice'
            ? MediaKind.audio
            : type == 'image'
            ? MediaKind.image
            : MediaKind.video;
        final transfer =
            'chat-$type-transfer:$group:$id'
            '${type == 'voice' ? '' : ':$type'}';
        final retained = type == 'voice'
            ? 'chat-voice-asset:$asset'
            : 'chat-$type-message:$group:$id:$type';
        worker.update(rows);
        await worker.idle;
        expect(worker.hasFailures, true);
        for (final key in [transfer, retained]) {
          await expectLater(
            media.cached(scope: 'member:me', contentKey: key, kind: kind),
            throwsStateError,
          );
        }
        worker.update(rows);
        await worker.idle;
        expect(calls, 2); // Backoff avoids a busy download loop.
        media.bytes = Uint8List.fromList([4, 5, 6]);
        worker.update(rows, retryFailures: true);
        await worker.idle;
        expect(worker.hasFailures, false);
        expect(media.downloads, 2);
        expect(calls, 4);
        final reopened = MediaCache(directory: () async => root);
        final file = await reopened.cached(
          scope: 'member:me',
          contentKey: retained,
          kind: kind,
        );
        expect(await file.readAsBytes(), [4, 5, 6]);
      });
    }
  }
}
