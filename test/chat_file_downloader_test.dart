import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';

class DownloadTransport implements HttpClientAdapter {
  DownloadTransport(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) => handler(options);
  @override
  void close({bool force = false}) {}
}

const messageId = '12345678-1234-1234-1234-123456789012';
const assetId = '22345678-1234-1234-1234-123456789012';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'deleted file message cannot restart a download or request a grant',
    () async {
      final root = await Directory.systemTemp.createTemp('deleted-download-');
      addTearDown(() => root.delete(recursive: true));
      final cache = ChatDownloadCache(
        root: root,
        key: await AesGcm.with256bits().newSecretKey(),
      );
      final hash = 'a' * 64;
      final ref = ChatFileReference(
        messageId: messageId,
        assetId: assetId,
        fileName: 'file.bin',
        size: 3,
        sha256: hash,
      );
      await cache.removePermanently(
        jsonEncode(['me', false, messageId, assetId, 3, hash, 'file.bin']),
      );
      var grants = 0;
      final downloader = ChatFileDownloader(
        repository: MessagingRepository(
          account: 'me',
          call: (_, _) async {
            grants++;
            throw StateError('Unexpected network request');
          },
        ),
        checkSession: () async {},
        resumeCache: cache,
      );
      addTearDown(downloader.dispose);
      await expectLater(downloader.download(ref), throwsStateError);
      expect(grants, 0);
      await expectLater(
        cache.ensureNotDeleted(
          jsonEncode(['me', false, messageId, assetId, 3, hash, 'file.bin']),
        ),
        throwsStateError,
      );
    },
  );
  for (final scenario in [
    'direct',
    'peer-unavailable',
    'peer-connect-cancel',
    'group',
    'empty',
    'corrupt',
    'oversize',
    'revoked',
    'cancel',
    'wrong-path',
    'session-during-download',
    'session-before-grant-return',
    'session-after-download',
    'expired-grant',
    'renewal-denied',
    'renewal-mismatch',
    'renewal-rejected',
    'connection-retry',
    'stream-retry',
    'truncated-retry',
    'retry-exhausted',
    'socket-retry',
    'dispose-before-directory',
    'delete-before-directory',
    'delete-completed',
  ]) {
    test('private chunk file download: $scenario', () async {
      final dir = await Directory.systemTemp.createTemp('chat-download-test-');
      addTearDown(() => dir.delete(recursive: true));
      final bytes = Uint8List.fromList(
        List.generate(
          scenario == 'empty' ? 0 : 1024 * 1024 + 3,
          (i) => i % 251,
        ),
      );
      final hash = (await Sha256().hash(bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final group = scenario == 'group';
      final ref = ChatFileReference(
        messageId: messageId,
        assetId: assetId,
        fileName: '测试文件.bin',
        size: bytes.length,
        sha256: hash,
        group: group,
      );
      var grants = 0, requests = 0;
      final requestedBlocks = <int>[];
      final repo = MessagingRepository(
        account: 'test-account',
        call: (id, params) async {
          expect(id, group ? 'K260914000654' : 'K260914000652');
          expect(params, {'messageId': messageId});
          grants++;
          if (scenario == 'session-before-grant-return') {
            SecureSessionStore.changes.add(null);
            await Future<void>.delayed(Duration.zero);
          }
          if ((scenario == 'revoked' || scenario == 'renewal-denied') &&
              grants == 2) {
            throw StateError('permission revoked');
          }
          return {
            'messageId': messageId,
            'file': {
              'assetId': scenario == 'renewal-mismatch' && grants == 2
                  ? messageId
                  : assetId,
              'fileName': ref.fileName,
              'size': bytes.length,
              'sha256': hash,
              'chunkBytes': 1024 * 1024,
              'chunkCount': bytes.isEmpty ? 1 : 2,
              'contentType': 'application/octet-stream',
              'path': scenario == 'wrong-path'
                  ? 'https://foreign.invalid/file'
                  : '/kingclub/${group ? 'group-chat-file' : 'chat-file'}/$messageId',
              'headers': {'authorization': 'Bearer synthetic-test-$grants'},
            },
          };
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = DownloadTransport((options) async {
          requests++;
          expect(options.followRedirects, false);
          expect(
            options.headers['authorization'],
            'Bearer synthetic-test-$grants',
          );
          final index = int.parse(options.path.split('/').last);
          requestedBlocks.add(index);
          if (index == 1 &&
              (scenario == 'retry-exhausted' ||
                  (scenario == 'connection-retry' && requests == 2))) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          }
          if (index == 1 &&
              [
                'expired-grant',
                'renewal-denied',
                'renewal-mismatch',
                'renewal-rejected',
              ].contains(scenario) &&
              (requests == 2 || scenario == 'renewal-rejected')) {
            return ResponseBody.fromString('denied', 403);
          }
          final begin = index * 1024 * 1024;
          final end = (begin + 1024 * 1024).clamp(0, bytes.length);
          final chunk = Uint8List.fromList(bytes.sublist(begin, end));
          if (scenario == 'corrupt' && chunk.isNotEmpty) chunk[0] ^= 1;
          final wire = scenario == 'oversize'
              ? Uint8List.fromList([...chunk, 9])
              : chunk;
          if (index == 1 &&
              requests == 2 &&
              ['stream-retry', 'truncated-retry'].contains(scenario)) {
            Stream<Uint8List> broken() async* {
              yield Uint8List.fromList([wire.first]);
              if (scenario == 'stream-retry') {
                throw const SocketException('lost network');
              }
            }

            return ResponseBody(
              broken(),
              200,
              headers: {
                'content-type': ['application/octet-stream'],
                'content-length': ['${wire.length}'],
              },
            );
          }
          return ResponseBody(
            Stream.fromIterable([
              for (var offset = 0; offset < wire.length; offset += 8192)
                Uint8List.sublistView(
                  wire,
                  offset,
                  (offset + 8192).clamp(0, wire.length),
                ),
            ]),
            200,
            headers: {
              'content-type': ['application/octet-stream'],
              // Oversize case has no declared length, so stream bounds must reject it.
              if (scenario != 'oversize') 'content-length': ['${wire.length}'],
            },
          );
        });
      if (scenario == 'socket-retry') {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          requests++;
          final index = int.parse(request.uri.pathSegments.last);
          requestedBlocks.add(index);
          final begin = index * 1024 * 1024;
          final chunk = bytes.sublist(
            begin,
            (begin + 1024 * 1024).clamp(0, bytes.length),
          );
          request.response.headers.contentType = ContentType.binary;
          request.response.contentLength = chunk.length;
          if (index == 1 && requests == 2) {
            final socket = await request.response.detachSocket(
              writeHeaders: false,
            );
            socket.add(
              ascii.encode(
                'HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: ${chunk.length}\r\nConnection: close\r\n\r\n',
              ),
            );
            socket.add([chunk.first]);
            await socket.flush();
            socket.destroy();
          } else {
            request.response.add(chunk);
            await request.response.close();
          }
        });
        dio.options.baseUrl = 'http://127.0.0.1:${server.port}';
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () => HttpOverrides.runWithHttpOverrides(
            () => HttpClient(),
            RealHttpOverrides(),
          ),
        );
      }
      final directoryEntered = Completer<void>();
      final directoryRelease = Completer<Directory>();
      final peerEntered = Completer<void>(), peerRelease = Completer<void>();
      final downloader = ChatFileDownloader(
        repository: repo,
        peerDownload: scenario == 'peer-unavailable'
            ? (_, _) async => throw const SocketException('peer unavailable')
            : scenario == 'peer-connect-cancel'
            ? (_, _) async {
                peerEntered.complete();
                await peerRelease.future;
                return null;
              }
            : null,
        checkSession: () async {},
        dio: dio,
        temporaryDirectory: () async {
          if (scenario == 'dispose-before-directory' ||
              scenario == 'delete-before-directory') {
            directoryEntered.complete();
            return directoryRelease.future;
          }
          return dir;
        },
      );
      addTearDown(downloader.dispose);
      final operation = downloader.download(
        ref,
        onProgress: (received, total) {
          expect(received, lessThanOrEqualTo(total));
          if (scenario == 'cancel') downloader.cancel();
          if (scenario == 'session-during-download') {
            SecureSessionStore.changes.add(null);
          }
        },
      );
      if (scenario == 'peer-connect-cancel') {
        final rejected = expectLater(operation, throwsA(anything));
        await peerEntered.future;
        downloader.cancel();
        await rejected.timeout(const Duration(milliseconds: 500));
        peerRelease.complete();
        await Future<void>.delayed(Duration.zero);
        expect(requests, 0);
        expect(await dir.list().toList(), isEmpty);
        return;
      }
      if (scenario == 'delete-before-directory') {
        final rejected = expectLater(operation, throwsA(anything));
        await directoryEntered.future;
        final deletion = const ChatMediaDeletion(
          'test-account',
          false,
          messageId,
        ).dispatch();
        directoryRelease.complete(dir);
        await rejected;
        await deletion;
        expect(requests, 0);
        expect(await dir.list().toList(), isEmpty);
        await expectLater(downloader.download(ref), throwsStateError);
        return;
      }
      if (scenario == 'dispose-before-directory') {
        final rejected = expectLater(operation, throwsA(anything));
        await directoryEntered.future;
        var finished = false;
        final disposal = downloader.dispose();
        disposal.then((_) => finished = true);
        expect(identical(disposal, downloader.dispose()), true);
        await Future<void>.delayed(Duration.zero);
        expect(finished, false);
        directoryRelease.complete(dir);
        await rejected;
        await disposal;
        expect(finished, true);
        expect(await dir.list().toList(), isEmpty);
        await expectLater(downloader.download(ref), throwsA(anything));
        expect(requests, 0);
        return;
      }
      if ([
        'direct',
        'delete-completed',
        'peer-unavailable',
        'group',
        'empty',
        'session-after-download',
        'expired-grant',
        'connection-retry',
        'stream-retry',
        'truncated-retry',
        'socket-retry',
      ].contains(scenario)) {
        final result = await operation;
        expect(await result.readAsBytes(), bytes);
        expect(
          grants,
          ['expired-grant', 'peer-unavailable'].contains(scenario) ? 3 : 2,
        );
        expect(
          requests,
          [
                'expired-grant',
                'connection-retry',
                'stream-retry',
                'truncated-retry',
                'socket-retry',
              ].contains(scenario)
              ? 3
              : bytes.isEmpty
              ? 1
              : 2,
        );
        if (scenario == 'expired-grant') expect(requestedBlocks, [0, 1, 1]);
        if ([
          'connection-retry',
          'stream-retry',
          'truncated-retry',
          'socket-retry',
        ].contains(scenario)) {
          expect(requestedBlocks, [0, 1, 1]);
        }
        if (scenario == 'delete-completed') {
          await const ChatMediaDeletion(
            'other-account',
            false,
            messageId,
          ).dispatch();
          await const ChatMediaDeletion(
            'test-account',
            true,
            messageId,
          ).dispatch();
          expect(await result.exists(), true);
          await const ChatMediaDeletion(
            'test-account',
            false,
            messageId,
          ).dispatch();
          expect(await result.exists(), false);
          await expectLater(downloader.authorizeExport(ref), throwsStateError);
          await expectLater(downloader.download(ref), throwsStateError);
        }
        if (scenario == 'session-after-download') {
          SecureSessionStore.changes.add(null);
          await Future<void>.delayed(Duration.zero);
          await expectLater(downloader.authorizeExport(ref), throwsA(anything));
          // Dispose joins cleanup so the assertion does not race the filesystem.
        }
        await downloader.dispose();
        expect(await result.exists(), false);
      } else {
        await expectLater(operation, throwsA(anything));
        expect(await dir.list().toList(), isEmpty);
        if (scenario == 'retry-exhausted') {
          expect(requestedBlocks, [0, 1, 1, 1]);
        }
        if (scenario == 'wrong-path') expect(requests, 0);
        if (scenario == 'renewal-rejected') expect(requestedBlocks, [0, 1, 1]);
        if (scenario == 'renewal-denied' || scenario == 'renewal-mismatch') {
          expect(requestedBlocks, [0, 1]);
        }
      }
    });
  }
}
