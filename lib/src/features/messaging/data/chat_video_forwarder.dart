import 'dart:async';
import 'dart:io';

import 'package:cryptography/dart.dart';

import '../../../core/media/media_cache.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'chat_file_uploader.dart';
import 'chat_video.dart';
import 'chat_video_grant.dart';
import 'messaging_repository.dart';

class ChatVideoForwarder {
  ChatVideoForwarder({
    required this.repository,
    required this.messageId,
    this.group = false,
    this.loadFile,
    this.openUploader,
  }) {
    _session = SecureSessionStore.changes.stream.listen((_) => dispose());
  }
  final MessagingRepository repository;
  final String messageId;
  final bool group;
  final Future<File> Function(ChatVideoGrant)? loadFile;
  final Future<ChatFileUploader> Function()? openUploader;
  StreamSubscription<void>? _session;
  ChatFileUploader? _uploader;
  UploadedChatFile? _uploaded;
  ChatVideo? _prepared;
  ChatVideoGrant? _source;
  bool _closed = false, _busy = false;
  void _check() {
    if (_closed) throw StateError('视频转发已结束');
  }

  Future<ChatVideoGrant> _grant() async {
    final grant = ChatVideoGrant.parse(
      await repository.videoMedia(messageId, group: group, preferHevc: true),
      messageId,
      group: group,
      full: true,
    );
    _check();
    final source = _source;
    if (source != null &&
        (source.fileId != grant.fileId ||
            source.sha256 != grant.sha256 ||
            source.size != grant.size)) {
      throw StateError('原视频已变化');
    }
    return grant;
  }

  Future<ChatVideo> prepare() async {
    _check();
    if (_busy) throw StateError('正在准备视频');
    _busy = true;
    try {
      final grant = await _grant();
      _source = grant;
      if (_prepared != null) return _prepared!;
      if (_uploaded == null) {
        final file =
            await (loadFile?.call(grant) ??
                MediaCache.shared.get(
                  '${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}${grant.path}',
                  scope: 'member:${repository.account}',
                  contentKey:
                      'chat-video:${repository.account}:${grant.fileId}:${grant.sha256}',
                  kind: MediaKind.video,
                  headers: {'authorization': grant.authorization},
                ));
        _check();
        if (await file.length() != grant.size) throw StateError('视频文件不完整');
        final hash = const DartSha256().newHashSink();
        var size = 0;
        await for (final bytes in file.openRead()) {
          _check();
          size += bytes.length;
          if (size > grant.size) throw StateError('视频文件已变化');
          hash.add(bytes);
        }
        hash.close();
        final digest = (await hash.hash()).bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        if (size != grant.size || digest != grant.sha256) {
          throw StateError('视频校验失败');
        }
        await _grant();
        final uploader =
            _uploader ??
            await (openUploader?.call() ?? ChatFileUploader.open(repository));
        if (_closed) {
          uploader.dispose();
          _check();
        }
        _uploader = uploader;
        final uploaded = await uploader.upload(file, fileName: 'video.mp4');
        _check();
        if (uploaded.size != grant.size || uploaded.sha256 != grant.sha256) {
          throw StateError('上传视频校验失败');
        }
        _uploaded = uploaded;
      }
      final video = await repository.prepareVideo(_uploaded!.assetId);
      _check();
      await _grant();
      _prepared = video;
      return video;
    } finally {
      _busy = false;
    }
  }

  Future<void> acknowledgeQueued() async {
    final file = _uploaded;
    if (file != null) await _uploader?.acknowledgeQueued(file);
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _session?.cancel();
    _uploader?.dispose();
    _uploaded = null;
    _prepared = null;
  }
}
