import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'chat_file_downloader_test.dart'
    show DownloadTransport, RealHttpOverrides, messageId, assetId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    'resume',
    'corrupt-cache',
    'revoked',
    'leave-page',
    'socket-resume',
    'group-resume',
    'peer-resume',
    'peer-corrupt-cache',
  ]) {
    test('encrypted file resume across downloader recreation: $scenario', () async {
      final root = await Directory.systemTemp.createTemp('chat-resume-test-');
      addTearDown(() => root.delete(recursive: true));
      final temp = await Directory('${root.path}/plain').create();
      final cacheRoot = Directory('${root.path}/encrypted');
      final key = await AesGcm.with256bits().newSecretKey();
      ChatDownloadCache cache() => ChatDownloadCache(root: cacheRoot, key: key);
      final bytes = Uint8List.fromList(
        List.generate(1024 * 1024 + 3, (i) => i % 251),
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
        group: scenario == 'group-resume',
      );
      var first = true;
      var grants = 0;
      var offline = false;
      var peerAttempts = 0;
      final requested = <int>[];
      HttpServer? server;
      if (scenario == 'socket-resume') {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server!.close(force: true));
        server.listen((request) async {
          expect(request.headers.value('authorization'), 'Bearer test-only');
          final index = int.parse(request.uri.pathSegments.last);
          requested.add(index);
          final block = bytes.sublist(
            index * 1024 * 1024,
            index == 0 ? 1024 * 1024 : bytes.length,
          );
          if (first && index == 1) {
            final socket = await request.response.detachSocket(
              writeHeaders: false,
            );
            socket.add(
              ascii.encode(
                'HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: ${block.length}\r\nConnection: close\r\n\r\n',
              ),
            );
            socket.add([block.first]);
            await socket.flush();
            socket.destroy();
          } else {
            request.response.headers.contentType = ContentType.binary;
            request.response.contentLength = block.length;
            request.response.add(block);
            await request.response.close();
          }
        });
      }
      final repo = MessagingRepository(
        account: 'me',
        call: (method, params) async {
          if (offline) throw const SocketException('offline');
          expect(method, ref.group ? 'K260914000654' : 'K260914000652');
          expect(params, {'messageId': messageId});
          grants++;
          if (!first && scenario == 'revoked') {
            throw const AuthFailure('CHAT_ACCESS_DENIED', 'revoked');
          }
          return {
            'messageId': messageId,
            'file': {
              'assetId': assetId,
              'fileName': ref.fileName,
              'size': bytes.length,
              'sha256': hash,
              'chunkBytes': 1024 * 1024,
              'chunkCount': 2,
              'contentType': 'application/octet-stream',
              'path':
                  '/kingclub/${ref.group ? 'group-chat-file' : 'chat-file'}/$messageId',
              'headers': {'authorization': 'Bearer test-only'},
            },
          };
        },
      );
      late ChatFileDownloader download;
      ChatFileDownloader downloader() {
        final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
        dio.httpClientAdapter = DownloadTransport((options) async {
          final index = int.parse(options.path.split('/').last);
          requested.add(index);
          if (first && index == 1) {
            if (scenario == 'leave-page') unawaited(download.dispose());
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          }
          final block = bytes.sublist(
            index * 1024 * 1024,
            index == 0 ? 1024 * 1024 : bytes.length,
          );
          return ResponseBody.fromBytes(
            block,
            200,
            headers: {
              Headers.contentTypeHeader: ['application/octet-stream'],
              Headers.contentLengthHeader: ['${block.length}'],
            },
          );
        });
        if (server != null) {
          dio.options.baseUrl = 'http://127.0.0.1:${server.port}';
          dio.httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => HttpOverrides.runWithHttpOverrides(
              () => HttpClient(),
              RealHttpOverrides(),
            ),
          );
        }
        return ChatFileDownloader(
          repository: repo,
          checkSession: () async {},
          dio: dio,
          temporaryDirectory: () async => temp,
          resumeCache: cache(),
          peerDownload: !first && scenario.startsWith('peer-')
              ? (_, _) async {
                  peerAttempts++;
                  return null;
                }
              : null,
        );
      }

      download = downloader();
      await expectLater(
        download.download(ref),
        throwsA(
          scenario == 'leave-page'
              ? isA<AuthFailure>()
              : anyOf(isA<DioException>(), isA<HttpException>()),
        ),
      );
      await download.dispose();
      expect(await temp.list().toList(), isEmpty);
      expect(requested, scenario == 'leave-page' ? [0, 1] : [0, 1, 1, 1]);
      final blocks = await cacheRoot
          .list(recursive: true)
          .where((e) => e is File)
          .cast<File>()
          .toList();
      expect(blocks, hasLength(1));
      final encrypted = await blocks.single.readAsBytes();
      expect(encrypted.length, 1024 * 1024 + 28);
      expect(encrypted.sublist(0, 100), isNot(bytes.sublist(0, 100)));
      if (scenario.endsWith('corrupt-cache')) {
        encrypted[30] ^= 1;
        await blocks.single.writeAsBytes(encrypted);
      }
      requested.clear();
      first = false;
      download = downloader();
      if (scenario == 'revoked') {
        await expectLater(download.download(ref), throwsA(isA<AuthFailure>()));
        expect(requested, isEmpty);
      } else {
        final result = await download.download(ref);
        expect(await result.readAsBytes(), bytes);
        expect(requested, scenario.endsWith('corrupt-cache') ? [0, 1] : [1]);
      }
      expect(peerAttempts, scenario.startsWith('peer-') ? 1 : 0);
      expect(
        grants,
        scenario == 'revoked'
            ? 2
            : scenario.startsWith('peer-')
            ? 4
            : 3,
      );
      final retained = await cacheRoot
          .list(recursive: true)
          .where((e) => e is File)
          .toList();
      expect(retained, scenario == 'revoked' ? isEmpty : hasLength(3));
      await download.dispose();
      expect(await temp.list().toList(), isEmpty);
      if (scenario != 'revoked') {
        // Completed blocks are durable, unlike the plaintext export copy.
        // Recreate the downloader and prove full restoration without grants
        // or block requests, including the group and corrupt-resume cases.
        offline = true;
        requested.clear();
        final grantsBeforeOffline = grants;
        download = downloader();
        final restored = await download.download(ref);
        expect(await restored.readAsBytes(), bytes);
        expect(requested, isEmpty);
        expect(grants, grantsBeforeOffline);
        await download.dispose();
        expect(await temp.list().toList(), isEmpty);
      }
    });
  }
}
