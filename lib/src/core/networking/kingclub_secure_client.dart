import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/domain/auth_repository.dart';

class KingclubSecureClient {
  KingclubSecureClient(String baseUrl)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl.replaceFirst(RegExp(r'/$'), ''),
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
          contentType: Headers.jsonContentType,
        ),
      );

  final Dio _dio;
  final _ecdh = Ecdh.p256(length: 32);
  final _aes = AesGcm.with256bits();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final _hmac = Hmac.sha256();

  Future<Map<String, dynamic>> call(
    String interfaceId,
    Map<String, dynamic> params,
  ) async {
    try {
      final keyPair = await _ecdh.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final clientNonce = 'nonce_${const Uuid().v4()}';
      final publicBytes = <int>[4, ...publicKey.x, ...publicKey.y];
      final handshakeResponse = await _dio.post<Map<String, dynamic>>(
        '/supper-handshake',
        data: {
          'clientPublicKey': _b64(publicBytes),
          'clientNonce': clientNonce,
          'clientType': 'android',
          'clientVersion': '1.0.0',
        },
      );
      final handshake = _map(handshakeResponse.data?['data']);
      final handshakeId = handshake['handshakeId'] as String;
      final serverBytes = _b64decode(handshake['serverPublicKey'] as String);
      if (serverBytes.length != 65 || serverBytes.first != 4) {
        throw const AuthFailure('HANDSHAKE_INVALID', '服务器安全握手无效');
      }
      final shared = await _ecdh.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: EcPublicKey(
          x: serverBytes.sublist(1, 33),
          y: serverBytes.sublist(33, 65),
          type: KeyPairType.p256,
        ),
      );
      final sessionKey = await _derive(
        shared,
        clientNonce,
        'ccsop:supper-handshake:$handshakeId',
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final nonce = 'nonce_${const Uuid().v4()}';
      final requestId = 'request_${const Uuid().v4()}';
      final salt = '$timestamp:$nonce';
      final requestKey = await _derive(
        sessionKey,
        salt,
        'ccsop:supper-interface:request:$requestId',
      );
      final signingKey = await _derive(
        sessionKey,
        salt,
        'ccsop:supper-interface:sign:$requestId',
      );
      final responseKey = await _derive(
        sessionKey,
        salt,
        'ccsop:supper-interface:response:$requestId',
      );
      final payload = await _encrypt(requestKey, {
        'interfaceId': interfaceId,
        'params': params,
      });
      final payloadJson = jsonEncode(payload);
      final digest = await Sha256().hash(utf8.encode(payloadJson));
      final canonical = [
        'POST',
        '/supper-interface',
        handshakeId,
        '',
        timestamp,
        nonce,
        requestId,
        _hex(digest.bytes),
      ].join('\n');
      final signature = await _hmac.calculateMac(
        utf8.encode(canonical),
        secretKey: signingKey,
      );
      final response = await _dio.post<Map<String, dynamic>>(
        '/supper-interface',
        data: {'data': payload, 'sign': _b64(signature.bytes)},
        options: Options(
          headers: {
            'x-handshake-id': handshakeId,
            'x-timestamp': timestamp,
            'x-nonce': nonce,
            'x-request-id': requestId,
          },
        ),
      );
      return await _decrypt(responseKey, _map(response.data?['data']));
    } on AuthFailure {
      rethrow;
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map) {
        throw AuthFailure(
          '${body['code'] ?? 'NETWORK_ERROR'}',
          '${body['message'] ?? '服务暂时不可用，请稍后重试'}',
        );
      }
      throw const AuthFailure('NETWORK_ERROR', '网络连接失败，请稍后重试');
    } catch (_) {
      throw const AuthFailure('SECURE_REQUEST_FAILED', '安全连接失败，请稍后重试');
    }
  }

  Future<SecretKey> _derive(SecretKey key, String salt, String info) =>
      _hkdf.deriveKey(
        secretKey: key,
        nonce: utf8.encode(salt),
        info: utf8.encode(info),
      );

  Future<Map<String, String>> _encrypt(
    SecretKey key,
    Map<String, dynamic> value,
  ) async {
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(value)),
      secretKey: key,
    );
    return {
      'iv': _b64(box.nonce),
      'ciphertext': _b64(box.cipherText),
      'tag': _b64(box.mac.bytes),
    };
  }

  Future<Map<String, dynamic>> _decrypt(
    SecretKey key,
    Map<String, dynamic> payload,
  ) async {
    final clear = await _aes.decrypt(
      SecretBox(
        _b64decode(payload['ciphertext'] as String),
        nonce: _b64decode(payload['iv'] as String),
        mac: Mac(_b64decode(payload['tag'] as String)),
      ),
      secretKey: key,
    );
    return _map(jsonDecode(utf8.decode(clear)));
  }
}

Map<String, dynamic> _map(Object? value) =>
    Map<String, dynamic>.from(value! as Map);
String _b64(List<int> value) => base64Url.encode(value).replaceAll('=', '');
Uint8List _b64decode(String value) => Uint8List.fromList(
  base64Url.decode(value.padRight((value.length + 3) ~/ 4 * 4, '=')),
);
String _hex(List<int> value) =>
    value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
