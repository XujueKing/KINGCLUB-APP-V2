import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'dart:io';

import 'package:cryptography/dart.dart';

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

class UploadedChatFile {
  const UploadedChatFile(
    this.assetId,
    this.fileName,
    this.size,
    this.sha256,
    this.fingerprint,
    this.requestId,
  );
  final String assetId, fileName, sha256, fingerprint, requestId;
  final int size;
}

class ChatFileUploader {
  ChatFileUploader({
    required this.repository,
    required this.checkSession,
    Dio? dio,
    GroupRequestStore? requests,
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
           GroupRequestStore(repository.account, namespace: 'file-uploads') {
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _cancel?.cancel('session changed');
    });
  }
  final MessagingRepository repository;
  final Future<void> Function() checkSession;
  final Dio _dio;
  final GroupRequestStore _requests;
  StreamSubscription<void>? _session;
  CancelToken? _cancel;
  bool _invalid = false, _busy = false;
  static Future<ChatFileUploader> open(MessagingRepository repository) async {
    final store = SecureSessionStore(), generation = MemberQrMemory.generation;
    final initial = await store.readSession();
    if (initial == null ||
        (initial['account'] as Map?)?['userAccount'] != repository.account) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    }
    return ChatFileUploader(
      repository: repository,
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

  static const chunkBytes = 1024 * 1024, maxBytes = 256 * 1024 * 1024;
  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  Future<UploadedChatFile> upload(
    File input, {
    required String fileName,
    void Function(int, int)? onProgress,
  }) async {
    if (_busy) throw StateError('正在上传文件');
    _busy = true;
    _cancel = CancelToken();
    RandomAccessFile? reader;
    try {
      await _check();
      final size = await input.length();
      if (size > maxBytes) throw ArgumentError('文件须不超过256MB');
      // Match the server before deriving retry identity, metadata and AAD.
      fileName = unorm.nfc(fileName);
      if (fileName.isEmpty ||
          fileName.trim().isEmpty ||
          fileName.length > 180 ||
          utf8.encode(fileName).length > 240 ||
          ['.', '..'].contains(fileName) ||
          RegExp(
            r'[\\/\x00-\x1f\x7f-\x9f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]',
          ).hasMatch(fileName)) {
        throw ArgumentError('文件名无效');
      }
      // DartSha256 has an incremental sink; no whole-file memory buffer.
      final hash = const DartSha256().newHashSink();
      var counted = 0;
      await for (final chunk in input.openRead()) {
        await _check();
        counted += chunk.length;
        if (counted > size) throw StateError('文件已变化');
        hash.add(chunk);
      }
      hash.close();
      if (counted != size) throw StateError('文件已变化');
      final digest = _hex((await hash.hash()).bytes);
      final fingerprint = jsonEncode(['chat-file-v1', fileName, size, digest]);
      final requestId = await _requests.identity(fingerprint);
      await _check();
      final begin = await repository.call('K260914000649', {
        'clientUploadId': requestId,
        'fileName': fileName,
        'size': size,
        'sha256': digest,
      });
      await _check();
      final asset = begin['assetId'];
      if (asset is! String ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(asset)) {
        throw const FormatException('文件资产无效');
      }
      final count = size == 0 ? 1 : (size + chunkBytes - 1) ~/ chunkBytes;
      void validate(Map<String, dynamic> data) {
        if (data['assetId'] != asset ||
            data['fileName'] != fileName ||
            data['size'] != size ||
            data['sha256'] != digest ||
            data['chunkCount'] != count) {
          throw const FormatException('文件回执不符');
        }
      }

      validate(begin);
      if (begin['status'] == 'expired') {
        await _requests.acknowledge(fingerprint, requestId);
        throw StateError('上传已过期，请重试');
      }
      Map<String, dynamic> completed = begin;
      if (begin['status'] == 'pending') {
        var grant = Map<String, dynamic>.from(begin['upload'] as Map);
        final path = '/kingclub/chat-file-upload/$asset';
        (String, List<int>) decodeGrant(Map<String, dynamic> grant) {
          if (grant['path'] != path ||
              grant['algorithm'] != 'AES-256-GCM' ||
              grant['wireFormat'] != 'iv12-tag16-ciphertext' ||
              grant['chunkBytes'] != chunkBytes ||
              grant['chunkCount'] != count) {
            throw const FormatException('文件上传协议无效');
          }
          final aad = grant['aad'] as String;
          final fields = jsonDecode(aad) as List;
          if (fields.length != 7 ||
              fields[0] != 'kingclub:chat-file-upload:v1' ||
              fields[2] != asset ||
              fields[3] != repository.account ||
              fields[4] != fileName ||
              fields[5] != digest ||
              fields[6] != size) {
            throw const FormatException('上传凭证不符');
          }
          final key = base64Url.decode(
            base64Url.normalize(grant['key'] as String),
          );
          if (key.length != 32) throw const FormatException('上传密钥无效');
          final token = grant['token'];
          if (token is! String ||
              token.isEmpty ||
              token.contains('\r') ||
              token.contains('\n')) {
            throw const FormatException('上传凭证无效');
          }
          return (aad, key);
        }

        var (aad, key) = decodeGrant(grant);
        final uploaded = <int, Map>{};
        for (final raw in begin['uploaded'] as List) {
          final row = raw as Map, index = row['index'];
          if (index is! int ||
              index < 0 ||
              index >= count ||
              uploaded.containsKey(index)) {
            throw const FormatException('分块回执无效');
          }
          uploaded[index] = row;
        }
        reader = await input.open();
        var done = 0;
        for (var index = 0; index < count; index++) {
          await _check();
          final length = (size - index * chunkBytes).clamp(0, chunkBytes);
          final bytes = await reader.read(length);
          if (bytes.length != length) throw StateError('文件已变化');
          final chunkHash = _hex((await Sha256().hash(bytes)).bytes);
          final old = uploaded[index];
          if (old != null) {
            if (old['size'] != length || old['sha256'] != chunkHash) {
              throw StateError('文件已变化，请重新选择');
            }
          } else {
            for (var attempt = 0; attempt < 2; attempt++) {
              try {
                final derived = await Hmac.sha256().calculateMac(
                  utf8.encode('chat-file-chunk-key:v1:$index'),
                  secretKey: SecretKey(key),
                );
                final box = await AesGcm.with256bits().encrypt(
                  bytes,
                  secretKey: SecretKey(derived.bytes),
                  aad: utf8.encode(jsonEncode([aad, index, length])),
                );
                final wire = Uint8List(length + 28)
                  ..setRange(0, 12, box.nonce)
                  ..setRange(12, 28, box.mac.bytes)
                  ..setRange(28, length + 28, box.cipherText);
                await _check();
                final response = await _dio.post<Map<String, dynamic>>(
                  '$path/$index',
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
                );
                await _check();
                final receipt = response.data?['data'];
                if (response.data?['status'] != 1 ||
                    receipt is! Map ||
                    receipt['assetId'] != asset ||
                    receipt['index'] != index ||
                    receipt['sha256'] != chunkHash) {
                  throw const FormatException('分块上传回执无效');
                }
                break;
              } on DioException catch (error) {
                if (attempt != 0) rethrow;
                final transient =
                    [
                      DioExceptionType.connectionError,
                      DioExceptionType.connectionTimeout,
                      DioExceptionType.sendTimeout,
                      DioExceptionType.receiveTimeout,
                    ].contains(error.type) ||
                    [502, 503, 504].contains(error.response?.statusCode);
                if (transient) {
                  // The server deduplicates by asset/index/plaintext hash.
                  // A lost receipt can safely retry with a fresh GCM nonce.
                  await Future.any<void>([
                    Future<void>.delayed(const Duration(milliseconds: 500)),
                    _cancel!.whenCancel.then<void>((_) {}),
                  ]);
                  await _check();
                  continue;
                }
                if (![401, 403].contains(error.response?.statusCode)) rethrow;
                await _check();
                final renewed = await repository.call('K260914000649', {
                  'clientUploadId': requestId,
                  'fileName': fileName,
                  'size': size,
                  'sha256': digest,
                });
                await _check();
                validate(renewed);
                if (renewed['status'] != 'pending') {
                  throw const FormatException('上传状态已变化，请重试');
                }
                grant = Map<String, dynamic>.from(renewed['upload'] as Map);
                (aad, key) = decodeGrant(grant);
              }
            }
          }
          done += length;
          onProgress?.call(done, size);
        }
        if (await input.length() != size) throw StateError('文件已变化');
        await _check();
        completed = await repository.call('K260914000650', {'assetId': asset});
      }
      await _check();
      validate(completed);
      if (completed['status'] != 'ready') {
        throw const FormatException('文件未完成上传');
      }
      onProgress?.call(size, size);
      return UploadedChatFile(
        asset,
        fileName,
        size,
        digest,
        fingerprint,
        requestId,
      );
    } on DioException catch (e) {
      if (_invalid) throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
      final body = e.response?.data;
      throw AuthFailure(
        body is Map
            ? body['code']?.toString() ?? 'UPLOAD_ERROR'
            : 'NETWORK_ERROR',
        '文件上传中断，请重试续传',
      );
    } finally {
      try {
        await reader?.close();
      } finally {
        _busy = false;
        _cancel = null;
      }
    }
  }

  Future<void> acknowledgeQueued(UploadedChatFile file) =>
      _requests.acknowledge(file.fingerprint, file.requestId);
  void dispose() {
    _invalid = true;
    _cancel?.cancel();
    _session?.cancel();
    _dio.close(force: true);
  }
}
