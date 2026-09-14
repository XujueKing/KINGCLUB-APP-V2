import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_uploader.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

class Transport implements HttpClientAdapter {
  Transport(this.handler);
  final Future<ResponseBody> Function(RequestOptions, Uint8List) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final bytes = BytesBuilder();
    await for (final chunk in stream!) {
      bytes.add(chunk);
    }
    return handler(options, bytes.takeBytes());
  }

  @override
  void close({bool force = false}) {}
}

const asset = '12345678-1234-1234-1234-123456789012';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final renew in [false, true]) {
    test(
      'file upload resumes acknowledged chunks; expired grant=$renew',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'kingclub-file-test-',
        );
        addTearDown(() => dir.delete(recursive: true));
        final bytes = Uint8List.fromList(
          List.generate(1024 * 1024 + 3, (i) => i % 251),
        );
        final file = await File('${dir.path}/fixture.bin').writeAsBytes(bytes);
        final key = List<int>.generate(32, (i) => i),
            ids = <String>[],
            uploaded = <int, Map<String, dynamic>>{};
        var aad = '', lost = false, posts = 0, ready = false;
        Map<String, dynamic> meta = {};
        final repo = MessagingRepository(
          account: 'me',
          call: (id, p) async {
            if (id == 'K260914000650') {
              ready = true;
              return {...meta, 'status': 'ready'};
            }
            expect(id, 'K260914000649');
            ids.add(p['clientUploadId'] as String);
            for (var i = 0; i < key.length; i++) {
              key[i] = (i + ids.length) % 256;
            }
            meta = {
              'assetId': asset,
              'fileName': p['fileName'],
              'size': bytes.length,
              'sha256': p['sha256'],
              'chunkCount': 2,
            };
            aad = jsonEncode([
              'kingclub:chat-file-upload:v1',
              'grant-${ids.length}',
              asset,
              'me',
              p['fileName'],
              p['sha256'],
              bytes.length,
            ]);
            return {
              ...meta,
              'status': ready ? 'ready' : 'pending',
              'uploaded': uploaded.values.toList(),
              'upload': {
                'path': '/kingclub/chat-file-upload/$asset',
                'algorithm': 'AES-256-GCM',
                'wireFormat': 'iv12-tag16-ciphertext',
                'chunkBytes': 1024 * 1024,
                'chunkCount': 2,
                'aad': aad,
                'key': base64UrlEncode(key),
                'token': 'test-grant',
              },
            };
          },
        );
        Dio transport() =>
            Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
              ..httpClientAdapter = Transport((options, wire) async {
                posts++;
                final index = int.parse(options.path.split('/').last);
                expect(options.followRedirects, false);
                if (renew && posts == 2) {
                  return ResponseBody.fromString(
                    '{}',
                    403,
                    headers: {
                      'content-type': ['application/json'],
                    },
                  );
                }
                final derived = await Hmac.sha256().calculateMac(
                  utf8.encode('chat-file-chunk-key:v1:$index'),
                  secretKey: SecretKey(key),
                );
                final plain = await AesGcm.with256bits().decrypt(
                  SecretBox(
                    wire.sublist(28),
                    nonce: wire.sublist(0, 12),
                    mac: Mac(wire.sublist(12, 28)),
                  ),
                  secretKey: SecretKey(derived.bytes),
                  aad: utf8.encode(
                    jsonEncode([aad, index, index == 0 ? 1024 * 1024 : 3]),
                  ),
                );
                expect(
                  plain,
                  bytes.sublist(
                    index * 1024 * 1024,
                    index == 0 ? 1024 * 1024 : bytes.length,
                  ),
                );
                final hash = (await Sha256().hash(plain)).bytes
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join();
                uploaded[index] = {
                  'index': index,
                  'size': plain.length,
                  'sha256': hash,
                };
                if (!renew && !lost) {
                  lost = true;
                  throw DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                  );
                }
                return ResponseBody.fromString(
                  jsonEncode({
                    'status': 1,
                    'data': {'assetId': asset, 'index': index, 'sha256': hash},
                  }),
                  201,
                  headers: {
                    'content-type': ['application/json'],
                  },
                );
              });
        final first = ChatFileUploader(
          repository: repo,
          checkSession: () async {},
          dio: transport(),
        );
        if (renew) {
          await first.upload(file, fileName: 'fixture.bin');
        } else {
          await expectLater(
            first.upload(file, fileName: 'fixture.bin'),
            throwsA(isA<AuthFailure>()),
          );
        }
        first.dispose();
        final second = ChatFileUploader(
          repository: repo,
          checkSession: () async {},
          dio: transport(),
        );
        addTearDown(second.dispose);
        final result = await second.upload(file, fileName: 'fixture.bin');
        expect(result.assetId, asset);
        expect(result.size, bytes.length);
        expect(posts, renew ? 3 : 2);
        expect(ids[0], ids[1]);
        await second.upload(file, fileName: 'fixture.bin');
        expect(posts, renew ? 3 : 2);
        SecureSessionStore.changes.add(null);
        await Future<void>.delayed(Duration.zero);
        await expectLater(
          second.upload(file, fileName: 'fixture.bin'),
          throwsA(isA<AuthFailure>()),
        );
      },
    );
  }
}
