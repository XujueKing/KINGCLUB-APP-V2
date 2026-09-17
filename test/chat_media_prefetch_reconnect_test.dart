import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_image_prefetch.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_prefetch.dart';
import 'package:kingclub/src/features/messaging/data/chat_video_prefetch.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

class DiskMedia extends MediaCache {
  DiskMedia(Directory root) : super(directory: () async => root);
  int downloads = 0;
  @override
  Future<File> get(
    String url, {
    required String scope,
    String? contentKey,
    MediaKind kind = MediaKind.image,
    Map<String, String>? headers,
  }) {
    downloads++;
    return importBytes(
      Uint8List.fromList([1, 2, 3]),
      scope: scope,
      contentKey: contentKey!,
      kind: kind,
    );
  }
}

void main() {
  const id = '11111111-1111-4111-8111-111111111111';
  const asset = '22222222-2222-4222-8222-222222222222';
  for (final type in ['image', 'voice', 'video']) {
    for (final active in [false, true]) {
      for (final deleted in [false, true]) {
        test('$type reconnect active=$active deleted=$deleted', () async {
          final root = await Directory.systemTemp.createTemp(
            'media-reconnect-',
          );
          addTearDown(() => root.delete(recursive: true));
          final media = DiskMedia(root);
          final started = Completer<void>(), release = Completer<void>();
          var calls = 0;
          final hash = (await const DartSha256().hash([1, 2, 3])).bytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          final repo = MessagingRepository(
            account: 'me',
            call: (_, _) async {
              if (++calls == 1) {
                started.complete();
                if (active) await release.future;
                throw const SocketException('offline');
              }
              return {
                'messageId': id,
                type: {
                  'fileId': asset,
                  'width': 100,
                  'height': 100,
                  'durationMs': 3000,
                  'contentType': 'audio/mp4',
                  'size': 3,
                  'sha256': hash,
                  'codec': 'h264',
                  'path':
                      '/kingclub/chat-$type/$id${type == 'voice' ? '' : '/$type'}',
                  'headers': {'authorization': 'Bearer fixture'},
                },
              };
            },
          );
          final dynamic worker = switch (type) {
            'image' => ChatImagePrefetch(repo, group: false, media: media),
            'voice' => ChatVoicePrefetch(repo, group: false, media: media),
            _ => ChatVideoPrefetch(repo, group: false, media: media),
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
          worker.update(rows);
          await started.future;
          if (!active) {
            await worker.idle;
            expect(worker.hasFailures, true);
            worker.update(rows);
            await worker.idle;
            expect(calls, 1); // Ordinary history updates retain the backoff.
          }
          Future<void>? removal;
          if (deleted) removal = ChatMediaDeletion('me', false, id).dispatch();
          worker.update(rows, retryFailures: true);
          if (active) release.complete();
          await worker.idle;
          await removal;
          expect(calls, deleted ? 1 : 3);
          expect(media.downloads, deleted ? 0 : 1);
          expect(worker.hasFailures, false);
          if (!deleted) {
            final reopened = MediaCache(directory: () async => root);
            final file = await reopened.cached(
              scope: 'member:me',
              contentKey: type == 'voice'
                  ? 'chat-voice-asset:$asset'
                  : 'chat-$type-message:false:$id:$type',
              kind: type == 'voice'
                  ? MediaKind.audio
                  : type == 'video'
                  ? MediaKind.video
                  : MediaKind.image,
            );
            expect(await file.readAsBytes(), [1, 2, 3]);
          }
        });
      }
    }
  }
}
