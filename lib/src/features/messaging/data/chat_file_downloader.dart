import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import 'messaging_repository.dart';
import 'chat_download_cache.dart';
import 'novorudp_file_download.dart';
import 'novorudp_binding_runtime.dart';
import 'peer_file_authority.dart';

/// Metadata comes from the acknowledged message, never from a download URL.
class ChatFileReference {
  const ChatFileReference({
    required this.messageId,
    required this.assetId,
    required this.fileName,
    required this.size,
    required this.sha256,
    this.group = false,
    this.sender,
  });
  final String messageId, assetId, fileName, sha256;
  final int size;
  final bool group;
  final String? sender;
}

/// Owns private temporary files until dispose. Export is an explicit UI action.
class ChatFileDownloader {
  ChatFileDownloader({
    required this.repository,
    required this.checkSession,
    Dio? dio,
    Future<Directory> Function()? temporaryDirectory,
    this.resumeCache,
    this.peerDownload,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), ''),
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory {
    _session = SecureSessionStore.changes.stream.listen((_) {
      _sessionChanged = true;
      _invalid = true;
      cancel();
      _deleteCompleted();
    });
  }
  static const chunkBytes = 1024 * 1024, maxBytes = 256 * 1024 * 1024;
  final MessagingRepository repository;
  final ChatDownloadCache? resumeCache;

  /// Only a runtime with an authenticated peer/message binding may supply this.
  /// Service authorization is checked before connecting and after receiving.
  final Future<NovoRudpFileDownload?> Function(
    ChatFileReference reference,
    bool Function() stillActive,
  )?
  peerDownload;
  final Future<void> Function() checkSession;
  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectory;
  late final StreamSubscription<void> _session;
  final List<Directory> _completed = [];
  Future<void> _cleanup = Future<void>.value();
  Completer<void>? _downloadDone;
  Future<void>? _disposing;
  CancelToken? _cancel;
  NovoRudpFileDownload? _peer;
  bool _invalid = false, _busy = false;
  bool _sessionChanged = false;

  static Future<ChatFileDownloader> open(MessagingRepository repository) async {
    final store = SecureSessionStore(), generation = MemberQrMemory.generation;
    final initial = await store.readSession();
    if (initial == null ||
        (initial['account'] as Map?)?['userAccount'] != repository.account) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    }
    ChatDownloadCache? cache;
    try {
      cache = await ChatDownloadCache.open(repository.account);
    } catch (_) {
      // Unavailable cache must not prevent an authorized fresh download.
    }
    return ChatFileDownloader(
      repository: repository,
      resumeCache: cache,
      peerDownload: NovoRudpBindingRuntime.fileTransferEnabled
          ? (reference, active) {
              final sender = reference.sender;
              if (reference.group ||
                  sender == null ||
                  sender == repository.account) {
                return Future.value(null);
              }
              return NovoRudpBindingRuntime.receiveFile(
                account: repository.account,
                sender: sender,
                messageId: reference.messageId,
                assetId: reference.assetId,
                fileName: reference.fileName,
                size: reference.size,
                sha256: reference.sha256,
                stillActive: active,
              );
            }
          : null,
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

  Future<void> authorizeExport(ChatFileReference reference) async {
    await _grant(reference);
  }

  void cancel() {
    _cancel?.cancel('download cancelled');
    unawaited(_peer?.close());
  }

  Future<bool> _tryPeer(
    ChatFileReference ref,
    File destination,
    void Function(int, int)? onProgress,
  ) async {
    final connect = peerDownload;
    if (connect == null || ref.group) return false;
    final token = _cancel;
    var opening = true;
    Timer? progressTimer;
    bool active() =>
        !_invalid &&
        token != null &&
        identical(token, _cancel) &&
        !token.isCancelled;
    try {
      final pending = connect(ref, active).then((download) async {
        if (!opening || !active()) {
          await download?.close();
          return null;
        }
        return download;
      });
      _peer = await Future.any<NovoRudpFileDownload?>([
        pending,
        token!.whenCancel.then((error) => throw error),
      ]).timeout(const Duration(seconds: 3));
      opening = false;
      await _check();
      final peer = _peer;
      if (peer == null) return false;
      var reported = -1;
      void reportProgress() {
        if (!active() || onProgress == null || ref.size == 0) return;
        // Reserve completion for digest and final permission verification.
        final received = peer.receivedBytes.clamp(0, ref.size - 1);
        if (received == reported) return;
        reported = received;
        onProgress(received, ref.size);
      }

      reportProgress();
      progressTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => reportProgress(),
      );
      final source = await peer.completed;
      await _check();
      // Independently validate and copy: callers never receive a peer-owned
      // temporary path, and a failed lane cannot append to the HTTP fallback.
      if (await source.length() != ref.size) {
        throw const FormatException('Peer file size mismatch');
      }
      final output = await destination.open(mode: FileMode.write);
      final digest = const DartSha256().newHashSink();
      var received = 0;
      try {
        await for (final bytes in source.openRead()) {
          await _check();
          received += bytes.length;
          if (received > ref.size) {
            throw const FormatException('Peer file too large');
          }
          digest.add(bytes);
          await output.writeFrom(bytes);
        }
        await output.flush();
      } finally {
        digest.close();
        await output.close();
      }
      final hash = (await digest.hash()).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (received != ref.size || hash != ref.sha256) {
        throw const FormatException('Peer file digest mismatch');
      }
      if (ref.sender != null) {
        final authority = await PeerFileAuthority.read(
          repository,
          ref.sender!,
          ref.messageId,
          sending: false,
        );
        if (authority.assetId != ref.assetId ||
            authority.fileName != ref.fileName ||
            authority.size != ref.size ||
            authority.sha256 != ref.sha256) {
          throw const FormatException('Peer file authority changed');
        }
      }
      await _check();
      return true;
    } catch (_) {
      // Cancellation/logout must not silently start another network transfer.
      await _check();
      return false;
    } finally {
      progressTimer?.cancel();
      opening = false;
      final peer = _peer;
      _peer = null;
      await peer?.close();
    }
  }

