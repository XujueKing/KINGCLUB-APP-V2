import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/media/media_cache.dart';
import '../../../core/session/secure_session_store.dart';

import '../../../core/design_system/king_components.dart';
import '../data/chat_image_uploader.dart';
import '../data/chat_file_draft_store.dart';
import '../data/chat_session_controller.dart';

/// Selected local image stays on screen until it is durably queued.
class ChatImageSendPage extends StatefulWidget {
  const ChatImageSendPage({
    super.key,
    required this.bytes,
    required this.chat,
    this.title = '发送照片',
    this.draft,
    this.drafts,
    this.mediaStore,
    this.createUploader,
  });
  final String title;
  final Uint8List bytes;
  final ChatSessionController chat;
  final ChatFileDraft? draft;
  final ChatFileDraftStore? drafts;
  final MediaCache? mediaStore;
  final Future<ChatImageUploader> Function()? createUploader;
  @override
  State<ChatImageSendPage> createState() => _ChatImageSendPageState();
}

class _ChatImageSendPageState extends State<ChatImageSendPage> {
  ChatImageUploader? _uploader;
  UploadedChatImage? _uploaded;
  late final String _clientMessageId = widget.draft?.id ?? const Uuid().v4();
  StreamSubscription<void>? _session;
  bool _invalid = false;
  bool get _usable => mounted && !_invalid;

  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      if (mounted) setState(() => _error = '登录状态已变化，请重新进入会话');
    });
  }

  Future<void> _retainImage() => (widget.mediaStore ?? MediaCache.shared)
      .importBytes(
        widget.bytes,
        scope: 'member:${widget.chat.messaging.account}',
        contentKey: 'chat-image-sent:$_clientMessageId',
        kind: MediaKind.image,
      )
      .then((_) {});
  bool _busy = false;
  String? _error;
  double? _progress;

  bool get _alreadyQueued =>
      widget.draft != null &&
      widget.chat.messages.any(
        (message) =>
            message['clientMessageId'] == widget.draft!.id &&
            message['sender'] == widget.chat.messaging.account &&
            message['messageType'] == 'image',
      );

  @override
  void dispose() {
    _session?.cancel();
    _uploader?.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_usable) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    try {
      if (_alreadyQueued) {
        await _retainImage();
        if (!_usable) return;
        try {
          await widget.drafts?.remove(widget.draft!.id);
        } catch (_) {}
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      final uploader =
          _uploader ??
          await (widget.createUploader?.call() ??
              ChatImageUploader.open(widget.chat.messaging));
      if (!_usable) {
        uploader.dispose();
        return;
      }
      _uploader = uploader;
      final image =
          _uploaded ??
          await uploader.upload(
            widget.bytes,
            onProgress: (sent, total) {
              if (_usable && total > 0) {
                setState(() => _progress = sent / total);
              }
            },
          );
      if (!_usable) return;
      _uploaded = image;
      await _retainImage();
      if (!_usable) return;
      var queued = _alreadyQueued;
      if (!queued) {
        await widget.chat.sendImage(
          image.assetId,
          onQueued: () => queued = true,
          clientMessageId: _clientMessageId,
        );
      }
      if (!queued) throw StateError('会话已关闭，请重新进入后发送');
      // A journal cleanup error must not invite a second send of an already
      // durable message. The outbox now owns delivery and retry.
      try {
        if (widget.draft != null) await widget.drafts?.remove(widget.draft!.id);
        await uploader.acknowledgeQueued(image);
      } catch (_) {}
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    if (_busy || widget.draft == null || widget.drafts == null) return;
    setState(() => _busy = true);
    try {
      await widget.drafts!.remove(widget.draft!.id);
      if (mounted) Navigator.of(context).pop(false);
    } catch (_) {
      if (mounted) setState(() => _error = '未能丢弃照片草稿，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: kingAppBar(
      context: context,
      backgroundColor: Colors.black,
      leading: KingBackButton(onPressed: () => Navigator.of(context).pop()),
      title: Text(widget.title),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.memory(
                widget.bytes,
                fit: BoxFit.contain,
                cacheWidth: 1080,
                errorBuilder: (_, _, _) => const Text('无法预览此图片'),
              ),
            ),
          ),
          if (_busy) LinearProgressIndicator(value: _progress),
          if (widget.draft != null && widget.drafts != null)
            TextButton(
              onPressed: _busy ? null : _discard,
              child: const Text('放弃这张照片'),
            ),
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
                child: Text(_busy ? '正在发送…' : '发送'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
