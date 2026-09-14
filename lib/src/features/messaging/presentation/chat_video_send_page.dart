import 'package:video_player/video_player.dart';

import '../data/chat_video.dart';
import '../data/chat_video_optimizer.dart';
import '../data/chat_file_draft_store.dart';

import 'dart:io';

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
  });
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
  bool _optimizing = false;
  VideoPlayerController? _preview;
  UploadedChatFile? _uploaded;
  ChatVideo? _prepared;
  bool _processing = false;
  @override
  void initState() {
    super.initState();
    _optimizer = ChatVideoOptimizer(account: widget.chat.messaging.account);
    final player = VideoPlayerController.file(widget.file);
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
  double? _progress;

  @override
  void dispose() {
    _optimizer.dispose();
    _preview?.dispose();
    _uploader?.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    try {
      final uploader =
          _uploader ?? await ChatFileUploader.open(widget.chat.messaging);
      if (!mounted) {
        uploader.dispose();
        return;
      }
      _uploader = uploader;
      File uploadInput = widget.file;
      if (_uploaded == null) {
        await _preview?.pause();
        setState(() => _optimizing = true);
        uploadInput = await _optimizer.prepare(
          widget.file,
          onProgress: (value) {
            if (mounted && _optimizing) setState(() => _progress = value);
          },
        );
        if (!mounted) return;
        setState(() {
          _optimizing = false;
          _progress = null;
        });
      }
      final file =
          _uploaded ??
          await uploader.upload(
            uploadInput,
            fileName: uploadInput.path == widget.file.path
                ? widget.fileName
                : 'video.mp4',
            onProgress: (sent, total) {
              if (mounted && total > 0) {
                setState(() => _progress = sent / total);
              }
            },
          );
      if (!mounted) return;
      _uploaded = file;
      setState(() {
        _processing = true;
        _progress = null;
      });
      final video =
          _prepared ?? await widget.chat.messaging.prepareVideo(file.assetId);
      if (!mounted) return;
      _prepared = video;
      var queued = false;
      await widget.chat.sendVideo(
        video,
        onQueued: () => queued = true,
        clientMessageId: widget.draft?.id,
      );
      if (!queued) throw StateError('会话已关闭，请重新进入后发送');
      // A journal cleanup error must not invite a second send of an already
      // durable message. The outbox now owns delivery and retry.
      try {
        if (widget.draft != null) await widget.drafts?.remove(widget.draft!.id);
        await uploader.acknowledgeQueued(file);
        await _optimizer.acknowledgeQueued();
      } catch (_) {}
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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
                onPressed: _busy ? null : _send,
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
