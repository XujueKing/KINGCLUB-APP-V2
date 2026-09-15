import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/chat_history_context.dart';
import 'legacy_messaging_components.dart';
import 'chat_timestamp.dart';
import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_notice.dart';
import '../data/messaging_repository.dart';
import '../data/chat_voice_playback.dart';
import '../data/chat_file_downloader.dart';
import '../data/chat_location.dart';
import '../data/chat_call_history.dart';
import '../data/call_repository.dart';
import 'chat_image_view.dart';
import 'chat_video_view.dart';
import 'chat_file_card.dart';
import 'chat_file_details_page.dart';
import 'chat_location_message.dart';

class ChatHistoryContextPage extends StatefulWidget {
  const ChatHistoryContextPage({
    super.key,
    required this.read,
    required this.messageId,
    required this.sequence,
    required this.account,
    this.senderLabel,
    this.repository,
    this.groupId,
    this.events,
    this.createVoicePlayback,
    this.onCall,
  });
  final ContextHistoryReader read;
  final String messageId, account;
  final String Function(String account)? senderLabel;
  final int sequence;
  final MessagingRepository? repository;
  final String? groupId;
  final Stream<Map<String, dynamic>>? events;
  final ChatVoicePlayback Function()? createVoicePlayback;
  final Future<void> Function(CallMedia media)? onCall;
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
  ChatVoicePlayback? _voice;
  bool _openingCall = false;

  Future<void> _call(CallMedia media) async {
    if (_invalid || !_foreground || _openingCall || widget.onCall == null) {
      return;
    }
    _openingCall = true;
    try {
      await _voice?.stop();
      if (!mounted || _invalid || !_foreground) return;
      await widget.onCall!(media);
    } catch (_) {
      if (mounted && !_invalid) KingNotice.of(context).show('暂时无法发起通话，请重试');
    } finally {
      _openingCall = false;
    }
  }

  void _voiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _playVoice(String id) async {
    final repository = widget.repository;
    if (_invalid || !_foreground || repository == null) return;
    final voice = _voice ??=
        ((widget.createVoicePlayback?.call() ?? ChatVoicePlayback())
          ..addListener(_voiceChanged));
    await voice.toggle(
      repository,
      id,
      group: widget.groupId != null,
      groupId: widget.groupId,
    );
    if (mounted && voice.error != null) {
      KingNotice.of(context).show(voice.error!);
    }
  }

