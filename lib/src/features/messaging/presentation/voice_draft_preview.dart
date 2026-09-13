import 'package:path_provider/path_provider.dart';

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/design_system/king_notice.dart';
import '../data/voice_capture.dart';

class VoiceDraftPreview extends StatefulWidget {
  const VoiceDraftPreview({super.key, required this.draft});
  final VoiceDraft draft;
  @override
  State<VoiceDraftPreview> createState() => _VoiceDraftPreviewState();
}

class _VoiceDraftPreviewState extends State<VoiceDraftPreview> {
  late final _player = AudioPlayer();
  bool _playing = false;
  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.stop();
      } else {
        await _player.play(DeviceFileSource(widget.draft.path));
      }
      if (mounted) setState(() => _playing = !_playing);
    } catch (_) {
      if (mounted) KingNotice.of(context).show('播放失败，请重新录音');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('语音预览', style: TextStyle(fontSize: 17)),
          const SizedBox(height: 16),
          if (widget.draft.duration > Duration.zero)
            Text('${widget.draft.duration.inSeconds} 秒'),
          IconButton(
            tooltip: _playing ? '停止播放' : '播放录音',
            onPressed: _toggle,
            icon: Icon(
              _playing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
              size: 40,
            ),
          ),
          const Text(
            '已保存在本机，尚未发送',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () async {
                  await _player.stop();
                  final file = File(widget.draft.path);
                  if (await file.exists()) await file.delete();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('删除录音'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('保留草稿'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> showVoiceDrafts(BuildContext context) async {
  final root = await getApplicationSupportDirectory();
  final directory = Directory('${root.path}/voice_drafts');
  final files = await directory.exists()
      ? await directory
            .list()
            .where((f) => f is File && f.path.endsWith('.m4a'))
            .cast<File>()
            .toList()
      : <File>[];
  files.sort((a, b) => b.path.compareTo(a.path));
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFF191715),
    builder: (context) => SafeArea(
      child: SizedBox(
        height: 320,
        child: files.isEmpty
            ? const Center(child: Text('还没有语音草稿'))
            : ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.mic_none),
                  title: Text('语音草稿 ${files.length - index}'),
                  trailing: const Icon(Icons.play_circle_outline),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    backgroundColor: const Color(0xFF191715),
                    builder: (_) => VoiceDraftPreview(
                      draft: VoiceDraft(files[index].path, Duration.zero),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}
