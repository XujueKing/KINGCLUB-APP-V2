import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/chat_image_uploader.dart';
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
  test('uploader transmits authenticated binary bytes and retains upload identity until message is queued', () async {
    final source = Uint8List.fromList([1, 2, 3, 4, 5]),
        key = List<int>.generate(32, (i) => i);
    final requests = <Map<String, dynamic>>[];
    String aad = '';
    var posts = 0;
    var ready = false;
    final repository = MessagingRepository(
      account: 'me',
      call: (id, params) async {
        expect(id, 'K260913000631');
        requests.add(params);
        if (ready) {
          return {
            'assetId': asset,
            'status': 'ready',
            'width': 40,
            'height': 20,
          };
        }
        aad = jsonEncode([
          'kingclub:chat-image-upload:v1',
          'grant',
          asset,
          'me',
          params['sha256'],
          source.length,
        ]);
        return {
          'assetId': asset,
          'status': 'pending',
          'upload': {
            'path': '/kingclub/chat-image-upload',
            'algorithm': 'AES-256-GCM',
            'wireFormat': 'iv12-tag16-ciphertext',
            'aad': aad,
            'key': base64UrlEncode(key),
            'token': 'private grant',
          },
        };
      },
    );
    Dio transport() =>
        Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
          ..httpClientAdapter = Transport((options, wire) async {
            posts++;
            expect(options.followRedirects, false);
            expect(options.headers['authorization'], 'Bearer private grant');
            expect(wire.length, source.length + 28);
            final decoded = await AesGcm.with256bits().decrypt(
              SecretBox(
                wire.sublist(28),
                nonce: wire.sublist(0, 12),
                mac: Mac(wire.sublist(12, 28)),
              ),
              secretKey: SecretKey(key),
              aad: utf8.encode(aad),
            );
            expect(decoded, source);
            // Server committed but client did not receive the response.
            ready = true;
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          });
    final original = Uint8List.fromList([99, 98]);
    final first = ChatImageUploader(
      repository: repository,
      checkSession: () async {},
      dio: transport(),
      prepareSource: (_) async => source,
    );
    await expectLater(first.upload(original), throwsA(isA<AuthFailure>()));
    first.dispose();
    final second = ChatImageUploader(
      repository: repository,
      checkSession: () async {},
      dio: transport(),
      prepareSource: (_) async => source,
    );
    final image = await second.upload(original);
    expect(image.assetId, asset);
    expect(image.sourceBytes, source);
    expect(posts, 1);
    expect(requests[0]['clientUploadId'], requests[1]['clientUploadId']);
    await second.upload(original);
    expect(requests[2]['clientUploadId'], requests[1]['clientUploadId']);
    await second.acknowledgeQueued(image);
    await second.upload(original);
    expect(requests[3]['clientUploadId'], isNot(requests[2]['clientUploadId']));
    second.dispose();
  });
  test('session invalidation prevents requests and oversized input never starts upload', () async {
    var calls = 0;
    final uploader = ChatImageUploader(
      repository: MessagingRepository(
        account: 'me',
        call: (_, _) async {
          calls++;
          return {};
        },
      ),
      checkSession: () async {},
      dio: Dio(),
    );
    await expectLater(
      uploader.upload(Uint8List(20 * 1024 * 1024 + 1)),
      throwsArgumentError,
    );
    expect(calls, 0);
    SecureSessionStore.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      uploader.upload(Uint8List.fromList([1])),
      throwsA(isA<AuthFailure>()),
    );
    expect(calls, 0);
    uploader.dispose();
  });
  test('foreign upload binding is rejected before binary transport', () async {
    var posts = 0;
    final uploader = ChatImageUploader(
      repository: MessagingRepository(
        account: 'me',
        call: (_, params) async => {
          'assetId': asset,
          'status': 'pending',
          'upload': {
            'path': '/kingclub/chat-image-upload',
            'algorithm': 'AES-256-GCM',
            'wireFormat': 'iv12-tag16-ciphertext',
            'aad': jsonEncode([
              'kingclub:chat-image-upload:v1',
              'grant',
              asset,
              'someone-else',
              params['sha256'],
              params['size'],
            ]),
            'key': base64UrlEncode(List.filled(32, 1)),
            'token': 'grant',
          },
        },
      ),
      checkSession: () async {},
      dio: Dio()
        ..httpClientAdapter = Transport((_, _) async {
          posts++;
          throw StateError('must not transmit');
        }),
    );
    addTearDown(uploader.dispose);
    await expectLater(
      uploader.upload(Uint8List.fromList([1])),
      throwsFormatException,
    );
    expect(posts, 0);
  });
  test(
    'session change while requesting grant discards late ready result',
    () async {
      var current = true;
      final uploader = ChatImageUploader(
        repository: MessagingRepository(
          account: 'me',
          call: (_, _) async {
            current = false;
            return {
              'assetId': asset,
              'status': 'ready',
              'width': 1,
              'height': 1,
            };
          },
        ),
        checkSession: () async {
          if (!current) throw const AuthFailure('SESSION_CHANGED', 'changed');
        },
        dio: Dio(),
      );
      addTearDown(uploader.dispose);
      await expectLater(
        uploader.upload(Uint8List.fromList([1])),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
}
