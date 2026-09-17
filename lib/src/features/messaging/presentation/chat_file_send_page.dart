import '../data/chat_file_draft_store.dart';
import '../data/chat_outbox.dart';

import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/chat_file_uploader.dart';
import '../data/chat_session_controller.dart';

/// Selected local file remains available for retry until durably queued.
class ChatFileSendPage extends StatefulWidget {
  const ChatFileSendPage({
    super.key,
    required this.file,
    required this.fileName,
    required this.chat,
    this.draft,
    this.drafts,
    this.createUploader,
  });
  final Future<ChatFileUploader> Function()? createUploader;
  final ChatFileDraft? draft;
  final ChatFileDraftStore? drafts;
  final File file;
  final String fileName;
  final ChatSessionController chat;
  @override
  State<ChatFileSendPage> createState() => _ChatFileSendPageState();
}

class _ChatFileSendPageState extends State<ChatFileSendPage> {
  ChatFileUploader? _uploader;
  bool _busy = false;
  String? _error;
  double? _progress;
  bool _invalid = false;
  StreamSubscription<void>? _session;
  bool get _usable => mounted && !_invalid;

  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (!mounted) return;
      _uploader?.dispose();
      _uploader = null;
      setState(() {
        _invalid = true;
        _busy = false;
        _progress = null;
        _error = '登录状态已变化，请重新进入会话';
      });
    });
  }

  bool get _alreadyQueued =>
      widget.draft != null &&
      widget.chat.messages.any(
        (message) =>
            message['clientMessageId'] == widget.draft!.id &&
            message['sender'] == widget.chat.messaging.account &&
            message['messageType'] == 'file',
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
    Future<void> Function()? releaseSource;
    try {
      if (_alreadyQueued) {
        try {
          await widget.drafts?.remove(widget.draft!.id);
        } catch (_) {}
        if (mounted && !_invalid) Navigator.of(context).pop(true);
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
      final file = await uploader.upload(
        widget.file,
        fileName: widget.fileName,
        onProgress: (sent, total) {
          if (_usable && total > 0) setState(() => _progress = sent / total);
        },
      );
      if (!_usable) return;
      releaseSource = await SecureChatOutbox(
        widget.chat.messaging.account,
      ).holdMediaSource({'messageType': 'file', 'fileAssetId': file.assetId});
      if (!_usable) return;
      var queued = _alreadyQueued;
      if (!queued) {
        await widget.chat.sendFile(
          file.assetId,
          file.fileName,
          file.size,
          file.sha256,
          onQueued: () => queued = true,
          clientMessageId: widget.draft?.id,
        );
      }
      if (!queued) throw StateError('会话已关闭，请重新进入后发送');
      if (!_usable) return;
      await uploader.retainQueuedSource(widget.file, file);
      // A journal cleanup error must not invite a second send of an already
      // durable message. The outbox now owns delivery and retry.
      try {
        if (widget.draft != null) await widget.drafts?.remove(widget.draft!.id);
        await uploader.acknowledgeQueued(file);
      } catch (_) {}
      if (mounted && !_invalid) Navigator.of(context).pop(true);
    } catch (error) {
      if (_usable) setState(() => _error = error.toString());
    } finally {
      await releaseSource?.call();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    if (_busy || !_usable) return;
    setState(() => _busy = true);
    try {
      await widget.drafts!.remove(widget.draft!.id);
      if (mounted && !_invalid) Navigator.of(context).pop(false);
    } catch (_) {
      if (_usable) setState(() => _error = '未能丢弃草稿，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      leading: KingBackButton(onPressed: () => Navigator.of(context).pop()),
      title: const Text('发送文件'),
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
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 64,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 16),
                    if (!_invalid)
                      Text(widget.fileName, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
          if (widget.draft != null && widget.drafts != null)
            TextButton(
              onPressed: _busy || _invalid ? null : _discard,
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
                onPressed: _busy || _invalid ? null : _send,
                child: Text(_busy ? '正在发送…' : '发送'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
