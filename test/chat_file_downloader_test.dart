import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    'direct',
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
      final downloader = ChatFileDownloader(
        repository: repo,
        checkSession: () async {},
        dio: dio,
        temporaryDirectory: () async => dir,
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
      if ([
        'direct',
        'group',
        'empty',
        'session-after-download',
        'expired-grant',
      ].contains(scenario)) {
        final result = await operation;
        expect(await result.readAsBytes(), bytes);
        expect(grants, scenario == 'expired-grant' ? 3 : 2);
        expect(
          requests,
          scenario == 'expired-grant'
              ? 3
              : bytes.isEmpty
              ? 1
              : 2,
        );
        if (scenario == 'expired-grant') expect(requestedBlocks, [0, 1, 1]);
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
        if (scenario == 'wrong-path') expect(requests, 0);
        if (scenario == 'renewal-rejected') expect(requestedBlocks, [0, 1, 1]);
        if (scenario == 'renewal-denied' || scenario == 'renewal-mismatch') {
          expect(requestedBlocks, [0, 1]);
        }
      }
    });
  }
}
