import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/secure_session_store.dart';
import '../../../core/session/member_qr_memory.dart';
import '../data/voice_capture.dart';
import '../data/messaging_repository.dart';
import '../data/voice_draft_transcriber.dart';

class VoiceTranscriptionPage extends StatefulWidget {
  const VoiceTranscriptionPage({
    super.key,
    required this.draft,
    required this.repository,
    this.convert,
  });
  final VoiceDraft draft;
  final MessagingRepository repository;
  final Future<String> Function()? convert;
  @override
  State<VoiceTranscriptionPage> createState() => _VoiceTranscriptionPageState();
}

class _VoiceTranscriptionPageState extends State<VoiceTranscriptionPage> {
  late final _transcriber = VoiceDraftTranscriber(widget.repository);
  final _text = TextEditingController();
  StreamSubscription<void>? _session;
  bool _busy = false, _invalid = false, _ready = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      _transcriber.dispose();
      if (mounted) {
        setState(() {
          _invalid = true;
          _text.clear();
          _error = '登录状态已变化，请重新进入';
        });
      }
    });
    _run();
  }

  Future<void> _run() async {
    if (_busy || _invalid) return;
    final generation = MemberQrMemory.generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text =
          await (widget.convert?.call() ??
              _transcriber.transcribe(widget.draft));
      if (!mounted || _invalid || generation != MemberQrMemory.generation) {
        return;
      }
      setState(() {
        _text.text = text;
        _ready = true;
        if (text.isEmpty) _error = '未识别到清晰语音，可重试或返回保留录音';
      });
    } catch (_) {
      if (mounted && !_invalid) setState(() => _error = '转文字暂不可用，录音已保留，可稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _session?.cancel();
    _transcriber.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF191715),
    appBar: kingAppBar(
      context: context,
      title: const Text('转文字'),
      leading: KingBackButton(onPressed: () => Navigator.pop(context)),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          if (_busy) const Text('正在识别，原录音已保留'),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.white70)),
          Expanded(
            child: TextField(
              controller: _text,
              enabled: _ready && !_busy && !_invalid,
              maxLines: null,
              expands: true,
              maxLength: 4000,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: '识别结果可在这里修改',
                border: InputBorder.none,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _busy || _invalid ? null : _run,
                child: const Text('重新识别'),
              ),
              FilledButton(
                onPressed: _busy || _invalid || !_ready
                    ? null
                    : () {
                        final text = _text.text.trim();
                        if (text.isNotEmpty) Navigator.pop(context, text);
                      },
                child: const Text('使用文字'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
