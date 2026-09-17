import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/messaging_repository.dart';
import '../data/chat_media_deletion.dart';
import '../data/chat_media_event_scope.dart';

class MessageVoiceTranscriptionPage extends StatefulWidget {
  const MessageVoiceTranscriptionPage({
    super.key,
    required this.repository,
    required this.messageId,
    required this.group,
    this.scopeId,
    this.events,
  });
  final MessagingRepository repository;
  final String messageId;
  final bool group;
  final String? scopeId;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<MessageVoiceTranscriptionPage> createState() =>
      _MessageVoiceTranscriptionPageState();
}

class _MessageVoiceTranscriptionPageState
    extends State<MessageVoiceTranscriptionPage>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  String? _text, _error;
  bool _busy = false, _invalid = false, _foreground = true;
  int _generation = 0, _revision = 0;
  Future<void>? _checking;
  late final void Function() _removeDeletionListener;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _removeDeletionListener = ChatMediaDeletion.listen((event) {
      if (event.account != widget.repository.account ||
          event.group != widget.group ||
          event.messageId != widget.messageId) {
        return;
      }
      _invalid = true;
      _clear('内容已移除');
    });
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _clear('登录状态已变化');
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      if (_invalid || !_foreground) return;
      if (affectsChatMedia(
        event,
        group: widget.group,
        scopeId: widget.scopeId,
      )) {
        _revision++;
        unawaited(
          _check().catchError((Object _) {
            if (mounted && !_invalid) _clear('该语音暂不可查看');
          }),
        );
      }
    });
    _load();
  }

  void _clear(String error) {
    if (!mounted) return;
    setState(() {
      _generation++;
      _text = null;
      _error = error;
      _busy = false;
    });
  }

  Future<void> _check() {
    if (_invalid) return Future.error(StateError('Session changed'));
    if (_checking != null) return _checking!;
    final future = _checkCurrent();
    _checking = future;
    return future.whenComplete(() {
      if (identical(_checking, future)) _checking = null;
    });
  }

  Future<void> _checkCurrent() async {
    while (mounted && !_invalid && _foreground) {
      final revision = _revision;
      final value = await widget.repository.voiceMedia(
        widget.messageId,
        group: widget.group,
      );
      if (_invalid) throw StateError('Session changed');
      if (value['messageId'] != widget.messageId || value['voice'] is! Map) {
        throw const FormatException('Invalid permission');
      }
      if (revision == _revision) return;
    }
  }

  Future<void> _load() async {
    if (_busy || _invalid || !_foreground) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _text = null;
    });
    try {
      final result = await widget.repository.call('K260915000675', {
        'messageId': widget.messageId,
        'kind': widget.group ? 'group' : 'direct',
      });
      final text = result['text'];
      if (result['messageId'] != widget.messageId ||
          result['kind'] != (widget.group ? 'group' : 'direct') ||
          text is! String ||
          text.length > 4000 ||
          !['recognized', 'no-speech'].contains(result['status'])) {
        throw const FormatException('Invalid transcription');
      }
      if (!mounted || _invalid || !_foreground || generation != _generation) {
        return;
      }
      await _check();
      if (mounted && !_invalid && generation == _generation) {
        setState(() => _text = text.trim().isEmpty ? '未识别到清晰语音' : text.trim());
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = '转文字暂不可用，请稍后重试');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && !_invalid) {
      _clear('返回后请重新识别');
    }
  }

  @override
  void dispose() {
    _generation++;
    _removeDeletionListener();
    WidgetsBinding.instance.removeObserver(this);
    _session?.cancel();
    _events?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('转文字'),
      leading: KingBackButton(onPressed: () => Navigator.pop(context)),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          if (_text != null)
            Expanded(
              child: SingleChildScrollView(child: SelectableText(_text!)),
            ),
          if (_error != null) Text(_error!),
          if (!_busy && _text == null)
            TextButton(
              onPressed: _invalid ? null : _load,
              child: const Text('重试'),
            ),
        ],
      ),
    ),
  );
}
