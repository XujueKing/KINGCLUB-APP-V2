import 'dart:io';
import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_transfer.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'chat_file_downloader_test.dart' show DownloadTransport;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'private cache clearing removes failed-transfer resume blocks',
    () async {
      final root = await Directory.systemTemp.createTemp('media-resume-clear-');
      final cache = MediaCache(directory: () async => root);
      late Directory resume;
      cache.transfer =
          ({
            required url,
            required scope,
            required destination,
            required resumeDirectory,
            required cancel,
          }) async {
            resume = resumeDirectory;
            await resume.create(recursive: true);
            await File('${resume.path}/partial.block').writeAsBytes([1]);
            throw const SocketException('offline');
          };
      try {
        await expectLater(
          cache.get(
            'https://test.invalid/media',
            scope: 'member:me',
            contentKey: 'item',
          ),
          throwsA(isA<SocketException>()),
        );
        expect(await resume.exists(), true);
        await MediaCache(directory: () async => root).clear(privateOnly: true);
        expect(await resume.exists(), false);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  const id = '11111111-1111-4111-8111-111111111111';
  for (final type in ['image', 'voice', 'video']) {
    for (final group in [false, true]) {
      test('shared cache actual $type group=$group uses transfer then local file', () async {
        final root = await Directory.systemTemp.createTemp('media-entry-');
        final bytes = [1, 2, 3];
        final hash = (await Sha256().hash(bytes)).bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        final path =
            '/kingclub/${group ? 'group-' : ''}chat-$type/$id${type == 'voice' ? '' : '/$type'}';
        final repo = MessagingRepository(
          account: 'me',
          call: (_, params) async {
            expect(params['messageId'], id);
            return {
              'messageId': id,
              'assetId': id,
              'sender': 'other',
              type: {
                'fileId': id,
                'size': 3,
                'sha256': hash,
                'path': path,
                'headers': {'authorization': 'Bearer test'},
              },
            };
          },
        );
        final kind = type == 'image'
            ? MediaKind.image
            : type == 'voice'
            ? MediaKind.audio
            : MediaKind.video;
        var transfers = 0;
        final cache = MediaCache(
          directory: () async => Directory('${root.path}/media'),
        );
        cache.transfer =
            ({
              required url,
              required scope,
              required destination,
              required resumeDirectory,
              required cancel,
            }) => ChatMediaTransfer.download(
              repo,
              url: url,
              scope: scope,
              destination: destination,
              resumeDirectory: resumeDirectory,
              cancel: cancel,
              baseUrl: 'https://test.invalid/api',
              openDownloader: (directory) async {
                transfers++;
                return ChatFileDownloader(
                  repository: repo,
                  checkSession: () async {},
                  temporaryDirectory: () async => root,
                  dio: Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
                    ..httpClientAdapter = DownloadTransport((options) async {
                      expect(options.headers['range'], 'bytes=0-2');
                      return ResponseBody.fromBytes(
                        bytes,
                        206,
                        headers: {
                          'content-range': ['bytes 0-2/3'],
                          'content-length': ['3'],
                          'content-type': [
                            type == 'image'
                                ? 'image/webp'
                                : type == 'voice'
                                ? 'audio/mp4'
                                : 'video/mp4',
                          ],
                        },
                      );
                    }),
                );
              },
            );
        try {
          final first = await cache.get(
            'https://test.invalid/api$path',
            scope: 'member:me',
            contentKey: 'message',
            kind: kind,
          );
          expect(await first.readAsBytes(), bytes);
          expect(
            (await cache.get(
              'https://test.invalid/api$path',
              scope: 'member:me',
              contentKey: 'message',
              kind: kind,
            )).path,
            first.path,
          );
          expect(transfers, 1);
          await cache.removePermanently(
            scope: 'member:me',
            contentKey: 'message',
            kind: kind,
          );
          expect(await first.exists(), false);
          await expectLater(
            cache.get(
              'https://test.invalid/api$path',
              scope: 'member:me',
              contentKey: 'message',
              kind: kind,
            ),
            throwsStateError,
          );
          expect(transfers, 1);
        } finally {
          await root.delete(recursive: true);
        }
      });
    }
  }
  test('deletion removes unfinished transfer resume data and blocks late publication', () async {
    final root = await Directory.systemTemp.createTemp('media-delete-');
    final started = Completer<void>();
    late Directory resume;
    final cache = MediaCache(directory: () async => root);
    cache.transfer =
        ({
          required url,
          required scope,
          required destination,
          required resumeDirectory,
          required cancel,
        }) async {
          resume = resumeDirectory;
          await resume.create(recursive: true);
          await File('${resume.path}/partial').writeAsBytes([1]);
          started.complete();
          await cancel.whenCancel;
          // A late callback cannot restore a deleted media item.
          await destination.writeAsBytes([1, 2, 3]);
          return true;
        };
    try {
      final download = cache.get(
        'https://test.invalid/media',
        scope: 'member:me',
        contentKey: 'item',
      );
      final rejected = expectLater(download, throwsStateError);
      await started.future;
      await cache.removePermanently(
        scope: 'member:me',
        contentKey: 'item',
        kind: MediaKind.image,
      );
      await rejected;
      expect(await resume.exists(), false);
      final restarted = MediaCache(directory: () async => root);
      await expectLater(
        restarted.get(
          'https://test.invalid/media',
          scope: 'member:me',
          contentKey: 'item',
        ),
        throwsStateError,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });
}
