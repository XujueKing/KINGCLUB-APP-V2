import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_download.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';

import 'chat_file_downloader_test.dart'
    show DownloadTransport, messageId, assetId;

class _Channel implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Link implements NovoRudpFrameLink {
  @override
  final channel = _Channel();
  final incoming = StreamController<NovoRudpFrame>.broadcast();
  @override
  Stream<NovoRudpFrame> get frames => incoming.stream;
  @override
  Future<void> send(NovoRudpFrame frame) async {}
  @override
  Future<void> close() => incoming.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in ['cancel', 'dispose', 'logout', 'delete']) {
    test(
      'peer complete blocks survive page interruption only: $mode',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'peer-cancel-resume-',
        );
        final link = _Link();
        final cacheRoot = Directory('${root.path}/cache');
        final cache = ChatDownloadCache(
          root: cacheRoot,
          key: await AesGcm.with256bits().newSecretKey(),
        );
        final bytes = Uint8List.fromList(
          List.generate(2 * 1024 * 1024 + 3, (i) => i % 251),
        );
        final hash = (await Sha256().hash(bytes)).bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        final ref = ChatFileReference(
          messageId: messageId,
          assetId: assetId,
          fileName: 'file.bin',
          size: bytes.length,
          sha256: hash,
        );
        final repo = MessagingRepository(
          account: 'me',
          call: (_, _) async => {
            'messageId': messageId,
            'file': {
              'assetId': assetId,
              'fileName': ref.fileName,
              'size': bytes.length,
              'sha256': hash,
              'chunkBytes': 1024 * 1024,
              'chunkCount': 3,
              'contentType': 'application/octet-stream',
              'path': '/kingclub/chat-file/$messageId',
              'headers': {'authorization': 'Bearer test-only'},
            },
          },
        );
        final requested = <int>[];
        Dio http() => Dio(BaseOptions(baseUrl: 'https://test.invalid'))
          ..httpClientAdapter = DownloadTransport((options) async {
            final index = int.parse(options.path.split('/').last);
            requested.add(index);
            return ResponseBody.fromBytes(
              bytes.sublist(
                index * 1024 * 1024,
                ((index + 1) * 1024 * 1024).clamp(0, bytes.length),
              ),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/octet-stream'],
                Headers.contentLengthHeader: ['${index < 2 ? 1024 * 1024 : 3}'],
              },
            );
          });
        late ChatFileDownloader download;
        Future<void>? closing;
        download = ChatFileDownloader(
          repository: repo,
          checkSession: () async {},
          dio: http(),
          resumeCache: cache,
          temporaryDirectory: () async => root,
          peerDownload: (_, active) async {
            final peer = await NovoRudpFileDownload.open(
              link: link,
              privateDirectory: root,
              streamId: BigInt.one,
              objectId: BigInt.two,
              size: bytes.length,
              sha256: hash,
              canReceive: active,
            );
            // A complete received block, plus an outstanding tail, at interruption.
            await peer.restoreBlocks(
              (index, length) async => index < 2
                  ? Uint8List.sublistView(
                      bytes,
                      index * 1024 * 1024,
                      index * 1024 * 1024 + length,
                    )
                  : null,
            );
            return peer;
          },
        );
        var interrupted = false;
        try {
          final operation = download.download(
            ref,
            onProgress: (received, _) {
              if (received == 0 || interrupted) return;
              interrupted = true;
              switch (mode) {
                case 'cancel':
                  download.cancel();
                case 'dispose':
                  closing = download.dispose();
                case 'logout':
                  SecureSessionStore.changes.add(null);
                case 'delete':
                  closing = const ChatMediaDeletion(
                    'me',
                    false,
                    messageId,
                  ).dispatch();
              }
            },
          );
          await expectLater(operation, throwsA(anything));
          await closing;
          await download.dispose();
          expect(interrupted, true);
          expect(requested, isEmpty);
          download = ChatFileDownloader(
            repository: repo,
            checkSession: () async {},
            dio: http(),
            resumeCache: cache,
            temporaryDirectory: () async => root,
          );
          final restored = await download.download(ref);
          expect(await restored.readAsBytes(), bytes);
          expect(
            requested,
            mode == 'cancel' || mode == 'dispose' ? [1, 2] : [0, 1, 2],
          );
        } finally {
          await download.dispose();
          await link.close();
          await root.delete(recursive: true);
        }
      },
    );
  }
}
