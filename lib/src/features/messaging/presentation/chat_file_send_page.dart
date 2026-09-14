import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../data/chat_file_uploader.dart';
import '../data/chat_session_controller.dart';

/// Selected local file remains available for retry until durably queued.
class ChatFileSendPage extends StatefulWidget {
  const ChatFileSendPage({
    super.key,
    required this.file,
    required this.fileName,
    required this.chat,
  });
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

  @override
  void dispose() {
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
      final file = await uploader.upload(
        widget.file,
        fileName: widget.fileName,
        onProgress: (sent, total) {
          if (mounted && total > 0) setState(() => _progress = sent / total);
        },
      );
      if (!mounted) return;
      var queued = false;
      await widget.chat.sendFile(
        file.assetId,
        file.fileName,
        file.size,
        file.sha256,
        onQueued: () => queued = true,
      );
      if (!queued) throw StateError('会话已关闭，请重新进入后发送');
      // A journal cleanup error must not invite a second send of an already
      // durable message. The outbox now owns delivery and retry.
      try {
        await uploader.acknowledgeQueued(file);
      } catch (_) {}
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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
                    Text(widget.fileName, textAlign: TextAlign.center),
                  ],
                ),
              ),
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
