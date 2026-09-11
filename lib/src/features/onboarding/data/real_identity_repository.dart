import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';

final realIdentityRepositoryProvider = Provider(
  (ref) => RealIdentityRepository(
    KingclubSecureClient(kingclubApiBaseUrl),
    SecureSessionStore(),
    kingclubApiBaseUrl,
  ),
);

class RealIdentityRepository {
  RealIdentityRepository(this._client, this._sessions, String baseUrl)
    : _upload = Dio(
        BaseOptions(
          baseUrl: baseUrl.replaceFirst(RegExp(r'/$'), ''),
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 40),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
  final KingclubSecureClient _client;
  final SecureSessionStore _sessions;
  final Dio _upload;

  Future<Map<String, dynamic>> _call(
    String id,
    Map<String, dynamic> params,
  ) async {
    final session = await _sessions.readSession();
    if (session == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    return _client.call(
      id,
      params,
      session: session,
      receiveTimeout: const Duration(seconds: 35),
    );
  }

  Future<Map<String, dynamic>> status() => _call('K260911000203', {});

  Future<Uint8List?> capture() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 2000,
      maxHeight: 2000,
      requestFullMetadata: false,
    );
    if (photo == null) return null;
    // Native decoding avoids loading a full-resolution source into Dart memory.
    for (final quality in [88, 82, 76]) {
      final bytes = await FlutterImageCompress.compressWithFile(
        photo.path,
        minWidth: 1600,
        minHeight: 1600,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
        autoCorrectionAngle: true,
      );
      if (bytes != null && bytes.isNotEmpty && bytes.length <= 2000000) {
        return bytes;
      }
    }
    throw const AuthFailure('PHOTO_COMPRESSION_FAILED', '照片处理失败，请重新拍摄');
  }

  Future<String> upload(
    Uint8List photo,
    void Function(int, int) onProgress,
  ) async {
    final digest = await Sha256().hash(photo);
    final ticket = await _call('K260911000201', {
      'sha256': digest.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
      'sizeBytes': photo.length,
    });
    try {
      final response = await _upload.post<Map<String, dynamic>>(
        '/kingclub/identity/photo',
        data: Stream.value(photo),
        options: Options(
          contentType: 'image/jpeg',
          headers: {
            'authorization': 'Bearer ${ticket['uploadToken']}',
            'content-length': photo.length,
          },
        ),
        onSendProgress: onProgress,
      );
      final data = response.data?['data'];
      if (response.data?['status'] != 1 ||
          data is! Map ||
          data['photoId'] != ticket['photoId']) {
        throw const AuthFailure('PHOTO_UPLOAD_FAILED', '照片上传失败，请重试');
      }
      return ticket['photoId'] as String;
    } on DioException catch (error) {
      final body = error.response?.data;
      throw AuthFailure(
        body is Map ? '${body['code']}' : 'PHOTO_UPLOAD_FAILED',
        body is Map ? '${body['message'] ?? '照片上传失败'}' : '照片上传失败，请检查网络后重试',
      );
    }
  }

  Future<Map<String, dynamic>> submit({
    required String photoId,
    required String name,
    required String idCard,
    required String idempotencyKey,
  }) => _call('K260911000202', {
    'photoId': photoId,
    'name': name,
    'idCard': idCard,
    'idempotencyKey': idempotencyKey,
  });
}
