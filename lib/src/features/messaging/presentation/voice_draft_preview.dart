import '../../../core/session/member_qr_memory.dart';

import 'dart:async';

import '../data/voice_draft_store.dart';
import '../../../core/session/secure_session_store.dart';

import 'dart:io';

import '../data/chat_voice_playback.dart';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_notice.dart';
import '../data/voice_capture.dart';

class VoiceDraftPreview extends StatefulWidget {
  const VoiceDraftPreview({
    super.key,
    required this.draft,
    this.onSend,
    this.output,
    this.loadStore,
  });
  final ChatVoiceOutput? output;
  final Future<VoiceDraftStore> Function()? loadStore;
  final VoiceDraft draft;
  final Future<void> Function()? onSend;
  @override
  State<VoiceDraftPreview> createState() => _VoiceDraftPreviewState();
}

class _VoiceDraftPreviewState extends State<VoiceDraftPreview>
    with WidgetsBindingObserver {
  late final _player = widget.output ?? NativeChatVoiceOutput();
  bool _playing = false;
  bool _toggling = false;
  bool _foreground = true;
  int _playGeneration = 0;
  StreamSubscription<void>? _completion;
  bool _sending = false;
  int _sendGeneration = 0;
  bool _valid = true;
  StreamSubscription<void>? _session;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _playGeneration++;
      _sendGeneration++;
      _player.stop().catchError((Object _) {});
      if (mounted) {
        setState(() {
          _valid = false;
          _playing = false;
        });
      }
    });
    _completion = _player.completed.listen(
      (_) {
        _playGeneration++;
        if (mounted) setState(() => _playing = false);
      },
      onError: (Object _, StackTrace _) {
        if (!mounted || !_valid || !_foreground) return;
        _playGeneration++;
        _player.stop().catchError((Object _) {});
        setState(() => _playing = false);
        KingNotice.of(context).show('播放中断，录音已保留，请重试');
      },
    );
  }

  Future<void> _toggle() async {
    if (_toggling || !_valid || !_foreground || _sending) return;
    final generation = ++_playGeneration;
    setState(() => _toggling = true);
    bool current() =>
        mounted && _valid && _foreground && generation == _playGeneration;
    try {
      final store = await (widget.loadStore ?? VoiceDraftStore.current)();
      if (!current()) return;
      if (!store.owns(widget.draft.path)) {
        throw StateError('录音不属于当前账号');
      }
      if (_playing) {
        await _player.stop();
      } else {
        await _player.play(widget.draft.path);
      }
      if (!current()) {
        await _player.stop();
        return;
      }
      if (mounted) setState(() => _playing = !_playing);
    } catch (_) {
      if (mounted && current()) KingNotice.of(context).show('播放失败，请重新录音');
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _playGeneration++;
      _sendGeneration++;
      _player.stop().catchError((Object _) {});
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _send() async {
    if (!_valid ||
        !_foreground ||
        _sending ||
        _toggling ||
        widget.onSend == null) {
      return;
    }
    final generation = ++_sendGeneration;
    setState(() => _sending = true);
    try {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      if (!mounted ||
          !_valid ||
          !_foreground ||
          generation != _sendGeneration) {
        return;
      }
      await widget.onSend!();
      if (mounted && _valid && generation == _sendGeneration) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted && _valid && _foreground && generation == _sendGeneration) {
        KingNotice.of(context).show('发送未完成，录音已保留，请重试');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _playGeneration++;
    _sendGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _session?.cancel();
    _completion?.cancel();
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
            onPressed: _valid && !_sending && !_toggling ? _toggle : null,
            icon: Icon(
              _playing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
              size: 40,
            ),
          ),
          const Text(
            '已保存在本机，尚未发送',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (widget.onSend != null)
            FilledButton(
              onPressed: _valid && !_sending && !_toggling ? _send : null,
              child: Text(_sending ? '正在发送…' : '发送语音'),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: !_valid || _sending || _toggling
                    ? null
                    : () async {
                        try {
                          await _player.stop();
                          final store =
                              await (widget.loadStore ??
                                  VoiceDraftStore.current)();
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

Future<void> showVoiceDrafts(
  BuildContext context, {
  Future<void> Function(VoiceDraft)? onSend,
}) async {
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
                  onTap: () async {
                    if (generation != MemberQrMemory.generation) return;
                    final draft = VoiceDraft(files[index].path, Duration.zero);
                    await showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      backgroundColor: const Color(0xFF191715),
                      builder: (_) => VoiceDraftPreview(
                        draft: draft,
                        onSend: onSend == null ? null : () => onSend(draft),
                      ),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
      ),
    ),
  );
}
