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
import 'chat_sent_file_cache.dart';
import 'novorudp_file_download.dart';
import 'novorudp_binding_runtime.dart';
import 'peer_file_authority.dart';
import 'chat_media_deletion.dart';

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
    this.media,
    this.fileId,
  });
  final String messageId, assetId, fileName, sha256;
  final int size;
  final bool group;
  final String? sender;
  final String? media, fileId;
}

/// Owns private temporary files until dispose. Export is an explicit UI action.
class ChatFileDownloader {
  ChatFileDownloader({
    required this.repository,
    required this.checkSession,
    Dio? dio,
    Future<Directory> Function()? temporaryDirectory,
    this.resumeCache,
    this.sentCache,
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
    _removeDeletionListener = ChatMediaDeletion.listen((event) async {
      if (event.account != repository.account) return;
      final identity = (event.group, event.messageId);
      _deleted.add(identity);
      if (_activeMessage == identity) {
        final done = _downloadDone?.future;
        cancel();
        await done;
      }
      await _deleteCompleted(only: identity, strict: true);
    });
  }
  static const chunkBytes = 1024 * 1024, maxBytes = 256 * 1024 * 1024;
  final MessagingRepository repository;
  final ChatDownloadCache? resumeCache;
  final ChatDownloadCache? sentCache;

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
  final _completedMessages = <Directory, (bool, String)>{};
  final _deleted = <(bool, String)>{};
  final _verifiedLocal = <String>{};
  (bool, String)? _activeMessage;
  late final void Function() _removeDeletionListener;
  Future<void> _cleanup = Future<void>.value();
  Completer<void>? _downloadDone;
  Future<void>? _disposing;
  CancelToken? _cancel;
  NovoRudpFileDownload? _peer;
  bool _invalid = false, _busy = false;
  bool _lastReadWasLocal = false;
  bool get lastReadWasLocal => _lastReadWasLocal;
  bool _sessionChanged = false;

  static Future<ChatFileDownloader> open(
    MessagingRepository repository, {
    Directory? mediaResumeDirectory,
  }) async {
    final store = SecureSessionStore(), generation = MemberQrMemory.generation;
    final initial = await store.readSession();
    if (initial == null ||
        (initial['account'] as Map?)?['userAccount'] != repository.account) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    }
    ChatDownloadCache? cache, sent;
    try {
      cache = await ChatDownloadCache.open(repository.account);
      if (mediaResumeDirectory != null) {
        cache = ChatDownloadCache(root: mediaResumeDirectory, key: cache.key);
      }
    } catch (_) {
      // Unavailable cache must not prevent an authorized fresh download.
    }
    try {
      sent = await ChatDownloadCache.openSentFiles(repository.account);
    } catch (_) {}
    late final ChatFileDownloader downloader;
    downloader = ChatFileDownloader(
      repository: repository,
      resumeCache: cache,
      sentCache: sent,
      peerDownload: NovoRudpBindingRuntime.fileTransferEnabled
          ? (reference, active) {
              final sender = reference.sender;
              if (sender == null || sender == repository.account) {
                return Future.value(null);
              }
              return NovoRudpBindingRuntime.receiveFile(
                account: repository.account,
                sender: sender,
                group: reference.group,
                media: reference.media,
                messageId: reference.messageId,
                assetId: reference.assetId,
                fileName: reference.fileName,
                size: reference.size,
                sha256: reference.sha256,
                stillActive: active,
                prepare: (peer) => downloader._preparePeer(reference, peer),
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
    return downloader;
  }

  Future<void> authorizeExport(ChatFileReference reference) async {
    final identity = _identity(reference);
    if (_verifiedLocal.contains(identity)) {
      await _check();
      if (_deleted.contains((reference.group, reference.messageId))) {
        throw StateError('文件所属聊天记录已删除');
      }
      await resumeCache?.ensureNotDeleted(identity);
      return;
    }
    await _grant(reference);
  }

  String _identity(ChatFileReference ref) => jsonEncode([
    repository.account,
    ref.group,
    ref.messageId,
    ref.assetId,
    ref.size,
    ref.sha256,
    ref.fileName,
    if (ref.media != null) ref.media,
    if (ref.media != null) ref.fileId,
  ]);

  Future<bool> _restoreLocal(
    ChatFileReference ref,
    String identity,
    File file,
  ) async {
    final cache = resumeCache;
    if (cache == null || !await cache.isRetained(identity)) return false;
    final output = await file.open(mode: FileMode.write);
    final digest = const DartSha256().newHashSink();
    var valid = true;
    try {
      final count = ref.size == 0
          ? 1
          : (ref.size + chunkBytes - 1) ~/ chunkBytes;
      for (var index = 0; index < count; index++) {
        await _check();
        final length = (ref.size - index * chunkBytes).clamp(0, chunkBytes);
        final bytes = await cache.read(identity, index, length);
        if (bytes == null) {
          valid = false;
          break;
        }
        digest.add(bytes);
        await output.writeFrom(bytes);
      }
      digest.close();
      final hash = (await digest.hash()).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      valid = valid && hash == ref.sha256;
      await output.flush();
    } finally {
      await output.close();
    }
    await _check();
    await cache.ensureNotDeleted(identity);
    if (!valid) {
      await cache.remove(identity);
      return false;
    }
    _verifiedLocal.add(identity);
    return true;
  }

  void cancel() {
    _cancel?.cancel('download cancelled');
    unawaited(_peer?.close());
  }

  final _preparedPeers = Expando<bool>();
  Future<void> _preparePeer(
    ChatFileReference ref,
    NovoRudpFileDownload peer,
  ) async {
    if (_preparedPeers[peer] == true) return;
    final cache = resumeCache;
    if (cache != null) {
      final identity = _identity(ref);
      bool canPreserve() =>
          !_sessionChanged && !_deleted.contains((ref.group, ref.messageId));
      Future<void> checkPreservation() async {
        if (!canPreserve()) throw StateError('Resume access removed');
        await checkSession();
        if (!canPreserve()) throw StateError('Resume access removed');
        await cache.ensureNotDeleted(identity);
      }

      peer.preserveBlocksOnClose((index, bytes) async {
        // Cancelling network work or closing its page must not discard complete
        // encrypted blocks. Logout and message deletion still invalidate them.
        await checkPreservation();
        await cache.write(identity, index, bytes);
        await checkPreservation();
      }, canPreserve: canPreserve);
      await peer.restoreBlocks((index, length) async {
        await _check();
        await cache.ensureNotDeleted(identity);
        return cache.read(identity, index, length);
      });
    }
    await _check();
    _preparedPeers[peer] = true;
  }

  Future<bool> _tryPeer(
    ChatFileReference ref,
    File destination,
    void Function(int, int)? onProgress,
  ) async {
    final connect = peerDownload;
    if (connect == null) return false;
    final token = _cancel;
    var opening = true;
    var peerAttemptActive = true;
    Timer? progressTimer;
    bool active() =>
        peerAttemptActive &&
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
      await _preparePeer(ref, peer);
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
          group: ref.group,
          media: ref.media,
        );
        if (authority.assetId != ref.assetId ||
            authority.fileId != ref.fileId ||
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
      peerAttemptActive = false;
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
    if (_deleted.contains((ref.group, ref.messageId))) {
      throw StateError('文件所属聊天记录已删除');
    }
    await _check();
    if (ref.media != null) return _mediaGrant(ref);
    final result = await repository.fileMedia(ref.messageId, group: ref.group);
    await _check();
    final raw = result['file'];
    if (_deleted.contains((ref.group, ref.messageId))) {
      throw StateError('文件所属聊天记录已删除');
    }
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

  Future<Map<String, dynamic>> _mediaGrant(ChatFileReference ref) async {
    final type = ref.media!;
    final image = type == 'image' || type == 'image-thumbnail';
    final voice = type == 'voice';
    final result = image
        ? await repository.imageMedia(ref.messageId, group: ref.group)
        : voice
        ? await repository.voiceMedia(ref.messageId, group: ref.group)
        : await repository.videoMedia(
            ref.messageId,
            group: ref.group,
            preferHevc: type == 'hevc',
          );
    await _check();
    if (_deleted.contains((ref.group, ref.messageId))) {
      throw StateError('媒体所属聊天记录已删除');
    }
    final slot = type.endsWith('thumbnail')
        ? 'thumbnail'
        : image
        ? 'image'
        : voice
        ? 'voice'
        : 'video';
    final raw = result[slot];
    if (raw is! Map) throw const FormatException('媒体授权无效');
    final media = Map<String, dynamic>.from(raw);
    final token = (media['headers'] as Map?)?['authorization'];
    final routeType = image
        ? 'image'
        : voice
        ? 'voice'
        : 'video';
    final path =
        '/kingclub/${ref.group ? 'group-' : ''}chat-$routeType/${ref.messageId}${voice ? '' : '/${type == 'hevc' ? 'hevc' : slot}'}';
    if (result['messageId'] != ref.messageId ||
        media['fileId'] != ref.fileId ||
        media['size'] != ref.size ||
        media['sha256'] != ref.sha256 ||
        media['path'] != path ||
        token is! String ||
        !token.startsWith('Bearer ') ||
        token.length <= 7 ||
        token.length > 4103 ||
        token.contains('\r') ||
        token.contains('\n')) {
      throw const FormatException('媒体授权与对象不匹配');
    }
    return {
      ...media,
      'chunkCount': (ref.size + chunkBytes - 1) ~/ chunkBytes,
      'contentType': image
          ? 'image/webp'
          : voice
          ? 'audio/mp4'
          : slot == 'thumbnail'
          ? 'image/jpeg'
          : 'video/mp4',
    };
  }

  Future<File> download(
    ChatFileReference ref, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (_invalid) throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    if (_busy) throw StateError('正在下载文件');
    if (_deleted.contains((ref.group, ref.messageId))) {
      throw StateError('文件所属聊天记录已删除');
    }
    _busy = true;
    _lastReadWasLocal = false;
    _activeMessage = (ref.group, ref.messageId);
    _downloadDone = Completer<void>();
    _cancel = CancelToken();
    Directory? working;
    RandomAccessFile? output;
    var completed = false;
    var keepResume = false;
    final identity = _identity(ref);
    try {
      final uuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (!uuid.hasMatch(ref.messageId) ||
          !uuid.hasMatch(ref.assetId) ||
          (ref.media != null &&
              (!PeerFileAuthority.mediaKinds.contains(ref.media) ||
                  ref.fileId == null ||
                  !uuid.hasMatch(ref.fileId!) ||
                  ref.size < 1 ||
                  ref.size > 32 * 1024 * 1024)) ||
          ref.size < 0 ||
          ref.size > maxBytes ||
          ref.fileName.isEmpty ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(ref.sha256)) {
        throw const FormatException('文件消息无效');
      }
      await resumeCache?.ensureNotDeleted(identity);
      if (await resumeCache?.isRetained(identity) == true) {
        final parent = await _temporaryDirectory();
        await _check();
        working = await parent.createTemp('kingclub-chat-download-');
        final local = File('${working.path}/content.bin');
        if (await _restoreLocal(ref, identity, local)) {
          _lastReadWasLocal = true;
          _completed.add(working);
          _completedMessages[working] = (ref.group, ref.messageId);
          completed = true;
          onProgress?.call(ref.size, ref.size);
          return local;
        }
        await working.delete(recursive: true);
        working = null;
      }
      if (sentCache != null && ref.sender == repository.account) {
        final parent = await _temporaryDirectory();
        await _check();
        working = await parent.createTemp('kingclub-chat-download-');
        final local = File('${working.path}/content.bin');
        final restored =
            await ChatSentFileCache(
              cache: sentCache!,
              checkSession: _check,
              temporaryDirectory: _temporaryDirectory,
            ).use<bool>(
              assetId: ref.assetId,
              size: ref.size,
              sha256: ref.sha256,
              send: (source) async {
                await source.copy(local.path);
                return true;
              },
            );
        await _check();
        await resumeCache?.ensureNotDeleted(identity);
        if (_deleted.contains((ref.group, ref.messageId))) {
          throw StateError('文件所属聊天记录已删除');
        }
        if (restored == true) {
          _lastReadWasLocal = true;
          _verifiedLocal.add(identity);
          _completed.add(working);
          _completedMessages[working] = (ref.group, ref.messageId);
          completed = true;
          onProgress?.call(ref.size, ref.size);
          return local;
        }
        await working.delete(recursive: true);
        working = null;
      }
      var media = await _grant(ref);
      try {
        await resumeCache?.prune(identity);
      } catch (_) {}
      final parent = await _temporaryDirectory();
      await _check();
      working = await parent.createTemp('kingclub-chat-download-');
      final file = File('${working.path}/content.bin');
      // HTTP blocks arrive in order. Reuse an authenticated first block rather
      // than starting a whole-file peer transfer on every resumed download.
      var firstBlock = await resumeCache?.read(
        identity,
        0,
        ref.size.clamp(0, chunkBytes),
      );
      await _check();
      await resumeCache?.ensureNotDeleted(identity);
      Future<File> finishPeer(File peerFile) async {
        await _grant(ref);
        await _check();
        await resumeCache?.ensureNotDeleted(identity);
        if (resumeCache != null) {
          final reader = await peerFile.open();
          try {
            final count = ref.size == 0
                ? 1
                : (ref.size + chunkBytes - 1) ~/ chunkBytes;
            for (var index = 0; index < count; index++) {
              await _check();
              final length = (ref.size - index * chunkBytes).clamp(
                0,
                chunkBytes,
              );
              final bytes = await reader.read(length);
              if (bytes.length != length) throw StateError('File changed');
              await resumeCache!.write(identity, index, bytes);
            }
            await resumeCache!.retainCompleted(identity);
          } finally {
            await reader.close();
          }
        }
        await _check();
        _completed.add(working!);
        _completedMessages[working] = (ref.group, ref.messageId);
        completed = true;
        onProgress?.call(ref.size, ref.size);
        return peerFile;
      }

      if (firstBlock == null && await _tryPeer(ref, file, onProgress)) {
        return await finishPeer(file);
      }
      if (firstBlock == null && peerDownload != null) {
        // The peer attempt may outlive a grant or a membership change.
        media = await _grant(ref);
        // Closing the failed peer snapshots complete ranges into this cache.
        firstBlock = await resumeCache?.read(
          identity,
          0,
          ref.size.clamp(0, chunkBytes),
        );
        onProgress?.call(0, ref.size);
      }
      final httpOutput = await file.open(mode: FileMode.write);
      output = httpOutput;
      final digest = const DartSha256().newHashSink();
      var received = 0;
      for (var index = 0; index < (media['chunkCount'] as int); index++) {
        await _check();
        await resumeCache?.ensureNotDeleted(identity);
        final expected = (ref.size - index * chunkBytes).clamp(0, chunkBytes);
        Uint8List? block = index == 0
            ? firstBlock
            : await resumeCache?.read(identity, index, expected);
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
            if (!_retryable(error)) rethrow;
            if (networkAttempt >= 2) {
              // HTTP is exhausted. The peer imports the same cached blocks,
              // advertises only missing fragments, and verifies the whole file.
              if (peerDownload != null) {
                await _grant(ref);
                final recovered = File('${working.path}/peer-recovered.bin');
                if (await _tryPeer(ref, recovered, onProgress)) {
                  await httpOutput.close();
                  output = null;
                  digest.close();
                  await file.delete();
                  return await finishPeer(recovered);
                }
              }
              rethrow;
            }
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
        await httpOutput.writeFrom(block);
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
      await httpOutput.flush();
      await httpOutput.close();
      output = null;
      // Recheck permissions after network and disk I/O, including empty files.
      await _grant(ref);
      await _check();
      await resumeCache?.ensureNotDeleted(identity);
      await resumeCache?.retainCompleted(identity);
      _completed.add(working);
      _completedMessages[working] = (ref.group, ref.messageId);
      completed = true;
      return file;
    } catch (error) {
      keepResume =
          !_sessionChanged &&
          !_deleted.contains((ref.group, ref.messageId)) &&
          (_retryable(error) ||
              error is DioException && CancelToken.isCancel(error) ||
              _disposing != null);
      rethrow;
    } finally {
      if (!keepResume && !completed) {
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
          _activeMessage = null;
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
        ref.media == null ? '${media['path']}/$index' : media['path'] as String,
        cancelToken: _cancel,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (code) =>
              code == (ref.media == null ? 200 : 206) ||
              code == 401 ||
              code == 403,
          headers: {
            'authorization': (media['headers'] as Map)['authorization'],
            'accept-encoding': 'identity',
            if (ref.media != null)
              'range':
                  'bytes=${index * chunkBytes}-${index * chunkBytes + expected - 1}',
          },
        ),
      );
      if (response.statusCode == (ref.media == null ? 200 : 206)) break;
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
        (ref.media != null &&
            response.headers.value('content-range') !=
                'bytes ${index * chunkBytes}-${index * chunkBytes + expected - 1}/${ref.size}') ||
        (encoding != null && encoding != 'identity') ||
        response.headers.value('content-type')?.split(';').first.trim() !=
            media['contentType']) {
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

  Future<void> _deleteCompleted({(bool, String)? only, bool strict = false}) {
    final directories = _completed
        .where((dir) => only == null || _completedMessages[dir] == only)
        .toList();
    _completed.removeWhere(directories.contains);
    _cleanup = _cleanup.catchError((Object _) {}).then((_) async {
      FileSystemException? failure;
      for (final directory in directories) {
        try {
          if (await directory.exists()) await directory.delete(recursive: true);
          _completedMessages.remove(directory);
        } on FileSystemException catch (error) {
          // Keep ownership for another cleanup attempt when a provider holds it.
          _completed.add(directory);
          failure = error;
        }
      }
      if (strict && failure != null) throw failure;
    });
    return _cleanup;
  }

  Future<void> dispose() {
    _invalid = true;
    cancel();
    return _disposing ??= _dispose();
  }

  Future<void> _dispose() async {
    _removeDeletionListener();
    final active = _downloadDone?.future;
    _dio.close(force: true);
    await _session.cancel();
    await active;
    await _deleteCompleted();
  }
}
