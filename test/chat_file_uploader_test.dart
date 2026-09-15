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
  test('revoked session after file scan prevents upload intent', () async {
    final dir = await Directory.systemTemp.createTemp('kingclub-hash-auth-');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File('${dir.path}/fixture.bin')
        .writeAsBytes(Uint8List(2 * 1024 * 1024));
    var checks = 0, calls = 0;
    final uploader = ChatFileUploader(
      repository: MessagingRepository(
        account: 'me',
        call: (_, _) async {
          calls++;
          throw StateError('must not create upload');
        },
      ),
      checkSession: () async {
        if (++checks > 1) {
          throw const AuthFailure('SESSION_CHANGED', 'revoked');
        }
      },
    );
    addTearDown(uploader.dispose);
    await expectLater(
      uploader.upload(file, fileName: 'fixture.bin'),
      throwsA(isA<AuthFailure>()),
    );
    expect(calls, 0);
    expect(checks, 2);
  });
  for (final scenario in [
    'lost',
    'transient',
    'timeout',
    'gateway',
    'renew',
    'denied',
    'changed',
    'rejected',
    'unicode',
  ]) {
    final automatic = ['transient', 'timeout', 'gateway'].contains(scenario);
    final renew = !['lost', 'unicode'].contains(scenario) && !automatic;
    final inputName = scenario == 'unicode' ? 'cafe\u0301.bin' : 'fixture.bin';
    final canonicalName = scenario == 'unicode'
        ? 'caf\u00e9.bin'
        : 'fixture.bin';
    test(
      'file upload resumes acknowledged chunks; renewal scenario=$scenario',
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
        final nonces = <String>{};
        Map<String, dynamic> meta = {};
        final repo = MessagingRepository(
          account: 'me',
          call: (id, p) async {
            if (id == 'K260914000650') {
              ready = true;
              return {...meta, 'status': 'ready'};
            }
            expect(id, 'K260914000649');
            expect(p['fileName'], canonicalName);
            ids.add(p['clientUploadId'] as String);
            if (scenario == 'denied' && ids.length == 2) {
              throw const AuthFailure('SESSION_REVOKED', 'revoked');
            }
            for (var i = 0; i < key.length; i++) {
              key[i] = (i + ids.length) % 256;
            }
            meta = {
              'assetId': scenario == 'changed' && ids.length == 2
                  ? '22345678-1234-1234-1234-123456789012'
                  : asset,
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
        Dio transport() => Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
          ..httpClientAdapter = Transport((options, wire) async {
            posts++;
            expect(
              nonces.add(base64Encode(wire.sublist(0, 12))),
              isTrue,
              reason: 'Each transmission must use a fresh GCM nonce',
            );
            final index = int.parse(options.path.split('/').last);
            expect(options.followRedirects, false);
            if (renew &&
                (posts == 2 || (scenario == 'rejected' && posts == 3))) {
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
            if (!renew && (!lost || (!automatic && posts == 2))) {
              lost = true;
              throw DioException(
                requestOptions: options,
                type: scenario == 'timeout'
                    ? DioExceptionType.receiveTimeout
                    : scenario == 'gateway'
                    ? DioExceptionType.badResponse
                    : DioExceptionType.connectionError,
                response: scenario == 'gateway'
                    ? Response(requestOptions: options, statusCode: 503)
                    : null,
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
        if (['denied', 'changed', 'rejected'].contains(scenario)) {
          try {
            await expectLater(
              first.upload(file, fileName: inputName),
              throwsA(anything),
            );
            expect(posts, scenario == 'rejected' ? 3 : 2);
            expect(ids.length, 2);
            expect(ids.toSet().length, 1);
            expect(ready, false);
            expect(uploaded.keys, [0]);
          } finally {
            first.dispose();
          }
          return;
        }
        if (renew || automatic) {
          await first.upload(file, fileName: inputName);
        } else {
          await expectLater(
            first.upload(file, fileName: inputName),
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
        final result = await second.upload(file, fileName: canonicalName);
        expect(result.fileName, canonicalName);
        expect(result.assetId, asset);
        expect(result.size, bytes.length);
        expect(posts, 3);
        expect(ids[0], ids[1]);
        await second.upload(file, fileName: inputName);
        expect(posts, 3);
        SecureSessionStore.changes.add(null);
        await Future<void>.delayed(Duration.zero);
        await expectLater(
          second.upload(file, fileName: inputName),
          throwsA(isA<AuthFailure>()),
        );
      },
    );
  }
}
