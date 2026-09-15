import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_image_uploader.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_uploader.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

class UploadTransport implements HttpClientAdapter {
  UploadTransport(this.handle);
  final Future<ResponseBody> Function(RequestOptions, Uint8List) handle;
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
    return handle(options, bytes.takeBytes());
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final kind in ['image', 'voice']) {
    for (final permanent in [false, true]) {
      test(
        '$kind renews a denied grant only once; permanent=$permanent',
        () async {
          const asset = '12345678-1234-1234-1234-123456789012';
          final source = Uint8List.fromList([1, 2, 3, 4]);
          final ids = <Object?>[];
          final wires = <Uint8List>[];
          var aad = '';
          var key = <int>[];
          final repository = MessagingRepository(
            account: 'me',
            call: (id, params) async {
              ids.add(params['clientUploadId']);
              key = List.filled(32, ids.length);
              aad = jsonEncode([
                'kingclub:chat-$kind-upload:v1',
                'grant-${ids.length}',
                asset,
                'me',
                params['sha256'],
                source.length,
              ]);
              return {
                'assetId': asset,
                'status': 'pending',
                'upload': {
                  'path': '/kingclub/chat-$kind-upload',
                  'algorithm': 'AES-256-GCM',
                  'wireFormat': 'iv12-tag16-ciphertext',
                  'aad': aad,
                  'key': base64UrlEncode(key),
                  'token': 'grant-${ids.length}',
                },
              };
            },
          );
          final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
            ..httpClientAdapter = UploadTransport((options, wire) async {
              wires.add(wire);
              expect(
                options.headers['authorization'],
                'Bearer grant-${ids.length}',
              );
              final plain = await AesGcm.with256bits().decrypt(
                SecretBox(
                  wire.sublist(28),
                  nonce: wire.sublist(0, 12),
                  mac: Mac(wire.sublist(12, 28)),
                ),
                secretKey: SecretKey(key),
                aad: utf8.encode(aad),
              );
              expect(plain, source);
              if (wires.length == 1 || permanent) {
                return ResponseBody.fromString(
                  jsonEncode({
                    'code': 'CHAT_${kind.toUpperCase()}_UPLOAD_DENIED',
                    'message': 'expired grant',
                  }),
                  403,
                  headers: {
                    'content-type': ['application/json'],
                  },
                );
              }
              return ResponseBody.fromString(
                jsonEncode({
                  'status': 1,
                  'data': {
                    'assetId': asset,
                    'status': 'ready',
                    'width': 10,
                    'height': 10,
                    'durationMs': 2000,
                    'codec': 'aac-lc',
                    'sampleRate': 24000,
                    'channels': 1,
                  },
                }),
                200,
                headers: {
                  'content-type': ['application/json'],
                },
              );
            });
          Future<Object> Function(Uint8List) send;
          if (kind == 'image') {
            final uploader = ChatImageUploader(
              repository: repository,
              checkSession: () async {},
              dio: dio,
            );
            addTearDown(uploader.dispose);
            send = (bytes) => uploader.upload(bytes);
          } else {
            final uploader = ChatVoiceUploader(
              repository: repository,
              checkSession: () async {},
              dio: dio,
            );
            addTearDown(uploader.dispose);
            send = (bytes) => uploader.upload(bytes);
          }
          if (permanent) {
            await expectLater(send(source), throwsA(isA<AuthFailure>()));
          } else {
            await send(source);
          }
          expect(ids, hasLength(2));
          expect(ids[0], ids[1]);
          expect(wires, hasLength(2));
          expect(wires[0].sublist(0, 12), isNot(wires[1].sublist(0, 12)));
        },
      );
    }
  }
}
