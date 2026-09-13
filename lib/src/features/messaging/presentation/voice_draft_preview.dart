import '../../../core/session/member_qr_memory.dart';

import 'dart:async';

import '../data/voice_draft_store.dart';
import '../../../core/session/secure_session_store.dart';

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
  bool _valid = true;
  StreamSubscription<void>? _session;
  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      _player.stop().catchError((Object _) {});
      if (mounted) {
        setState(() {
          _valid = false;
          _playing = false;
        });
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _toggle() async {
    try {
      final store = await VoiceDraftStore.current();
      if (!_valid || !store.owns(widget.draft.path)) {
        throw StateError('录音不属于当前账号');
      }
      if (_playing) {
        await _player.stop();
      } else {
        await _player.play(DeviceFileSource(widget.draft.path));
      }
      if (!_valid) {
        await _player.stop();
        return;
      }
      if (mounted) setState(() => _playing = !_playing);
    } catch (_) {
      if (mounted) KingNotice.of(context).show('播放失败，请重新录音');
    }
  }

  @override
  void dispose() {
    _session?.cancel();
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
            onPressed: _valid ? _toggle : null,
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
                onPressed: !_valid
                    ? null
                    : () async {
                        try {
                          await _player.stop();
                          final store = await VoiceDraftStore.current();
                          if (!_valid || !store.owns(widget.draft.path)) return;
                          final file = File(widget.draft.path);
                          if (await file.exists()) await file.delete();
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (context.mounted) {
                            KingNotice.of(context).show('无法删除录音，请重试');
                          }
                        }
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
  final generation = MemberQrMemory.generation;
  List<File> files;
  try {
    files = await (await VoiceDraftStore.current()).list();
  } catch (_) {
    if (context.mounted) KingNotice.of(context).show('请重新登录后查看录音');
    return;
  }
  if (!context.mounted || generation != MemberQrMemory.generation) return;
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
