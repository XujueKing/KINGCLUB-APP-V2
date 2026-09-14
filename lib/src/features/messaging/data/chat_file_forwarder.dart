import 'dart:async';

import '../../../core/session/secure_session_store.dart';
import 'chat_file_downloader.dart';
import 'chat_file_uploader.dart';
import 'messaging_repository.dart';

/// The downloader owns temporary plaintext; it is removed after the new owned
/// asset is ready, on failure, or on session invalidation.
class ChatFileForwarder {
  ChatFileForwarder({
    required this.repository,
    required this.reference,
    this.openDownloader,
    this.openUploader,
  }) {
    _session = SecureSessionStore.changes.stream.listen((_) => dispose());
  }
  final MessagingRepository repository;
  final ChatFileReference reference;
  final Future<ChatFileDownloader> Function()? openDownloader;
  final Future<ChatFileUploader> Function()? openUploader;
  StreamSubscription<void>? _session;
  ChatFileDownloader? _downloader;
  ChatFileUploader? _uploader;
  UploadedChatFile? _prepared;
  bool _closed = false, _busy = false;
  void _check() {
    if (_closed) throw StateError('文件转发已结束');
  }

  Future<UploadedChatFile> prepare() async {
    _check();
    if (_prepared != null) return _prepared!;
    if (_busy) throw StateError('正在准备文件');
    _busy = true;
    ChatFileDownloader? downloader;
    try {
      downloader =
          await (openDownloader?.call() ?? ChatFileDownloader.open(repository));
      _downloader = downloader;
      _check();
      final file = await downloader.download(reference);
      _check();
      final uploader =
          _uploader ??
          await (openUploader?.call() ?? ChatFileUploader.open(repository));
      if (_closed) {
        uploader.dispose();
        _check();
      }
      _uploader = uploader;
      final asset = await uploader.upload(file, fileName: reference.fileName);
      _check();
      if (asset.size != reference.size || asset.sha256 != reference.sha256) {
        throw StateError('转发文件校验不一致');
      }
      _prepared = asset;
      return asset;
    } finally {
      await downloader?.dispose();
      if (identical(_downloader, downloader)) _downloader = null;
      _busy = false;
    }
  }

  Future<void> acknowledgeQueued() async {
    final file = _prepared;
    if (file != null) await _uploader?.acknowledgeQueued(file);
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _prepared = null;
    _session?.cancel();
    _uploader?.dispose();
    final downloader = _downloader;
    // prepare owns cleanup after upload closes its file reader.
    downloader?.cancel();
  }
}
