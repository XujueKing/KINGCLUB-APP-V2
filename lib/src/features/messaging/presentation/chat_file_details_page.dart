import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../data/chat_file_downloader.dart';
import '../data/messaging_repository.dart';
import 'chat_file_card.dart';

class ChatFileDetailsPage extends StatefulWidget {
  const ChatFileDetailsPage({
    super.key,
    required this.reference,
    required this.repository,
    this.openDownloader,
  });
  final ChatFileReference reference;
  final MessagingRepository repository;
  final Future<ChatFileDownloader> Function(MessagingRepository)?
  openDownloader;
  @override
  State<ChatFileDetailsPage> createState() => _ChatFileDetailsPageState();
}

class _ChatFileDetailsPageState extends State<ChatFileDetailsPage> {
  ChatFileDownloader? _downloader;
  bool _busy = false, _cancelled = false;
  double? _progress;
  String? _error;
  File? _file;

  Future<void> _download() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _cancelled = false;
      _error = null;
      _progress = null;
    });
    try {
      final downloader =
          _downloader ??
          await (widget.openDownloader ?? ChatFileDownloader.open)(
            widget.repository,
          );
      if (!mounted) {
        await downloader.dispose();
        return;
      }
      _downloader = downloader;
      if (_cancelled) return;
      final file = await downloader.download(
        widget.reference,
        onProgress: (received, total) {
          if (mounted) {
            setState(() => _progress = total == 0 ? 1 : received / total);
          }
        },
      );
      if (mounted && !_cancelled) setState(() => _file = file);
    } catch (_) {
      if (mounted && !_cancelled) setState(() => _error = '下载未完成，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancel() {
    _cancelled = true;
    _downloader?.cancel();
  }

  @override
  void dispose() {
    _downloader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      leading: KingBackButton(onPressed: () => Navigator.of(context).pop()),
      title: const Text('文件'),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChatFileCard(
                      fileName: widget.reference.fileName,
                      size: widget.reference.size,
                    ),
                    const SizedBox(height: 16),
                    if (_file != null)
                      const Text(
                        '下载完成，文件校验通过',
                        style: TextStyle(color: Colors.white70),
                      ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ),
            if (_busy) ...[
              LinearProgressIndicator(value: _progress),
              TextButton(onPressed: _cancel, child: const Text('取消下载')),
            ] else if (_file == null)
              FilledButton(
                onPressed: _download,
                child: Text(_error == null ? '下载文件' : '重新下载'),
              ),
          ],
        ),
      ),
    ),
  );
}
