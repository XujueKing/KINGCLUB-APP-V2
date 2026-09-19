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
import 'package:kingclub/src/features/messaging/data/novorudp_file_receiver.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

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
  final incoming = StreamController<NovoRudpFrame>();
  @override
  Stream<NovoRudpFrame> get frames => incoming.stream;
  @override
  Future<void> send(NovoRudpFrame frame) async {}
  @override
  Future<void> close() => incoming.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    (false, false, null),
    (true, false, null),
    (false, true, null),
    for (final media in ['image', 'voice', 'video'])
      for (final reverse in [false, true]) (false, reverse, media),
  ]) {
    final (corrupt, reverse, media) = scenario;
    test('cross-route handoff corrupt=$corrupt reverse=$reverse media=$media', () async {
      final root = await Directory.systemTemp.createTemp('udp-http-');
      final staging = await Directory('${root.path}/staging').create();
      final cache = ChatDownloadCache(
        root: Directory('${root.path}/cache'),
        key: await AesGcm.with256bits().newSecretKey(),
      );
      const blockSize = ChatFileDownloader.chunkBytes;
      final bytes = Uint8List.fromList(
        List.generate(blockSize * 2 + 3, (i) => i % 251),
      );
      final hash = (await Sha256().hash(bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final ref = ChatFileReference(
        messageId: messageId,
        assetId: assetId,
        fileName: 'handoff.bin',
        size: bytes.length,
        sha256: hash,
        media: media,
        fileId: media == null ? null : assetId,
      );
      final requested = <int>[];
      var peerAttempts = 0;
      final link = _Link();
      Future<void>? feeding;
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'))
        ..httpClientAdapter = DownloadTransport((options) async {
          final index = media == null
              ? int.parse(options.path.split('/').last)
              : int.parse(
                      RegExp(r'^bytes=(\d+)-')
                          .firstMatch(options.headers['range'] as String)![1]!,
                    ) ~/
                    blockSize;
          requested.add(index);
          if (reverse && index == 1) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          }
          final start = index * blockSize;
          final part = bytes.sublist(
            start,
            (start + blockSize).clamp(0, bytes.length),
          );
          return ResponseBody.fromBytes(
            part,
            media == null ? 200 : 206,
            headers: {
              'content-type': [
                media == 'image'
                    ? 'image/webp'
                    : media == 'voice'
                    ? 'audio/mp4'
                    : media == 'video'
                    ? 'video/mp4'
                    : 'application/octet-stream',
              ],
              if (media != null)
                'content-range': [
                  'bytes $start-${start + part.length - 1}/${bytes.length}',
                ],
              'content-length': ['${part.length}'],
            },
          );
        });
      final downloader = ChatFileDownloader(
        repository: MessagingRepository(
          account: 'me',
          call: (_, _) async => {
            'messageId': messageId,
            media ?? 'file': {
              'assetId': assetId,
              if (media != null) 'fileId': assetId,
              'fileName': ref.fileName,
              'size': bytes.length,
              'sha256': hash,
              'chunkBytes': blockSize,
              'chunkCount': 3,
              'contentType': 'application/octet-stream',
              'path': media == null
                  ? '/kingclub/chat-file/$messageId'
                  : '/kingclub/chat-$media/$messageId${media == 'voice' ? '' : '/$media'}',
              'headers': {'authorization': 'Bearer test-only'},
            },
          },
        ),
        checkSession: () async {},
        dio: dio,
        resumeCache: cache,
        temporaryDirectory: () async => staging,
        peerDownload: (_, active) async {
          if (reverse && ++peerAttempts == 1) return null;
          final peer = await NovoRudpFileDownload.open(
            link: link,
            privateDirectory: staging,
            streamId: BigInt.one,
            objectId: BigInt.two,
            size: bytes.length,
            sha256: hash,
            canReceive: active,
          );
          feeding = () async {
            await Future<void>.delayed(Duration.zero);
            const chunk = NovoRudpFileReceiver.chunkSize;
            final count =
                ((reverse ? bytes.length : blockSize) + chunk - 1) ~/ chunk;
            final start = reverse ? blockSize ~/ chunk : 0;
            if (reverse) {
              final imported = Stopwatch()..start();
              while (peer.receivedBytes < start * chunk) {
                if (imported.elapsed > const Duration(seconds: 5)) {
                  throw StateError('Cache was not imported');
                }
                await Future<void>.delayed(const Duration(milliseconds: 1));
              }
            }
            for (var i = start; i < count; i++) {
              final part = bytes.sublist(
                i * chunk,
                ((i + 1) * chunk).clamp(0, bytes.length),
              );
              if (corrupt && i == 0) part[0] ^= 1;
              link.incoming.add(
                NovoRudpFrame(
                  kind: NovoRudpFrameKind.data,
                  sessionId: link.channel.sessionId,
                  streamId: BigInt.one,
                  objectId: BigInt.two,
                  sequence: BigInt.from(i),
                  ackEpoch: BigInt.zero,
                  payload: part,
                ),
              );
              final timer = Stopwatch()..start();
              while (peer.receivedBytes <
                  ((i + 1) * chunk).clamp(0, bytes.length)) {
                if (timer.elapsed > const Duration(seconds: 3)) {
                  throw StateError('Receive stalled');
                }
                await Future<void>.delayed(const Duration(milliseconds: 1));
              }
            }
            if (reverse) {
              link.incoming.add(
                NovoRudpFrame(
                  kind: NovoRudpFrameKind.done,
                  sessionId: link.channel.sessionId,
                  streamId: BigInt.one,
                  objectId: BigInt.two,
                  sequence: BigInt.zero,
                  ackEpoch: BigInt.zero,
                  payload: const [],
                ),
              );
            } else {
              link.incoming.addError(
                const SocketException('peer disconnected'),
              );
            }
          }();
          return peer;
        },
      );
      try {
        if (corrupt) {
          await expectLater(downloader.download(ref), throwsFormatException);
          expect(
            await cache.root
                .list(recursive: true)
                .where((f) => f is File)
                .toList(),
            isEmpty,
          );
        } else {
          final file = await downloader
              .download(ref)
              .timeout(const Duration(seconds: 15));
          expect(await file.readAsBytes(), bytes);
          expect(await staging.list().toList(), hasLength(1));
        }
        await feeding?.timeout(const Duration(seconds: 10));
        expect(requested, reverse ? [0, 1, 1, 1] : [1, 2]);
      } finally {
        await downloader.dispose();
        await link.close();
        expect(await staging.list().toList(), isEmpty);
        await root.delete(recursive: true);
      }
    });
  }
}
