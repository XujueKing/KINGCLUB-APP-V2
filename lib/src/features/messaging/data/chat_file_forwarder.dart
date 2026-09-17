import 'dart:async';

import 'chat_outbox.dart';

import 'dart:io';

import '../../../core/session/secure_session_store.dart';
import 'chat_file_downloader.dart';
import 'chat_file_uploader.dart';
import 'messaging_repository.dart';

/// The downloader owns temporary plaintext until the queued copy is retained,
/// preparation fails, or the forwarding flow is closed.
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
  File? _source;
  bool _closed = false, _busy = false;
  Future<void> Function()? _releaseSource;
  Future<void> _releaseHeldSource() async {
    final release = _releaseSource;
    _releaseSource = null;
    await release?.call();
  }

  void _check() {
    if (_closed) throw StateError('文件转发已结束');
  }

  Future<UploadedChatFile> prepare() async {
    _check();
    if (_busy) throw StateError('正在准备文件');
    if (_prepared != null) return _prepared!;
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
      _releaseSource = await SecureChatOutbox(
        repository.account,
      ).holdMediaSource({'messageType': 'file', 'fileAssetId': asset.assetId});
      _check();
      _prepared = asset;
      _source = file;
      return asset;
    } finally {
      if (_prepared == null || _closed) {
        await downloader?.dispose();
        if (identical(_downloader, downloader)) _downloader = null;
      }
      _busy = false;
      if (_closed) await _releaseHeldSource();
    }
  }

  Future<void> acknowledgeQueued() async {
    _check();
    if (_busy) throw StateError('文件仍在处理中');
    _busy = true;
    final file = _prepared;
    final source = _source;
    try {
      if (file != null) {
        if (source != null) await _uploader?.retainQueuedSource(source, file);
        _check();
        await _uploader?.acknowledgeQueued(file);
      }
    } finally {
      _source = null;
      final downloader = _downloader;
      _downloader = null;
      await downloader?.dispose();
      _busy = false;
      if (_closed) await _releaseHeldSource();
    }
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _prepared = null;
    _source = null;
    _session?.cancel();
    _uploader?.dispose();
    final downloader = _downloader;
    // Active upload/retention owns cleanup after its file reader closes.
    downloader?.cancel();
    if (!_busy) {
      unawaited(_releaseHeldSource());
      _downloader = null;
      unawaited(downloader?.dispose());
    }
  }
}
