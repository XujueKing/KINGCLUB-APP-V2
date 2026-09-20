import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

import '../../../core/session/secure_session_store.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import 'messaging_repository.dart';
import 'group_request_store.dart';
import 'chat_image_source.dart';

class UploadedChatImage {
  const UploadedChatImage(
    this.assetId,
    this.width,
    this.height,
    this._fingerprint,
    this._requestId, {
    this.sourceBytes,
  });
  final String assetId;
  final int width, height;
  final String _fingerprint, _requestId;
  final Uint8List? sourceBytes;
}

class ChatImageUploader {
  ChatImageUploader({
    required this.repository,
    required this.checkSession,
    Dio? dio,
    GroupRequestStore? requests,
    this.prepareSource,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), ''),
               connectTimeout: const Duration(seconds: 8),
               sendTimeout: const Duration(seconds: 60),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       _requests =
           requests ??
           GroupRequestStore(repository.account, namespace: 'image-uploads') {
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _cancel?.cancel('session changed');
    });
  }
  final MessagingRepository repository;
  final Future<void> Function() checkSession;
  final Dio _dio;
  final GroupRequestStore _requests;
  final Future<Uint8List> Function(Uint8List)? prepareSource;
  StreamSubscription<void>? _session;
  CancelToken? _cancel;
  bool _invalid = false, _busy = false;
  static Future<ChatImageUploader> open(MessagingRepository repository) async {
    final store = SecureSessionStore(), generation = MemberQrMemory.generation;
    final initial = await store.readSession();
    if (initial == null ||
        (initial['account'] as Map?)?['userAccount'] != repository.account) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    }
    return ChatImageUploader(
      repository: repository,
      prepareSource: prepareChatImageSource,
      checkSession: () async {
        final current = await store.readSession();
        if (generation != MemberQrMemory.generation ||
            current == null ||
            current['sessionId'] != initial['sessionId'] ||
            (current['account'] as Map?)?['userAccount'] !=
                repository.account) {
          throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
        }
      },
    );
  }

  Future<void> _check() async {
    if (_invalid) throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    await checkSession();
    if (_invalid) throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
  }

  Future<UploadedChatImage> upload(
    Uint8List input, {
    void Function(int, int)? onProgress,
  }) async {
    if (_busy) throw StateError('正在上传图片');
    if (input.isEmpty || input.length > 20 * 1024 * 1024) {
      throw ArgumentError('图片须小于20MB');
    }
    _busy = true;
    try {
      final owned = Uint8List.fromList(input);
      final prepared =
          await (prepareSource?.call(owned) ?? Future.value(owned));
      if (prepared.isEmpty || prepared.length > 20 * 1024 * 1024) {
        throw ArgumentError('压缩后的图片须小于20MB');
      }
      await _check();
      for (var attempt = 0; ; attempt++) {
        try {
          return await _uploadAttempt(prepared, onProgress: onProgress);
        } on AuthFailure catch (error) {
          if (attempt != 0 || error.code != 'CHAT_IMAGE_UPLOAD_DENIED') {
            rethrow;
          }
          // Re-request the same upload identity. A fresh grant also creates a
          // fresh AES-GCM nonce; invalid/revoked authority still fails closed.
          await _check();
        }
      }
    } finally {
      _busy = false;
    }
  }

  Future<UploadedChatImage> _uploadAttempt(
    Uint8List input, {
    void Function(int, int)? onProgress,
  }) async {
    _cancel = CancelToken();
    try {
      await _check();
      final bytes = input;
      final digest = (await Sha256().hash(bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final fingerprint = jsonEncode(['chat-image-v1', digest, bytes.length]);
      final requestId = await _requests.identity(fingerprint);
      await _check();
      final begin = await repository.call('K260913000631', {
        'clientUploadId': requestId,
        'sha256': digest,
        'size': bytes.length,
      });
      await _check();
      final assetId = begin['assetId'];
      if (assetId is! String ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(assetId)) {
        throw const FormatException('图片上传记录无效');
      }
      Map<String, dynamic> result = begin;
      if (begin['status'] == 'expired') {
        await _requests.acknowledge(fingerprint, requestId);
        throw StateError('上传已过期，请重试');
      }
      if (begin['status'] == 'pending') {
        final grant = Map<String, dynamic>.from(begin['upload'] as Map);
        if (grant['path'] != '/kingclub/chat-image-upload' ||
            grant['algorithm'] != 'AES-256-GCM' ||
            grant['wireFormat'] != 'iv12-tag16-ciphertext') {
          throw const FormatException('上传协议无效');
        }
        final aad = grant['aad'] as String;
        final fields = jsonDecode(aad) as List;
        if (fields.length != 6 ||
            fields[0] != 'kingclub:chat-image-upload:v1' ||
            fields[2] != assetId ||
            fields[3] != repository.account ||
            fields[4] != digest ||
            fields[5] != bytes.length) {
          throw const FormatException('上传凭证与图片不符');
        }
        final key = base64Url.decode(
          base64Url.normalize(grant['key'] as String),
        );
        if (key.length != 32) throw const FormatException('上传密钥无效');
        final box = await AesGcm.with256bits().encrypt(
          bytes,
          secretKey: SecretKey(key),
          aad: utf8.encode(aad),
        );
        final wire = Uint8List(bytes.length + 28)
          ..setRange(0, 12, box.nonce)
          ..setRange(12, 28, box.mac.bytes)
          ..setRange(28, bytes.length + 28, box.cipherText);
        await _check();
        final response = await _dio.post<Map<String, dynamic>>(
          '/kingclub/chat-image-upload',
          data: Stream.value(wire),
          cancelToken: _cancel,
          options: Options(
            contentType: 'application/octet-stream',
            followRedirects: false,
            headers: {
              'authorization': 'Bearer ${grant['token']}',
              'content-length': wire.length,
            },
          ),
          onSendProgress: onProgress,
        );
        await _check();
        if (response.data?['status'] != 1) {
          throw const FormatException('图片上传失败');
        }
        result = Map<String, dynamic>.from(response.data!['data'] as Map);
      }
      if (result['assetId'] != assetId ||
          result['status'] != 'ready' ||
          result['width'] is! int ||
          result['height'] is! int ||
          (result['width'] as int) < 1 ||
          (result['width'] as int) > 2560 ||
          (result['height'] as int) < 1 ||
          (result['height'] as int) > 2560) {
        throw const FormatException('图片上传回执无效');
      }
      return UploadedChatImage(
        assetId,
        result['width'] as int,
        result['height'] as int,
        fingerprint,
        requestId,
        sourceBytes: Uint8List.fromList(input),
      );
    } on DioException catch (e) {
      if (_invalid) throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
      final body = e.response?.data;
      if (body is Map) {
        throw AuthFailure(
          body['code']?.toString() ?? 'UPLOAD_ERROR',
          body['message']?.toString() ?? '图片上传失败',
        );
      }
      throw const AuthFailure('NETWORK_ERROR', '图片上传失败，请重试');
    } finally {
      _cancel = null;
    }
  }

  /// Call only after the resulting image message has been durably queued.
  Future<void> acknowledgeQueued(UploadedChatImage image) =>
      _requests.acknowledge(image._fingerprint, image._requestId);
  void dispose() {
    _invalid = true;
    _cancel?.cancel();
    _session?.cancel();
    _dio.close(force: true);
  }
}
