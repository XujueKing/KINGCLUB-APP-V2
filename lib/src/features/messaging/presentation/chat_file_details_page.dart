import '../data/chat_file_exporter.dart';
import '../data/chat_media_deletion.dart';

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
  ChatFileExporter? _exporter;
  bool _saving = false, _saved = false, _opening = false;
  bool _removed = false;
  late final void Function() _removeDeletionListener;

  @override
  void initState() {
    super.initState();
    _removeDeletionListener = ChatMediaDeletion.listen((event) {
      if (!mounted ||
          event.account != widget.repository.account ||
          event.group != widget.reference.group ||
          event.messageId != widget.reference.messageId) {
        return;
      }
      _cancel();
      setState(() {
        _removed = true;
        _file = null;
        _saved = false;
        _error = null;
      });
    });
  }

  Future<void> _openSaved() async {
    if (_removed || _opening || _saving) return;
    setState(() => _opening = true);
    try {
      final opened = await _exporter?.openSaved() ?? false;
      if (!opened && mounted) setState(() => _error = '无法打开文件，请从保存位置查看');
    } catch (_) {
      if (mounted) setState(() => _error = '无法打开文件，请选择支持此格式的应用');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _save() async {
    final file = _file, downloader = _downloader;
    if (_removed || file == null || downloader == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved =
          await (_exporter ??= ChatFileExporter(
            account: widget.repository.account,
          )).save(
            file,
            widget.reference,
            () => downloader.authorizeExport(widget.reference),
          );
      if (mounted && !_removed) setState(() => _saved = saved);
    } catch (_) {
      if (mounted) setState(() => _error = '保存未完成，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _download() async {
    if (_removed || _busy) return;
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
      if (mounted && !_cancelled) setState(() => _error = '文件读取未完成，请重试');
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
    _removeDeletionListener();
    _exporter?.dispose();
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
                      Text(
                        _downloader?.lastReadWasLocal == true
                            ? '已从本地读取，文件校验通过'
                            : '下载完成，文件校验通过',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    if (_saved)
                      const Text(
                        '已保存到所选位置',
                        style: TextStyle(color: Colors.white70),
                      ),
                    if (_removed)
                      const Text(
                        '内容已移除',
                        style: TextStyle(color: Colors.white70),
                      ),
                    if (_error != null && !_removed)
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ),
            if (_removed)
              const SizedBox.shrink()
            else if (_busy) ...[
              LinearProgressIndicator(value: _progress),
              TextButton(onPressed: _cancel, child: const Text('取消读取')),
            ] else if (_file == null)
              FilledButton(
                onPressed: _download,
                child: Text(_error == null ? '读取文件' : '重试读取'),
              )
            else if (Platform.isAndroid)
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '正在保存…' : '保存到文件'),
              ),
            if (_saved && Platform.isAndroid)
              TextButton(
                onPressed: _saving || _opening ? null : _openSaved,
                child: const Text('打开已保存文件'),
              ),
          ],
        ),
      ),
    ),
  );
}