  void _open(Widget page) {
    if (_invalid || !_foreground) return;
    _voice?.stop();
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  Widget _preview(Widget content, String title) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      title: Text(title),
      leading: KingBackButton(onPressed: () => Navigator.of(context).pop()),
    ),
    body: SafeArea(child: Center(child: content)),
  );

  Widget _content(Map<String, dynamic> message) {
    final call =
        widget.groupId == null &&
            (message['messageType'] == 'text' || message['messageType'] == null)
        ? ChatCallHistory.tryParse(message['call'])
        : null;
    if (call != null) {
      return TextButton.icon(
        key: ValueKey('context-call-${call.id}'),
        style: TextButton.styleFrom(
          foregroundColor: message['sender'] == widget.account
              ? const Color(0xFF222222)
              : legacyMessageGold,
          textStyle: legacyChatBodyTextStyle,
          iconSize: 20,
        ),
        onPressed: widget.onCall == null ? null : () => _call(call.media),
        icon: Icon(call.media == CallMedia.audio ? Icons.call : Icons.videocam),
        label: Text(
          call.displayText(outgoing: message['sender'] == widget.account),
        ),
      );
    }
    final repository = widget.repository;
    final id = message['messageId'];
    final group = widget.groupId != null;
    if (repository != null && id is String && id.isNotEmpty) {
      switch (message['messageType']) {
        case 'image':
          return GestureDetector(
            key: ValueKey('context-image-$id'),
            onTap: () => _open(
              _preview(
                ChatImageView(
                  repository: repository,
                  messageId: id,
                  group: group,
                  full: true,
                ),
                '图片',
              ),
            ),
            child: ChatImageView(
              repository: repository,
              messageId: id,
              group: group,
            ),
          );
        case 'video':
          return ChatVideoView(
            key: ValueKey('context-video-$id'),
            repository: repository,
            messageId: id,
            group: group,
            width: message['videoWidth'] as int? ?? 320,
            height: message['videoHeight'] as int? ?? 240,
            durationMs: message['videoDurationMs'] as int? ?? 0,
            onTap: () => _open(
              _preview(
                ChatVideoView(
                  repository: repository,
                  messageId: id,
                  group: group,
                  full: true,
                ),
                '视频',
              ),
            ),
          );
        case 'file':
          if (message['fileName'] is String &&
              message['fileSize'] is int &&
              message['fileAssetId'] is String &&
              message['fileSha256'] is String) {
            return ChatFileCard(
              fileName: message['fileName'] as String,
              size: message['fileSize'] as int,
              onTap: () => _open(
                ChatFileDetailsPage(
                  repository: repository,
                  reference: ChatFileReference(
                    messageId: id,
                    assetId: message['fileAssetId'] as String,
                    fileName: message['fileName'] as String,
                    size: message['fileSize'] as int,
                    sha256: message['fileSha256'] as String,
                    group: group,
                  ),
                ),
              ),
            );
          }
        case 'location':
          final location = ChatLocation.tryParse(message['location']);
          if (location != null) {
            return ChatLocationMessage(
              location: location,
              mine: message['sender'] == widget.account,
              onTap: () => _open(ChatLocationDetailsPage(location: location)),
            );
          }
        case 'voice':
          final duration = message['voiceDurationMs'] as int? ?? 0;
          final active = _voice?.activeId == id;
          return TextButton.icon(
            key: ValueKey('context-voice-$id'),
            onPressed: () => _playVoice(id),
            icon: Icon(active ? Icons.stop : Icons.volume_up),
            label: Text(
              active
                  ? (_voice!.loading ? '正在加载…' : '点击停止')
                  : '播放语音 ${(duration / 1000).ceil()}秒',
            ),
          );
      }
    }
    return SelectableText(
      message['text'] as String? ?? '',
      style: TextStyle(
        color: message['sender'] == widget.account
            ? Colors.black
            : Colors.white,
        fontSize: 16,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _voice?.stop();
      _generation++;
      if (mounted) {
        setState(() {
          _messages = [];
          _error = '登录状态已变化';
        });
      }
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      final type = event['eventType'];
      if (type == 'chat.group.read' || type == 'chat.group.changed') {
        final data = event['data'];
        final groupId = data is Map ? data['groupId'] : null;
        if (widget.groupId == null ||
            (groupId is String &&
                groupId.isNotEmpty &&
                groupId != widget.groupId)) {
          return;
        }
      }
      if ([
        'connection.ready',
        'chat.relationship.changed',
        'chat.settings.changed',
        'chat.group.changed',
        'chat.group.read',
      ].contains(event['eventType'])) {
        _load(background: type == 'chat.group.read');
      }
    });
    _load();
  }

  Future<void> _load({bool background = false}) async {
    if (_invalid) return;
    if (!background) _voice?.stop();
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        if (!background) _messages = [];
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
      final activeId = _voice?.activeId;
      if (activeId != null &&
          !messages.any(
            (message) =>
                message['messageId'] == activeId &&
                message['messageType'] == 'voice',
          )) {
        _voice?.stop();
      }
      setState(() => _messages = messages);
      if (background) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _target.currentContext;
        if (mounted && generation == _generation && target != null) {
          Scrollable.ensureVisible(target, alignment: 0.35);
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _voice?.stop();
      setState(() {
        _messages = [];
        _error = '暂时无法查看该消息，可能已清空或权限已变化';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _load();
  }

  @override
  void dispose() {
    _voice?.removeListener(_voiceChanged);
    _voice?.dispose();
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
                                  [
                                        widget.senderLabel?.call(
                                              message['sender']?.toString() ??
                                                  '',
                                            ) ??
                                            message['sender']?.toString() ??
                                            '',
                                        ?chatTimestampLabel(
                                          message['createdDate']?.toString(),
                                          null,
                                        ),
                                      ]
                                      .where((part) => part.isNotEmpty)
                                      .join(' · '),
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
                                  child: _content(message),
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