  Future<void> _check() async {
    if (_invalid) throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    if (_cancel?.isCancelled == true) throw _cancel!.cancelError!;
    await checkSession();
    if (_invalid) throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    if (_cancel?.isCancelled == true) throw _cancel!.cancelError!;
  }

  Future<Map<String, dynamic>> _grant(ChatFileReference ref) async {
    await _check();
    final result = await repository.fileMedia(ref.messageId, group: ref.group);
    await _check();
    final raw = result['file'];
    if (raw is! Map) throw const FormatException('文件授权无效');
    final media = Map<String, dynamic>.from(raw);
    final token = (media['headers'] as Map?)?['authorization'];
    final count = ref.size == 0 ? 1 : (ref.size + chunkBytes - 1) ~/ chunkBytes;
    if (result['messageId'] != ref.messageId ||
        media['assetId'] != ref.assetId ||
        media['fileName'] != ref.fileName ||
        media['size'] != ref.size ||
        media['sha256'] != ref.sha256 ||
        media['chunkBytes'] != chunkBytes ||
        media['chunkCount'] != count ||
        media['contentType'] != 'application/octet-stream' ||
        media['path'] !=
            '/kingclub/${ref.group ? 'group-chat-file' : 'chat-file'}/${ref.messageId}' ||
        token is! String ||
        !token.startsWith('Bearer ') ||
        token.length <= 7 ||
        token.contains('\r') ||
        token.contains('\n')) {
      throw const FormatException('文件授权与消息不匹配');
    }
    return media;
  }

  Future<File> download(
    ChatFileReference ref, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (_invalid) throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    if (_busy) throw StateError('正在下载文件');
    _busy = true;
    _downloadDone = Completer<void>();
    _cancel = CancelToken();
    Directory? working;
    RandomAccessFile? output;
    var completed = false;
    var keepResume = false;
    final identity = jsonEncode([
      repository.account,
      ref.group,
      ref.messageId,
      ref.assetId,
      ref.size,
      ref.sha256,
      ref.fileName,
    ]);
    try {
      final uuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (!uuid.hasMatch(ref.messageId) ||
          !uuid.hasMatch(ref.assetId) ||
          ref.size < 0 ||
          ref.size > maxBytes ||
          ref.fileName.isEmpty ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(ref.sha256)) {
        throw const FormatException('文件消息无效');
      }
      var media = await _grant(ref);
      try {
        await resumeCache?.prune(identity);
      } catch (_) {}
      final parent = await _temporaryDirectory();
      await _check();
      working = await parent.createTemp('kingclub-chat-download-');
      final file = File('${working.path}/content.bin');
      if (await _tryPeer(ref, file, onProgress)) {
        await _grant(ref);
        await _check();
        _completed.add(working);
        completed = true;
        onProgress?.call(ref.size, ref.size);
        return file;
      }
      if (peerDownload != null && !ref.group) {
        // The peer attempt may outlive a grant or a membership change.
        media = await _grant(ref);
        onProgress?.call(0, ref.size);
      }
      output = await file.open(mode: FileMode.write);
      final digest = const DartSha256().newHashSink();
      var received = 0;
      for (var index = 0; index < (media['chunkCount'] as int); index++) {
        await _check();
        final expected = (ref.size - index * chunkBytes).clamp(0, chunkBytes);
        Uint8List? block = await resumeCache?.read(identity, index, expected);
        await _check();
        final cached = block != null;
        for (var networkAttempt = 0; block == null; networkAttempt++) {
          try {
            block = await _readBlock(ref, media, index, expected, (count) {
              onProgress?.call(received + count, ref.size);
            });
            break;
          } catch (error) {
            await _check();
            if (networkAttempt >= 2 || !_retryable(error)) rethrow;
            onProgress?.call(received, ref.size);
            await Future<void>.delayed(
              Duration(milliseconds: 250 * (networkAttempt + 1)),
            );
            await _check();
          }
        }
        // Commit only a complete block, so retry cannot double-hash or append
        // a partially received block. Memory is bounded by one 1 MiB block.
        digest.add(block);
        await output.writeFrom(block);
        received += block.length;
        if (!cached) {
          try {
            await resumeCache?.write(identity, index, block);
          } catch (_) {}
        }
        onProgress?.call(received, ref.size);
      }
      digest.close();
      final hash = (await digest.hash()).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (received != ref.size || hash != ref.sha256) {
        throw const FormatException('文件完整性校验失败');
      }
      await output.flush();
      await output.close();
      output = null;
      // Recheck permissions after network and disk I/O, including empty files.
      await _grant(ref);
      await _check();
      _completed.add(working);
      completed = true;
      return file;
    } catch (error) {
      keepResume =
          !_sessionChanged &&
          (_retryable(error) ||
              error is DioException && CancelToken.isCancel(error) ||
              _disposing != null);
      rethrow;
    } finally {
      if (!keepResume) {
        try {
          await resumeCache?.remove(identity);
        } catch (_) {}
      }
      try {
        await output?.close();
      } finally {
        try {
          if (!completed && working != null && await working.exists()) {
            await working.delete(recursive: true);
          }
        } finally {
          _busy = false;
          _cancel = null;
          _downloadDone!.complete();
          _downloadDone = null;
        }
      }
    }
  }

