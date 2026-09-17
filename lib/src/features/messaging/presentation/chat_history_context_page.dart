import '../data/chat_history_access.dart';

import 'dart:async';

import '../../auth/domain/auth_repository.dart';
import '../data/chat_history_store.dart';

import '../data/chat_media_deletion.dart';
import '../data/chat_media_event_scope.dart';

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
    this.localConversation,
    this.readLocal,
    this.historyRemovals,
  });
  final ContextHistoryReader read;
  final String? localConversation;

  /// Account-scoped, matching the default local history store.
  final Stream<ConversationHistoryRemoval>? historyRemovals;
  final Future<List<Map<String, dynamic>>> Function()? readLocal;
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
  StreamSubscription<ConversationHistoryRemoval>? _historyRemovals;
  late final Future<void> _watchingHistory;
  void Function()? _stopDeletion;
  final _removedIds = <String>{};
  final _removedSequences = <int>{};
  int _hiddenThrough = 0;
  bool _invalid = false, _foreground = true;
  int _generation = 0;
  String? _error;
  ChatVoicePlayback? _voice;
  bool _openingCall = false;
  bool _localOnly = false;

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

  Future<void> _playVoice(Map<String, dynamic> message) async {
    final repository = widget.repository;
    if (_invalid || !_foreground || repository == null) return;
    final voice = _voice ??=
        ((widget.createVoicePlayback?.call() ?? ChatVoicePlayback())
          ..addListener(_voiceChanged));
    await voice.toggle(
      repository,
      message['messageId'] as String,
      group: widget.groupId != null,
      groupId: widget.groupId,
      conversationId: message['conversationId'] as String?,
      assetId: message['voiceAssetId'] as String?,
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
    final sentClient = message['sender'] == widget.account
        ? message['clientMessageId'] as String?
        : null;
    if (repository != null && id is String && id.isNotEmpty) {
      switch (message['messageType']) {
        case 'image':
          return GestureDetector(
            key: ValueKey('context-image-$id'),
            onTap: () => _open(
              _preview(
                ChatImageView(
                  sentClientMessageId: sentClient,
                  repository: repository,
                  scopeId:
                      widget.groupId ?? message['conversationId'] as String?,
                  messageId: id,
                  group: group,
                  full: true,
                ),
                '图片',
              ),
            ),
            child: ChatImageView(
              sentClientMessageId: sentClient,
              repository: repository,
              scopeId: widget.groupId ?? message['conversationId'] as String?,
              messageId: id,
              group: group,
            ),
          );
        case 'video':
          return ChatVideoView(
            sentClientMessageId: sentClient,
            key: ValueKey('context-video-$id'),
            scopeId: widget.groupId ?? message['conversationId'] as String?,
            repository: repository,
            messageId: id,
            group: group,
            width: message['videoWidth'] as int? ?? 320,
            height: message['videoHeight'] as int? ?? 240,
            durationMs: message['videoDurationMs'] as int? ?? 0,
            onTap: () => _open(
              _preview(
                ChatVideoView(
                  sentClientMessageId: sentClient,
                  repository: repository,
                  scopeId:
                      widget.groupId ?? message['conversationId'] as String?,
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
                    sender: message['sender'] as String?,
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
              onTap: () => _open(
                ChatLocationDetailsPage(
                  location: location,
                  source: ChatMediaDeletion(widget.account, group, id),
                ),
              ),
            );
          }
        case 'voice':
          final duration = message['voiceDurationMs'] as int? ?? 0;
          final active = _voice?.activeId == id;
          return TextButton.icon(
            key: ValueKey('context-voice-$id'),
            onPressed: () => _playVoice(message),
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
    _watchingHistory = _watchHistory();
    _stopDeletion = ChatMediaDeletion.listen((event) async {
      if (_invalid ||
          event.account != widget.account ||
          event.group != (widget.groupId != null)) {
        return;
      }
      _removedIds.add(event.messageId);
      if (event.messageId == widget.messageId) {
        _generation++;
        setState(() {
          _messages = [];
          _error = '原消息不可用';
        });
        await _voice?.stop();
      } else {
        setState(
          () => _messages.removeWhere(
            (message) => message['messageId'] == event.messageId,
          ),
        );
        if (_voice?.activeId == event.messageId) await _voice?.stop();
      }
    });
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
      if (affectsChatMedia(
        event,
        group: widget.groupId != null,
        scopeId: widget.groupId,
      )) {
        _load(background: type == 'chat.group.read');
      }
    });
    _load();
  }

  Future<void> _watchHistory() async {
    if (widget.localConversation == null) return;
    try {
      final stream =
          widget.historyRemovals ??
          (await ChatHistoryStore.open(widget.account)).clearedConversations;
      if (!mounted || _invalid) return;
      _historyRemovals = stream.listen((removal) async {
        if (_invalid || removal.conversation != widget.localConversation) {
          return;
        }
        if (removal.hiddenThrough > _hiddenThrough) {
          _hiddenThrough = removal.hiddenThrough;
        }
        _removedSequences.addAll(removal.sequences ?? const <int>{});
        bool removed(int sequence) =>
            removal.sequences == null ||
            sequence <= _hiddenThrough ||
            _removedSequences.contains(sequence);
        final ids = <String>{
          for (final message in _messages)
            if (removed(message['sequence'] as int))
              message['messageId'] as String,
          if (removed(widget.sequence)) widget.messageId,
        };
        _removedIds.addAll(ids);
        setState(() {
          if (ids.contains(widget.messageId)) {
            _generation++;
            _messages = [];
            _error = '原消息不可用';
          } else {
            _messages.removeWhere(
              (message) => ids.contains(message['messageId']),
            );
          }
        });
        if (ids.contains(widget.messageId) || ids.contains(_voice?.activeId)) {
          await _voice?.stop();
        }
        // Also invalidate a full-screen preview opened from an unsaved row.
        for (final id in ids) {
          await ChatMediaDeletion(
            widget.account,
            widget.groupId != null,
            id,
          ).dispatch();
        }
      });
    } catch (_) {
      // Keep normal remote read/error handling when local storage is unavailable.
    }
  }

  Future<void> _load({bool background = false}) async {
    if (_invalid || _removedIds.contains(widget.messageId)) return;
    if (!background) _voice?.stop();
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        if (!background) _messages = [];
        _error = null;
      });
    }
    if (_invalid || !_foreground) return;
    var remoteFinished = false;
    var positioned = false;
    try {
      await _watchingHistory;
      if (!mounted || _invalid || generation != _generation) return;
      void apply(List<Map<String, dynamic>> result, bool localOnly) {
        final messages = result
            .where(
              (message) =>
                  !_removedIds.contains(message['messageId']) &&
                  !_removedSequences.contains(message['sequence']) &&
                  (message['sequence'] as int) > _hiddenThrough,
            )
            .toList();
        final activeId = _voice?.activeId;
        if (activeId != null &&
            !messages.any(
              (message) =>
                  message['messageId'] == activeId &&
                  message['messageType'] == 'voice',
            )) {
          _voice?.stop();
        }
        setState(() {
          _messages = messages;
          _localOnly = localOnly;
        });
        if (background || positioned) return;
        positioned = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _target.currentContext;
          if (mounted && generation == _generation && target != null) {
            Scrollable.ensureVisible(target, alignment: 0.35);
          }
        });
      }

      Future<List<Map<String, dynamic>>> readLocal() async =>
          widget.readLocal != null
          ? await widget.readLocal!()
          : await (await ChatHistoryStore.open(widget.account)).context(
              widget.localConversation!,
              messageId: widget.messageId,
              sequence: widget.sequence,
            );
      Future<List<Map<String, dynamic>>>? cached;
      if (!background &&
          (widget.readLocal != null || widget.localConversation != null)) {
        cached = readLocal();
        unawaited(
          cached
              .then((rows) {
                if (!mounted ||
                    _invalid ||
                    generation != _generation ||
                    remoteFinished) {
                  return;
                }
                apply(rows, true);
              })
              .catchError((Object _) {}),
        );
      }
      List<Map<String, dynamic>> result;
      var localOnly = false;
      try {
        result = await readChatHistoryContext(
          read: widget.read,
          messageId: widget.messageId,
          sequence: widget.sequence,
        );
      } on AuthFailure catch (error) {
        if (error.code != 'NETWORK_ERROR' ||
            (widget.localConversation == null && widget.readLocal == null)) {
          rethrow;
        }
        result = await (cached ?? readLocal());
        localOnly = true;
      }
      if (!mounted || generation != _generation) return;
      remoteFinished = true;
      apply(result, localOnly);
    } catch (error) {
      remoteFinished = true;
      if (!mounted || generation != _generation) return;
      _voice?.stop();
      setState(() {
        _messages = [];
        _error = '暂时无法查看该消息，可能已清空或权限已变化';
      });
      if (widget.groupId != null) {
        try {
          await clearDeniedGroupHistory(
            error,
            account: widget.account,
            groupId: widget.groupId,
          );
        } catch (_) {
          // Keep the denied/error presentation even if local cleanup fails.
        }
      }
    } finally {
      remoteFinished = true;
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
    _historyRemovals?.cancel();
    _stopDeletion?.call();
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
          if (_localOnly && _error == null && _messages.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '当前显示本机已保存的记录',
                style: TextStyle(color: Color(0x88FFFFFF), fontSize: 12),
              ),
            ),
          Expanded(
            child: _error != null
                ? Center(
                    child: TextButton(
                      onPressed:
                          _invalid || _removedIds.contains(widget.messageId)
                          ? null
                          : _load,
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
