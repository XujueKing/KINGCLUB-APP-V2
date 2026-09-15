import 'package:video_player/video_player.dart';

import '../data/chat_video.dart';
import '../data/chat_video_optimizer.dart';
import '../data/chat_file_draft_store.dart';

import 'dart:async';
import 'dart:io';

import '../../../core/session/secure_session_store.dart';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../data/chat_file_uploader.dart';
import '../data/chat_session_controller.dart';

/// Selected local file remains available for retry until durably queued.
class ChatVideoSendPage extends StatefulWidget {
  const ChatVideoSendPage({
    super.key,
    required this.file,
    required this.fileName,
    required this.chat,
    this.draft,
    this.drafts,
    this.createUploader,
    this.createPreview,
  });
  final Future<ChatFileUploader> Function()? createUploader;
  final VideoPlayerController Function(File)? createPreview;
  final ChatFileDraft? draft;
  final ChatFileDraftStore? drafts;
  final File file;
  final String fileName;
  final ChatSessionController chat;
  @override
  State<ChatVideoSendPage> createState() => _ChatVideoSendPageState();
}

class _ChatVideoSendPageState extends State<ChatVideoSendPage> {
  ChatFileUploader? _uploader;
  late final ChatVideoOptimizer _optimizer;
  bool _optimizing = false, _invalid = false;
  StreamSubscription<void>? _session;
  bool get _usable => mounted && !_invalid;
  VideoPlayerController? _preview;
  UploadedChatFile? _uploaded;
  ChatVideo? _prepared;
  bool _processing = false;
  @override
  void initState() {
    super.initState();
    _optimizer = ChatVideoOptimizer(account: widget.chat.messaging.account);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _optimizer.dispose();
      _uploader?.dispose();
      _preview?.pause();
      if (mounted) setState(() => _error = '登录状态已变化，请重新进入会话');
    });
    final player =
        widget.createPreview?.call(widget.file) ??
        VideoPlayerController.file(widget.file);
    _preview = player;
    player
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object error) {
          if (mounted) setState(() => _error = '无法预览该视频，请重新选择');
        });
  }

  bool _busy = false;
  String? _error;
  String? _uploadSize;
  double? _progress;

  @override
  void dispose() {
    _session?.cancel();
    _optimizer.dispose();
    _preview?.dispose();
    _uploader?.dispose();
    super.dispose();
  }

  bool get _alreadyQueued =>
      widget.draft != null &&
      widget.chat.messages.any(
        (message) =>
            message['clientMessageId'] == widget.draft!.id &&
            message['sender'] == widget.chat.messaging.account &&
            message['messageType'] == 'video',
      );

  Future<void> _send() async {
    if (_busy || _invalid) return;
    var stage = 'opening';
    final elapsed = Stopwatch()..start();
    void trace(String next) {
      stage = next;
      debugPrint(
        'KINGCLUB_VIDEO_SEND stage=$stage elapsedMs=${elapsed.elapsedMilliseconds}',
      );
    }

    trace('opening');
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    try {
      if (_alreadyQueued) {
        try {
          await widget.drafts?.remove(widget.draft!.id);
        } catch (_) {}
        if (mounted && _usable) Navigator.of(context).pop(true);
        return;
      }
      final uploader =
          _uploader ??
          await (widget.createUploader?.call() ??
              ChatFileUploader.open(widget.chat.messaging));
      if (!_usable) {
        uploader.dispose();
        return;
      }
      _uploader = uploader;
      File uploadInput = widget.file;
      if (_uploaded == null) {
        await _preview?.pause();
        if (!_usable) return;
        setState(() => _optimizing = true);
        trace('optimizing');
        uploadInput = await _optimizer.prepare(
          widget.file,
          onProgress: (value) {
            if (_usable && _optimizing) setState(() => _progress = value);
          },
        );
        if (!_usable) return;
        final sourceBytes = await widget.file.length();
        final uploadBytes = await uploadInput.length();
        if (!_usable) return;
        String size(int bytes) =>
            '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
        setState(() {
          _uploadSize = uploadBytes < sourceBytes
              ? '已压缩：${size(sourceBytes)} → ${size(uploadBytes)}'
              : '上传原视频：${size(uploadBytes)}';
          _optimizing = false;
          _progress = null;
        });
      }
      trace('uploading');
      final file =
          _uploaded ??
          await uploader.upload(
            uploadInput,
            fileName: uploadInput.path == widget.file.path
                ? widget.fileName
                : 'video.mp4',
            onProgress: (sent, total) {
              if (_usable && total > 0) {
                setState(() => _progress = sent / total);
              }
            },
          );
      if (!_usable) return;
      _uploaded = file;
      setState(() {
        _processing = true;
        _progress = null;
      });
      trace('processing');
      final video =
          _prepared ?? await widget.chat.messaging.prepareVideo(file.assetId);
      if (!_usable) return;
      _prepared = video;
      var queued = _alreadyQueued;
      trace('queueing');
      if (!queued) {
        await widget.chat.sendVideo(
          video,
          onQueued: () => queued = true,
          clientMessageId: widget.draft?.id,
        );
      }
      if (!queued) throw StateError('会话已关闭，请重新进入后发送');
      trace('queued');
      // A journal cleanup error must not invite a second send of an already
      // durable message. The outbox now owns delivery and retry.
      try {
        if (widget.draft != null) await widget.drafts?.remove(widget.draft!.id);
        await uploader.acknowledgeQueued(file);
        await _optimizer.acknowledgeQueued();
      } catch (_) {}
      if (mounted && _usable) Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint(
        'KINGCLUB_VIDEO_SEND failedStage=$stage elapsedMs=${elapsed.elapsedMilliseconds} errorType=${error.runtimeType}',
      );
      if (_usable) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _processing = false;
          _optimizing = false;
        });
      }
    }
  }

  Future<void> _discard() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.drafts!.remove(widget.draft!.id);
      if (mounted) Navigator.of(context).pop(false);
    } catch (_) {
      if (mounted) setState(() => _error = '未能丢弃草稿，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _processing = false;
          _optimizing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      leading: KingBackButton(onPressed: () => Navigator.of(context).pop()),
      title: const Text('发送视频'),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_preview?.value.isInitialized == true)
                      Flexible(
                        child: AspectRatio(
                          aspectRatio: _preview!.value.aspectRatio,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _preview!.value.isPlaying
                                    ? _preview!.pause()
                                    : _preview!.play();
                              });
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_preview!),
                                if (!_preview!.value.isPlaying)
                                  const Icon(
                                    Icons.play_circle_outline,
                                    size: 56,
                                    color: Colors.white,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      const Icon(
                        Icons.videocam_outlined,
                        size: 64,
                        color: Colors.white70,
                      ),
                    const SizedBox(height: 16),
                    Text(widget.fileName, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
          if (widget.draft != null && widget.drafts != null)
            TextButton(
              onPressed: _busy ? null : _discard,
              child: const Text('丢弃草稿'),
            ),
          if (_uploadSize != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                _uploadSize!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          if (_busy) LinearProgressIndicator(value: _progress),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy || _invalid ? null : _send,
                child: Text(
                  _busy
                      ? (_optimizing
                            ? (_progress == null
                                  ? '正在压缩视频…'
                                  : '正在压缩视频 ${(100 * _progress!).floor()}%')
                            : _processing
                            ? '正在处理视频…'
                            : '正在上传…')
                      : '发送',
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
