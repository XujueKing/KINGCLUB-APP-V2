import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/chat_history_context.dart';
import 'legacy_messaging_components.dart';

class ChatHistoryContextPage extends StatefulWidget {
  const ChatHistoryContextPage({
    super.key,
    required this.read,
    required this.messageId,
    required this.sequence,
    required this.account,
  });
  final ContextHistoryReader read;
  final String messageId, account;
  final int sequence;
  @override
  State<ChatHistoryContextPage> createState() => _ChatHistoryContextPageState();
}

class _ChatHistoryContextPageState extends State<ChatHistoryContextPage>
    with WidgetsBindingObserver {
  final _target = GlobalKey();
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  bool _invalid = false, _foreground = true;
  int _generation = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _generation++;
      if (mounted) {
        setState(() {
          _messages = [];
          _error = '登录状态已变化';
        });
      }
    });
    _events = KingclubRealtime.shared.events.listen((event) {
      if ([
        'connection.ready',
        'chat.relationship.changed',
        'chat.settings.changed',
        'chat.group.changed',
        'chat.group.read',
      ].contains(event['eventType'])) {
        _load();
      }
    });
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _messages = [];
        _error = null;
      });
    }
    if (_invalid || !_foreground) return;
    try {
      final messages = await readChatHistoryContext(
        read: widget.read,
        messageId: widget.messageId,
        sequence: widget.sequence,
      );
      if (!mounted || generation != _generation) return;
      setState(() => _messages = messages);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _target.currentContext;
        if (mounted && generation == _generation && target != null) {
          Scrollable.ensureVisible(target, alignment: 0.35);
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = '暂时无法查看该消息，可能已清空或权限已变化');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    _events?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          LegacyMessagingHeader(
            title: '消息上下文',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: _error != null
                ? Center(
                    child: TextButton(
                      onPressed: _invalid ? null : _load,
                      child: Text(_error!),
                    ),
                  )
                : _messages.isEmpty
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                    child: Column(
                      children: [
                        for (final message in _messages)
                          Container(
                            key: message['messageId'] == widget.messageId
                                ? _target
                                : ValueKey(message['messageId']),
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: message['messageId'] == widget.messageId
                                  ? const Color(0x24C9B69E)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  message['sender'] == widget.account
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${message['sender']} · ${message['createdDate'] ?? ''}',
                                  style: const TextStyle(
                                    color: Color(0x888A8178),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: message['sender'] == widget.account
                                        ? const Color(0xFF95EC69)
                                        : const Color(0xFF202020),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    message['text'] as String? ?? '',
                                    style: TextStyle(
                                      color: message['sender'] == widget.account
                                          ? Colors.black
                                          : Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
