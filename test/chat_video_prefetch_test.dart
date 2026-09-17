import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';
import 'package:kingclub/src/features/messaging/data/chat_video_prefetch.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

class DiskVideos extends MediaCache {
  DiskVideos(Directory root) : super(directory: () async => root);
  int downloads = 0;
  @override
  Future<File> get(
    String url, {
    required String scope,
    String? contentKey,
    MediaKind kind = MediaKind.image,
    Map<String, String>? headers,
  }) async {
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
  const client = '22222222-2222-4222-8222-222222222222';
  final rows = <Map<String, dynamic>>[
    {
      'messageId': id,
      'clientMessageId': client,
      'messageType': 'video',
      'sender': 'me',
    },
  ];
  for (final group in [false, true]) {
    for (final badHash in [false, true]) {
      for (final deleteDuringGrant in [false, true]) {
        test(
          'sent video backfill survives disk reopen group=$group delete=$deleteDuringGrant corrupt=$badHash',
          () async {
            final root = await Directory.systemTemp.createTemp(
              'video-prefetch-',
            );
            final media = DiskVideos(root);
            final digest = (await const DartSha256().hash([1, 2, 3])).bytes
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join();
            final requested = Completer<void>(), gate = Completer<void>();
            var calls = 0;
            final worker = ChatVideoPrefetch(
              MessagingRepository(
                account: 'me',
                call: (method, _) async {
                  expect(method, group ? 'K260915000668' : 'K260915000667');
                  calls++;
                  if (!requested.isCompleted) requested.complete();
                  if (deleteDuringGrant) await gate.future;
                  return {
                    'messageId': id,
                    'video': {
                      'fileId': client,
                      'size': 3,
                      'sha256': badHash ? '0' * 64 : digest,
                      'codec': 'h264',
                      'path':
                          '/kingclub/${group ? 'group-chat-video' : 'chat-video'}/$id/video',
                      'headers': {'authorization': 'Bearer fixture'},
                    },
                  };
                },
              ),
              group: group,
              media: media,
            );
            worker.update(rows);
            await requested.future;
            Future<void>? deletion;
            if (deleteDuringGrant) {
              deletion = ChatMediaDeletion('me', group, id).dispatch();
              gate.complete();
            }
            await worker.idle;
            await deletion;
            final reopened = MediaCache(directory: () async => root);
            final read = reopened.cached(
              scope: 'member:me',
              contentKey: 'chat-video-message:$group:$id:video',
              kind: MediaKind.video,
            );
            if (deleteDuringGrant || badHash) {
              await expectLater(read, throwsA(anything));
              expect(media.downloads, deleteDuringGrant ? 0 : 1);
              expect(worker.hasFailures, !deleteDuringGrant);
            } else {
              expect(await (await read).readAsBytes(), [1, 2, 3]);
              expect(calls, 2);
              worker.update(rows);
              await worker.idle;
              expect(calls, 2);
              expect(media.downloads, 1);
            }
            worker.dispose();
            await root.delete(recursive: true);
          },
        );
      }
    }
  }
}
