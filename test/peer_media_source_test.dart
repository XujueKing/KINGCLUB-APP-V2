import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/peer_file_authority.dart';
import 'package:kingclub/src/features/messaging/data/peer_media_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id = '11111111-1111-4111-8111-111111111111',
      client = '22222222-2222-4222-8222-222222222222';
  for (final type in ['image', 'video', 'voice']) {
    test(
      'sender $type resolves existing bytes without creating a copy and respects deletion',
      () async {
        final root = await Directory.systemTemp.createTemp('peer-source-');
        final cache = MediaCache(directory: () async => root);
        final hash = (await const DartSha256().hash([1, 2, 3])).bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        final authority = await PeerFileAuthority.read(
          MessagingRepository(
            account: 'me',
            call: (_, _) async => {
              'messageId': id,
              'assetId': id,
              'fileId': id,
              'media': type,
              'clientMessageId': client,
              'sender': 'me',
              'recipient': 'peer',
              'fileName': 'source',
              'size': 3,
              'sha256': hash,
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(seconds: 15))
                  .toIso8601String(),
            },
          ),
          'peer',
          id,
          sending: true,
          media: type,
        );
        final kind = type == 'image'
            ? MediaKind.image
            : type == 'voice'
            ? MediaKind.audio
            : MediaKind.video;
        final key = type == 'voice'
            ? 'chat-voice-asset:$id'
            : 'chat-$type-sent:$client';
        try {
          final source = await cache.importBytes(
            Uint8List.fromList([1, 2, 3]),
            scope: 'member:me',
            contentKey: key,
            kind: kind,
          );
          if (type != 'voice') {
            // A different encoding in the message cache must not shadow the
            // matching original sent file merely because its length is equal.
            await cache.importBytes(
              Uint8List.fromList([9, 9, 9]),
              scope: 'member:me',
              contentKey: 'chat-$type-message:false:$id:$type',
              kind: kind,
            );
          }
          final before = await root
              .list(recursive: true)
              .where((f) => f is File)
              .length;
          final result = await readPeerMediaSource(
            authority,
            account: 'me',
            active: () => true,
            cache: cache,
          );
          expect(result?.path, source.path);
          expect(
            await root.list(recursive: true).where((f) => f is File).length,
            before,
          );
          expect(
            await readPeerMediaSource(
              authority,
              account: 'other',
              active: () => true,
              cache: cache,
            ),
            null,
          );
          expect(
            await readPeerMediaSource(
              authority,
              account: 'me',
              active: () => false,
              cache: cache,
            ),
            null,
          );
          await cache.removePermanently(
            scope: 'member:me',
            contentKey: key,
            kind: kind,
          );
          expect(
            await readPeerMediaSource(
              authority,
              account: 'me',
              active: () => true,
              cache: cache,
            ),
            null,
          );
        } finally {
          await root.delete(recursive: true);
        }
      },
    );
  }
}