  static bool _retryable(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return true;
    }
    if (error is! DioException) return false;
    return [
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.sendTimeout,
        ].contains(error.type) ||
        (error.type == DioExceptionType.badResponse &&
            [502, 503, 504].contains(error.response?.statusCode));
  }

  Future<Uint8List> _readBlock(
    ChatFileReference ref,
    Map<String, dynamic> media,
    int index,
    int expected,
    void Function(int) progress,
  ) async {
    late Response<ResponseBody> response;
    for (var attempt = 0; attempt < 2; attempt++) {
      await _check();
      response = await _dio.get<ResponseBody>(
        '${media['path']}/$index',
        cancelToken: _cancel,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (code) => code == 200 || code == 401 || code == 403,
          headers: {
            'authorization': (media['headers'] as Map)['authorization'],
            'accept-encoding': 'identity',
          },
        ),
      );
      if (response.statusCode == 200) break;
      await response.data?.stream.listen((_) {}).cancel();
      if (attempt == 1) {
        throw const AuthFailure('FILE_ACCESS_DENIED', '文件下载授权已失效');
      }
      // No bytes from this rejected block were written. Keep prior blocks,
      // but require the server to re-authorize exactly the same message.
      final renewed = await _grant(ref);
      media.clear();
      media.addAll(renewed);
    }
    await _check();
    final body = response.data;
    if (body == null) throw const FormatException('文件响应为空');
    final length = response.headers.value('content-length');
    final encoding = response.headers.value('content-encoding');
    if ((length != null && int.tryParse(length) != expected) ||
        (encoding != null && encoding != 'identity') ||
        response.headers.value('content-type')?.split(';').first.trim() !=
            'application/octet-stream') {
      await body.stream.listen((_) {}).cancel();
      throw const FormatException('文件分块响应无效');
    }
    var blockReceived = 0;
    final block = BytesBuilder(copy: false);
    await for (final bytes in body.stream.timeout(
      const Duration(seconds: 30),
    )) {
      await _check();
      blockReceived += bytes.length;
      if (blockReceived > expected) throw const FormatException('文件分块超长');
      block.add(bytes);
      await _check();
      progress(blockReceived);
    }
    if (blockReceived != expected) throw const HttpException('文件分块不完整');
    return block.takeBytes();
  }

  Future<void> _deleteCompleted() {
    final directories = List<Directory>.of(_completed);
    _completed.clear();
    _cleanup = _cleanup.then((_) async {
      for (final directory in directories) {
        try {
          if (await directory.exists()) await directory.delete(recursive: true);
        } on FileSystemException {
          // Keep ownership for another cleanup attempt when a provider holds it.
          _completed.add(directory);
        }
      }
    });
    return _cleanup;
  }

  Future<void> dispose() {
    _invalid = true;
    cancel();
    return _disposing ??= _dispose();
  }

  Future<void> _dispose() async {
    final active = _downloadDone?.future;
    _dio.close(force: true);
    await _session.cancel();
    await active;
    await _deleteCompleted();
  }
}
