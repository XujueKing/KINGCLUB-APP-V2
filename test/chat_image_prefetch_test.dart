import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_image_prefetch.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

class DiskImages extends MediaCache {
  DiskImages(Directory root) : super(directory: () async => root);
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
  for (final group in [false, true]) {
    for (final mode in [
      'received',
      'sent',
      'cached-sent',
      'deleted',
      'revoked',
    ]) {
      test('image retention group=$group mode=$mode', () async {
        final root = await Directory.systemTemp.createTemp('image-prefetch-');
        addTearDown(() => root.delete(recursive: true));
        final media = DiskImages(root);
        if (mode == 'cached-sent') {
          await media.importBytes(
            Uint8List.fromList([1, 2, 3]),
            scope: 'member:me',
            contentKey: 'chat-image-sent:$client',
            kind: MediaKind.image,
          );
        }
        final secondGrant = Completer<void>(), release = Completer<void>();
        var calls = 0;
        final worker = ChatImagePrefetch(
          MessagingRepository(
            account: 'me',
            call: (_, _) async {
              calls++;
              if (calls == 2) {
                secondGrant.complete();
                if (mode == 'deleted') await release.future;
                if (mode == 'revoked') throw StateError('revoked');
              }
              return {
                'messageId': id,
                'image': {
                  'fileId': client,
                  'width': 100,
                  'height': 80,
                  'path':
                      '/kingclub/${group ? 'group-chat-image' : 'chat-image'}/$id/image',
                  'headers': {'authorization': 'Bearer fixture'},
                },
              };
            },
          ),
          group: group,
          media: media,
        );
        addTearDown(worker.dispose);
        final row = <String, dynamic>{
          'messageId': id,
          'clientMessageId': client,
          'sender': mode == 'received' ? 'peer' : 'me',
          'messageType': 'image',
        };
        worker.update([row]);
        if (mode == 'deleted') {
          await secondGrant.future;
          final deleting = ChatMediaDeletion('me', group, id).dispatch();
          release.complete();
          await deleting;
        }
        await worker.idle;
        final reopened = MediaCache(directory: () async => root);
        final key = 'chat-image-message:$group:$id:image';
        if (mode == 'deleted' || mode == 'revoked' || mode == 'cached-sent') {
          await expectLater(
            reopened.cachedImage(scope: 'member:me', contentKey: key),
            throwsStateError,
          );
        } else {
          final local = await reopened.cachedImage(
            scope: 'member:me',
            contentKey: key,
          );
          expect(await local.readAsBytes(), [1, 2, 3]);
        }
        worker.update([row]);
        await worker.idle;
        expect(media.downloads, mode == 'cached-sent' ? 0 : 1);
        expect(calls, mode == 'cached-sent' ? 0 : 2);
        expect(worker.hasFailures, mode == 'revoked');
        await ChatMediaCleanup(media: media)
            .remove(account: 'me', group: group, message: row);
        for (final deletedKey in [
          key,
          'chat-image-transfer:$group:$id:image',
        ]) {
          await expectLater(
            reopened.cachedImage(scope: 'member:me', contentKey: deletedKey),
            throwsStateError,
          );
          await expectLater(
            reopened.importBytes(
              Uint8List.fromList([4]),
              scope: 'member:me',
              contentKey: deletedKey,
              kind: MediaKind.image,
            ),
            throwsStateError,
          );
        }
      });
    }
  }
}
