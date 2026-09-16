import '../data/chat_outbox_recovery.dart';
import '../data/chat_call_history.dart';
import 'chat_timestamp.dart';
import '../data/call_presentation_lease.dart';
import 'message_voice_transcription_page.dart';
import 'voice_transcription_page.dart';
import 'chat_video_view.dart';
import 'chat_video_send_page.dart';
import '../data/chat_reply.dart';
import 'chat_history_context_page.dart';
import 'forward_text_page.dart';
import '../data/chat_file_draft_store.dart';
import '../data/chat_text_draft_store.dart';
import 'chat_file_details_page.dart';
import '../data/chat_file_downloader.dart';
import 'chat_file_card.dart';

import 'package:file_picker/file_picker.dart';

import 'chat_file_send_page.dart';
import '../data/call_launch_coordinator.dart';
import '../data/call_repository.dart';
import 'group_call_page.dart';
import 'call_page.dart';
import 'chat_member_avatar.dart';
import '../data/chat_history_store.dart';
import '../data/novorudp_binding_runtime.dart';
import 'chat_location_message.dart';
import '../data/chat_location.dart';
import 'chat_location_picker_page.dart';
import '../data/chat_voice_playback.dart';
import '../data/voice_draft_sender.dart';
import '../../../core/design_system/king_components.dart';
import 'chat_image_view.dart';

import 'package:image_picker/image_picker.dart';

import 'chat_image_send_page.dart';
import '../data/chat_session_controller.dart';
import '../data/group_chat_controller.dart';
import '../data/group_chat_repository.dart';
import 'group_details_page.dart';
import '../../contacts/presentation/public_member_page.dart';
import '../data/messaging_repository.dart';
import '../data/direct_chat_controller.dart';
import '../data/chat_outbox.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/voice_capture.dart';
import 'voice_draft_preview.dart';

import 'dart:io';

import 'chat_emoji_panel.dart';
import 'voice_hold_overlay.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:kingclub/src/core/design_system/king_notice.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

import 'contact_selector_page.dart';
import 'direct_chat_details_page.dart';
import 'legacy_messaging_components.dart';

enum _FakeMessageStatus { queued, sending, sent, failed }

enum _FakeMessageKind {
  text,
  image,
  video,
  businessCard,
  goldCoin,
  redPacket,
  gift,
}

enum _ComposerPanel { none, attachments, gifts, emoji }

enum _FakeMessageAction { copy, quote, forward, delete, recall, transcribe }

const _giftItems = <_GiftItem>[
  _GiftItem(
    id: 0,
    name: '星光玫瑰',
    price: 599,
    category: 2,
    assetPath: 'assets/legacy/messaging/gift_rose.png',
  ),
  _GiftItem(
    id: 1,
    name: '冲刺狂王',
    price: 1200,
    category: 1,
    assetPath: 'assets/legacy/messaging/gift_racer.png',
  ),
  _GiftItem(
    id: 2,
    name: '变形战车',
    price: 2999,
    category: 1,
    assetPath: 'assets/legacy/messaging/gift_transformer.png',
  ),
  _GiftItem(
    id: 3,
    name: '嘉年华',
    price: 30000,
    category: 1,
    assetPath: 'assets/legacy/messaging/gift_anniversary.png',
  ),
  _GiftItem(
    id: 4,
    name: '夏日度假',
    price: 999,
    category: 3,
    assetPath: 'assets/legacy/messaging/gift_flamingo.png',
  ),
  _GiftItem(
    id: 5,
    name: '天鹅之梦',
    price: 50,
    category: 2,
    assetPath: 'assets/legacy/messaging/gift_swan.png',
  ),
  _GiftItem(
    id: 6,
    name: '天鹅公主',
    price: 999,
    category: 2,
    assetPath: 'assets/legacy/messaging/gift_princess.png',
  ),
  _GiftItem(
    id: 7,
    name: '太空之镜',
    price: 6399,
    category: 3,
    assetPath: 'assets/legacy/messaging/gift_horse.png',
  ),
];

class _GiftItem {
  const _GiftItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.assetPath,
  });

  final int id;
  final String name;
  final int price;
  final int category;
  final String assetPath;
}

class DirectChatPage extends StatefulWidget {
  const DirectChatPage({
    super.key,
    this.peerName = '卡座搭子',
    this.initialMuted = false,
    this.onMutedChanged,
    this.voiceCapture,
    this.peerAccount,
    this.groupId,
    this.repository,
    this.openRepository,
    this.chatOutbox,
    this.openTextDraftStore,
  }) : assert(peerAccount == null || groupId == null);

  final String? peerAccount;
  final String? groupId;
  final MessagingRepository? repository;
  final Future<MessagingRepository> Function()? openRepository;
  final ChatOutbox? chatOutbox;
  final Future<ChatTextDraftStore> Function(String account, String target)?
  openTextDraftStore;
  final VoiceCapture? voiceCapture;
  final String peerName;
  final bool initialMuted;
  final ValueChanged<bool>? onMutedChanged;

  @override
  State<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<DirectChatPage>
    with WidgetsBindingObserver {
  ChatSessionController? _chat;
  int _connectionGeneration = 0;
  String? _conversationAccount;
  String _connectionNotice = '正在连接会话…';
  CallLaunchCoordinator? _callLauncher;
  bool _openingCall = false, _choosingCall = false;
  String? get _realTarget => widget.groupId ?? widget.peerAccount;
  StreamSubscription<Map<String, dynamic>>? _chatEvents;
  final _avatarProfiles = <String, Future<Map<String, dynamic>>>{};
  String? _peerNickname;
  StreamSubscription<String>? _remarkEvents;

  String get _displayPeerName {
    if (widget.groupId != null) {
      return _chat?.settings['groupName'] as String? ?? widget.peerName;
    }
    final remark = (_chat?.settings['remark'] as String?)?.trim();
    if (remark != null && remark.isNotEmpty) return remark;
    return _peerNickname ?? widget.peerName;
  }

  Future<void> _refreshPeerNickname(ChatSessionController chat) async {
    final peer = widget.peerAccount;
    if (widget.groupId != null || peer == null) return;
    try {
      final profile = await cachedChatAvatarProfile(
        _avatarProfiles,
        peer,
        () => chat.messaging.avatarProfile(peer),
      );
      if (!mounted || !identical(chat, _chat)) return;
      final nickname = (profile['nickname'] as String?)?.trim();
      if (nickname != null && nickname.isNotEmpty) {
        setState(() => _peerNickname = nickname);
      }
    } catch (_) {}
  }

  StreamSubscription<void>? _sessionEvents;
  bool _loadingOlder = false;
  bool _selectingImage = false;
  VoiceCapture? _capture;
  bool _leaving = false;
  int _voiceSession = 0;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();
  bool _scrollScheduled = false;
  final _animatedMessageIds = <String>{};
  _ComposerPanel _composerPanel = _ComposerPanel.none;
  bool _voiceMode = false;
  bool _voiceInputToText = false;
  bool _heldInputToText = false;
  OverlayEntry? _voiceOverlay;
  final _voiceTarget = ValueNotifier(VoiceHoldTarget.send);
  Offset? _voiceStart;

  void _beginVoiceHold(PointerDownEvent details) {
    _voicePlayback?.stop();
    if (_readOnly) return;
    _capture ??= widget.voiceCapture ?? VoiceCapture.native();
    if (!_capture!.begin(
      onLimit: _endVoiceHold,
      onInterrupted: _endVoiceHold,
    )) {
      return;
    }
    _heldInputToText = _voiceInputToText;
    _voiceStart = details.position;
    _voiceTarget.value = VoiceHoldTarget.send;
    _voiceOverlay?.remove();
    _voiceOverlay = OverlayEntry(
      builder: (_) =>
          VoiceHoldOverlay(target: _voiceTarget, sendAsText: _heldInputToText),
    );
    Overlay.of(context, rootOverlay: true).insert(_voiceOverlay!);
  }

  void _moveVoiceHold(PointerMoveEvent details) {
    final dy = details.position.dy - (_voiceStart?.dy ?? details.position.dy);
    _voiceTarget.value = dy < -60
        ? (details.position.dx < MediaQuery.sizeOf(context).width / 2
              ? VoiceHoldTarget.cancel
              : VoiceHoldTarget.text)
        : VoiceHoldTarget.send;
  }

  void _endVoiceHold({bool interrupted = false}) {
    if (_voiceOverlay == null) return;
    final target =
        _heldInputToText && _voiceTarget.value == VoiceHoldTarget.send
        ? VoiceHoldTarget.text
        : _voiceTarget.value;
    _voiceOverlay?.remove();
    _voiceOverlay = null;
    _voiceStart = null;
    _finishRecording(interrupted || target == VoiceHoldTarget.cancel, target);
  }

  Widget _voiceBubble(_FakeMessage message) {
    final playback = _voicePlayback ??= ChatVoicePlayback();
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final active =
            message.messageId != null && playback.activeId == message.messageId;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: message.messageId == null || _chat == null
              ? null
              : () async {
                  await playback.toggle(
                    _chat!.messaging,
                    message.messageId!,
                    group: widget.groupId != null,
                    groupId: widget.groupId,
                    conversationId: _chat!.conversationId,
                    assetId: message.voiceAssetId,
                  );
                  if (context.mounted && playback.error != null) {
                    KingNotice.of(context).show(playback.error!);
                  }
                },
          child: SizedBox(
            width: (74 + (message.voiceDurationMs! / 1000) * 2)
                .clamp(76, 190)
                .toDouble(),
            child: Row(
              mainAxisAlignment: message.mine
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  active
                      ? (playback.loading
                            ? Icons.more_horiz
                            : Icons.stop_rounded)
                      : Icons.volume_up_rounded,
                  size: 22,
                  color: message.mine
                      ? const Color(0xFF174A2C)
                      : const Color(0xFFC9B69E),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(message.voiceDurationMs! / 1000).ceil()}″',
                  style: TextStyle(
                    fontSize: 16,
                    color: message.mine
                        ? const Color(0xFF111111)
                        : const Color(0xFFC9B69E),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  final _voiceSender = VoiceDraftSender();
  ChatVoicePlayback? _voicePlayback;

  Future<void> _finishRecording(bool cancel, VoiceHoldTarget target) async {
    final session = _voiceSession;
    try {
      final draft = await _capture?.finish(cancel: cancel);
      if (!mounted || _leaving || draft == null || session != _voiceSession) {
        return;
      }
      final chat = _chat;
      if (target != VoiceHoldTarget.text && chat != null) {
        try {
          await _voiceSender.send(chat, draft);
          return;
        } catch (_) {
          if (!mounted || _leaving || session != _voiceSession) return;
          KingNotice.of(context).show('语音发送未完成，录音已保留');
        }
      }
      if (!mounted || _leaving || session != _voiceSession) return;
      if (target == VoiceHoldTarget.text && chat != null) {
        final text = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => VoiceTranscriptionPage(
              draft: draft,
              repository: chat.messaging,
            ),
          ),
        );
        if (!mounted ||
            _leaving ||
            session != _voiceSession ||
            !identical(chat, _chat)) {
          return;
        }
        if (text != null && text.isNotEmpty) {
          setState(() {
            _controller.text = _controller.text.isEmpty
                ? text
                : '${_controller.text}\n$text';
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
            _voiceMode = false;
          });
          _inputFocusNode.requestFocus();
        }
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: legacyMessagePanel,
        showDragHandle: true,
        builder: (_) => VoiceDraftPreview(
          draft: draft,
          onSend: chat == null ? null : () => _voiceSender.send(chat, draft),
        ),
      );
    } catch (error) {
      if (mounted && !_leaving && !cancel) {
        KingNotice.of(context)
            .show(error is StateError ? error.message.toString() : '录音失败，请重试');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_flushTextDraft());
    if (state != AppLifecycleState.resumed) _endVoiceHold(interrupted: true);
    if (state == AppLifecycleState.resumed) {
      _chat?.synchronize().then((_) => _chat?.retryQueued());
    }
  }

  int _attachmentPage = 0;
  int _giftCategory = 0;
  int? _selectedGift;
  int _goldBalance = 501;
  String? _quotedDraft;
  String? _quotedMessageId;
  ChatTextDraftStore? _textDrafts;
  ChatTextDraft? _textDraft;
  Timer? _textDraftTimer;
  int _textDraftRevision = 0;
  bool _restoringTextDraft = false;

  void _captureTextDraft() {
    if (_realTarget == null || _restoringTextDraft) return;
    final text = _controller.text;
    if (_textDraft?.text == text &&
        _textDraft?.replyTo == _quotedMessageId &&
        _textDraft?.preview == _quotedDraft) {
      return;
    }
    _textDraftRevision++;
    _textDraft = ChatTextDraft(
      text,
      replyTo: _quotedMessageId,
      preview: _quotedDraft,
    );
    _textDraftTimer?.cancel();
    _textDraftTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_flushTextDraft()),
    );
  }

  Future<void> _flushTextDraft() async {
    _textDraftTimer?.cancel();
    final store = _textDrafts, draft = _textDraft;
    if (store == null) return;
    try {
      await store.write(draft);
    } catch (_) {
      if (mounted && identical(store, _textDrafts)) {
        KingNotice.of(context).show('草稿暂未保存，请稍后重试');
      }
    }
  }

  Future<void> _loadTextDraft(
    MessagingRepository repository,
    int generation,
  ) async {
    final revision = _textDraftRevision;
    try {
      final store =
          await (widget.openTextDraftStore ?? ChatTextDraftStore.open)(
            repository.account,
            widget.groupId != null
                ? 'group:${widget.groupId}'
                : 'peer:${widget.peerAccount}',
          );
      final draft = await store.read();
      if (!mounted || generation != _connectionGeneration) return;
      _textDrafts = store;
      if (revision == _textDraftRevision &&
          _controller.text.isEmpty &&
          draft != null) {
        _restoringTextDraft = true;
        setState(() {
          _textDraft = draft;
          _quotedDraft = draft.preview;
          _quotedMessageId = draft.replyTo;
          _controller.value = TextEditingValue(
            text: draft.text,
            selection: TextSelection.collapsed(offset: draft.text.length),
          );
        });
        _restoringTextDraft = false;
      } else if (_textDraft != null) {
        await _flushTextDraft();
      }
    } catch (_) {
      // Chat remains usable if the local draft cannot be restored.
    }
  }

  bool get _readOnly =>
      (_realTarget != null && _chat == null) ||
      (_chat is GroupChatController &&
          (_chat as GroupChatController).sendMuted);
  late final List<_FakeMessage> _messages = _realTarget != null
      ? []
      : [
          _FakeMessage(
            '你已添加了${widget.peerName}，现在可以开始聊天了。',
            mine: false,
            system: true,
          ),
          const _FakeMessage('周末 KING CLUB 见？', mine: false),
          const _FakeMessage('好，晚上九点。', mine: true),
          const _FakeMessage('A6 卡座见', mine: false, quoted: '好，晚上九点。'),
        ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muted = widget.initialMuted;
    _inputFocusNode.addListener(_handleInputFocusChanged);
    _controller.addListener(_captureTextDraft);
    if (_realTarget != null) {
      _sessionEvents = SecureSessionStore.changes.stream.listen(
        (_) => _rebindChatSession(),
      );
      _scrollController.addListener(_onRealScroll);
      _connectRealChat();
    }
  }

  void Function()? _releaseOutboxRecovery;

  Future<void> _connectRealChat({MessagingRepository? renewed}) async {
    final generation = ++_connectionGeneration;
    try {
      final repository =
          renewed ??
          widget.repository ??
          await (widget.openRepository ?? MessagingRepository.open)();
      if (!mounted || generation != _connectionGeneration) return;
      _conversationAccount ??= repository.account;
      if (repository.persistHistory || widget.openTextDraftStore != null) {
        unawaited(_loadTextDraft(repository, generation));
      }
      _releaseOutboxRecovery?.call();
      _releaseOutboxRecovery = ChatOutboxRecovery.hold(
        repository.account,
        widget.groupId ?? widget.peerAccount!,
        widget.groupId != null,
      );
      final outbox = widget.chatOutbox ?? SecureChatOutbox(repository.account);
      final ChatSessionController chat = widget.groupId != null
          ? GroupChatController(
              repository: GroupChatRepository(repository),
              groupId: widget.groupId!,
              outbox: outbox,
              openHistory: repository.persistHistory
                  ? () => ChatHistoryStore.open(repository.account)
                  : null,
            )
          : DirectChatController(
              repository: repository,
              peer: widget.peerAccount!,
              outbox: outbox,
              markRelayRead: repository.persistHistory
                  ? NovoRudpBindingRuntime.textReadMarker(
                      repository.account,
                      widget.peerAccount!,
                    )
                  : null,
              sendRelayText: repository.persistHistory
                  ? NovoRudpBindingRuntime.textSender(
                      repository.account,
                      widget.peerAccount!,
                    )
                  : null,
              preferRelayText: () =>
                  repository.persistHistory &&
                  NovoRudpBindingRuntime.relay?.connection != null,
              readRelayMessages: repository.persistHistory
                  ? NovoRudpBindingRuntime.textReader(
                      repository.account,
                      widget.peerAccount!,
                    )
                  : null,
              relayChanges: repository.persistHistory
                  ? NovoRudpBindingRuntime.textChanges(repository.account)
                  : null,
              openHistory: repository.persistHistory
                  ? () => ChatHistoryStore.open(repository.account)
                  : null,
            );
      _chat = chat;
      _remarkEvents?.cancel();
      _remarkEvents = MessagingRepository.remarkChanges(repository.account)
          .listen((peer) {
            if (mounted &&
                identical(chat, _chat) &&
                widget.groupId == null &&
                peer == widget.peerAccount) {
              unawaited(chat.synchronize());
            }
          });
      chat.addListener(_realChatChanged);
      unawaited(_refreshPeerNickname(chat));
      _chatEvents = KingclubRealtime.shared.events.listen((event) {
        final type = event['eventType'] as String? ?? '';
        final data = event['data'];
        if (type == 'connection.ready' ||
            type == 'chat.friend-request.changed' ||
            type == 'chat.group.changed' ||
            type == 'chat.relationship.changed') {
          if (mounted) setState(_avatarProfiles.clear);
          unawaited(_refreshPeerNickname(chat));
        }
        if (type == 'connection.ready' && chat is GroupChatController) {
          chat.invalidateMemberNames();
        }
        if (chat is GroupChatController && type == 'chat.group.changed') {
          chat.refreshGroup();
          return;
        }
        if (type == 'connection.ready' ||
            (type.startsWith('chat.') &&
                (chat.conversationId == null ||
                    data is Map &&
                        data[widget.groupId == null
                                ? 'conversationId'
                                : 'groupId'] ==
                            chat.conversationId))) {
          chat.synchronize().then((_) => chat.retryQueued());
        }
      });
      await chat.initialize();
      if (mounted &&
          generation == _connectionGeneration &&
          chat.error != null) {
        KingNotice.of(context).show(chat.error!);
      }
    } catch (error) {
      if (mounted && generation == _connectionGeneration) {
        setState(() => _connectionNotice = '会话连接失败，请返回重试');
        KingNotice.of(context).show(error.toString());
      }
    }
  }

  Future<void> _rebindChatSession() async {
    _remarkEvents?.cancel();
    _textDraftTimer?.cancel();
    _textDrafts = null;
    final generation = ++_connectionGeneration;
    _callLauncher?.close();
    _callLauncher = null;
    _voiceSession++;
    _endVoiceHold(interrupted: true);
    _voicePlayback?.dispose();
    _voicePlayback = null;
    _chatEvents?.cancel();
    _chat?.removeListener(_realChatChanged);
    _chat?.dispose();
    _releaseOutboxRecovery?.call();
    _releaseOutboxRecovery = null;
    _chat = null;
    _peerNickname = null;
    _avatarProfiles.clear();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _quotedDraft = null;
      _quotedMessageId = null;
      _connectionNotice = '正在恢复会话…';
    });
    try {
      final session = await SecureSessionStore().readSession();
      if (!mounted || generation != _connectionGeneration) return;
      final account = (session?['account'] as Map?)?['userAccount'];
      if (account == null || account != _conversationAccount) {
        _controller.clear();
        setState(() => _connectionNotice = '登录状态已变化，请重新进入会话');
        return;
      }
      final repository =
          await (widget.openRepository ?? MessagingRepository.open)();
      if (!mounted || generation != _connectionGeneration) return;
      if (repository.account != _conversationAccount) return;
      await _connectRealChat(renewed: repository);
    } catch (_) {
      if (mounted && generation == _connectionGeneration) {
        setState(() => _connectionNotice = '会话连接失败，请返回重试');
      }
    }
  }

  Future<void> _chooseCallType() async {
    if (_openingCall || _choosingCall || _leaving) return;
    _choosingCall = true;
    try {
      final media = await showModalBottomSheet<CallMedia>(
        context: context,
        backgroundColor: legacyActionMenuBackground,
        builder: (sheetContext) => LegacyActionMenuStyle(
          child: SafeArea(
            child: Wrap(
              children: [
                for (final type in CallMedia.values)
                  ListTile(
                    key: ValueKey('call-type-${type.name}'),
                    leading: Icon(
                      type == CallMedia.audio ? Icons.call : Icons.videocam,
                    ),
                    title: Text(type == CallMedia.audio ? '语音通话' : '视频通话'),
                    onTap: () => Navigator.pop(sheetContext, type),
                  ),
                ListTile(
                  title: const Text('取消'),
                  onTap: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted && !_leaving && media != null) await _openCall(media);
    } finally {
      _choosingCall = false;
    }
  }

  Future<void> _openCall(CallMedia media) async {
    if (_openingCall || _leaving) return;
    final lease = CallPresentationLease.acquire();
    if (lease == null) return;
    try {
      await _openExclusiveCall(media);
    } finally {
      lease.release();
    }
  }

  Future<void> _openExclusiveCall(CallMedia media) async {
    if (_openingCall || _leaving) return;
    final chat = _chat;
    final peer = widget.peerAccount;
    if (widget.groupId != null) {
      if (chat == null) return;
      _openingCall = true;
      _dismissComposer();
      try {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => GroupCallPage(
              repository: GroupChatRepository(chat.messaging),
              groupId: widget.groupId!,
              media: media,
            ),
          ),
        );
      } finally {
        _openingCall = false;
      }
      return;
    }
    if (chat == null || peer == null) {
      KingNotice.of(context).show('请在已连接的好友会话中发起通话');
      return;
    }
    _openingCall = true;
    _dismissComposer();
    final launcher = _callLauncher ??= CallLaunchCoordinator(
      CallRepository(chat.messaging),
    );
    try {
      final prepared = await launcher.outgoing(peer: peer, media: media);
      if (!mounted || _leaving || !identical(_callLauncher, launcher)) return;
      final page = CallPage.native(
        repository: launcher.repository,
        initial: prepared.call,
        peerName: _displayPeerName,
        relay: prepared.relay,
        outgoingAttempt: prepared.outgoingAttempt,
      );
      // A completed setup must not open the camera behind another page or
      // after this app has moved to the background.
      if (ModalRoute.of(context)?.isCurrent != true ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        try {
          await page.controller.end();
        } finally {
          page.controller.dispose();
        }
      } else {
        await Navigator.of(context)
            .push<void>(MaterialPageRoute(builder: (_) => page));
      }
      if (!mounted || _leaving || !identical(_callLauncher, launcher)) return;
      await launcher.finishOutgoing(prepared.call.id);
    } catch (error) {
      if (mounted && !_leaving && identical(_callLauncher, launcher)) {
        KingNotice.of(context).show('通话未能完成：$error');
      }
    } finally {
      _openingCall = false;
    }
  }

  void _realChatChanged() {
    final chat = _chat;
    if (!mounted || chat == null) return;
    final nearBottom =
        !_scrollController.hasClients ||
        _scrollController.position.extentBefore < 48;
    final displayedIds = _messages
        .map((message) => message.clientMessageId)
        .toSet();
    final hasNewOutgoing = chat.messages.any(
      (message) =>
          message['sender'] == chat.messaging.account &&
          (message['status'] == 'queued' || message['status'] == 'sending') &&
          !displayedIds.contains(message['clientMessageId']),
    );
    if (_messages.isNotEmpty &&
        !_loadingOlder &&
        (nearBottom || hasNewOutgoing)) {
      _animatedMessageIds.addAll(
        chat.messages
            .map((message) => message['clientMessageId'])
            .whereType<String>()
            .where((id) => !displayedIds.contains(id)),
      );
    }
    final activeVoice = _voicePlayback?.activeId;
    if (activeVoice != null &&
        !chat.messages.any(
          (m) => m['messageId'] == activeVoice && m['messageType'] == 'voice',
        )) {
      _voicePlayback?.stop();
    }
    setState(() {
      _messages
        ..clear()
        ..addAll(
          chat.messages.map(
            (message) => _FakeMessage(
              message['text'] as String,
              messageId: message['messageId'] as String?,
              system: message['messageType'] == 'recalled',
              quoted: ChatReply.tryParse(message['reply'])?.text,
              reply: ChatReply.tryParse(message['reply']),
              call:
                  widget.groupId == null &&
                      (message['messageType'] == null ||
                          message['messageType'] == 'text')
                  ? ChatCallHistory.tryParse(message['call'])
                  : null,
              fileName: message['messageType'] == 'file'
                  ? message['fileName'] as String?
                  : null,
              fileAssetId: message['fileAssetId'] as String?,
              fileSha256: message['fileSha256'] as String?,
              fileSize: message['messageType'] == 'file'
                  ? message['fileSize'] as int?
                  : null,
              videoDurationMs: message['messageType'] == 'video'
                  ? message['videoDurationMs'] as int?
                  : null,
              videoWidth: message['videoWidth'] as int?,
              videoHeight: message['videoHeight'] as int?,
              voiceDurationMs: message['messageType'] == 'voice'
                  ? message['voiceDurationMs'] as int?
                  : null,
              voiceAssetId: message['voiceAssetId'] as String?,
              location: message['messageType'] == 'location'
                  ? ChatLocation.tryParse(message['location'])
                  : null,
              kind: message['messageType'] == 'image'
                  ? _FakeMessageKind.image
                  : _FakeMessageKind.text,
              mine: message['sender'] == chat.messaging.account,
              senderAccount: message['sender'] as String?,
              senderName: widget.groupId == null
                  ? null
                  : message['senderName'] as String?,
              clientMessageId: message['clientMessageId'] as String,
              createdDate: message['createdDate'] as String?,
              receiptLabel:
                  widget.groupId == null &&
                      message['sender'] == chat.messaging.account
                  ? (message['peerRead'] == true
                        ? '已读'
                        : message['peerDelivered'] == true
                        ? '已送达'
                        : null)
                  : null,
              status: switch (message['status']) {
                'queued' => _FakeMessageStatus.queued,
                'sent' => _FakeMessageStatus.sent,
                'sending' => _FakeMessageStatus.sending,
                _ => _FakeMessageStatus.failed,
              },
            ),
          ),
        );
      _muted = chat.settings['muted'] == true;
    });
    if (nearBottom || hasNewOutgoing) _scrollToLatest();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRealRead());
  }

  void _markRealRead() {
    final chat = _chat;
    if (!mounted ||
        chat == null ||
        ModalRoute.of(context)?.isCurrent != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        !_scrollController.hasClients ||
        _scrollController.position.extentBefore > 24) {
      return;
    }
    final confirmed = chat.messages.where(
      (message) => message['sequence'] is num,
    );
    if (chat is DirectChatController) unawaited(chat.markRelayVisibleRead());
    if (confirmed.isNotEmpty) {
      chat.markVisibleRead((confirmed.last['sequence'] as num).toInt());
    }
  }

  void _onRealScroll() {
    _markRealRead();
    final chat = _chat;
    if (chat == null ||
        _loadingOlder ||
        !chat.hasOlder ||
        _scrollController.position.extentAfter > 32) {
      return;
    }
    _loadingOlder = true;
    chat.loadOlder().whenComplete(() {
      _loadingOlder = false;
    });
  }

  void _dismissComposer() {
    _inputFocusNode.unfocus();
    if (_composerPanel != _ComposerPanel.none) {
      setState(() => _composerPanel = _ComposerPanel.none);
    }
  }

  @override
  void dispose() {
    _remarkEvents?.cancel();
    unawaited(_flushTextDraft());
    _controller.removeListener(_captureTextDraft);
    _leaving = true;
    _connectionGeneration++;
    unawaited(_callLauncher?.abandonOutgoing().catchError((Object _) {}));
    _chatEvents?.cancel();
    _sessionEvents?.cancel();
    _voiceSender.dispose();
    _voicePlayback?.dispose();
    _chat?.removeListener(_realChatChanged);
    _chat?.dispose();
    _releaseOutboxRecovery?.call();
    _releaseOutboxRecovery = null;
    WidgetsBinding.instance.removeObserver(this);
    _endVoiceHold(interrupted: true);
    _capture?.dispose().catchError((Object _) {});
    _voiceTarget.dispose();
    _inputFocusNode
      ..removeListener(_handleInputFocusChanged)
      ..dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            LegacyMessagingHeader(
              alignToConversationTitle: true,
              title: _displayPeerName,
              onBack: () => Navigator.pop(context),
              trailing: IconButton(
                key: const ValueKey('direct-chat-details'),
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
                tooltip: '聊天详情',
                onPressed: _openDetails,
                icon: const Icon(
                  Icons.more_horiz,
                  color: legacyMessageGold,
                  size: 24,
                ),
              ),
            ),
            if (_readOnly)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                color: const Color(0x221F1B17),
                child: Text(
                  _chat is GroupChatController &&
                          (_chat as GroupChatController).sendMuted
                      ? (_chat as GroupChatController).sendDisabledReason
                      : _connectionNotice,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
                ),
              ),
            Expanded(
              child: GestureDetector(
                key: const ValueKey('direct-chat-dismiss-area'),
                behavior: HitTestBehavior.opaque,
                onTap: _dismissComposer,
                child: ListView.builder(
                  key: const ValueKey('direct-chat-message-list'),
                  controller: _scrollController,
                  reverse: true,
                  physics: const _ChatViewportPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(640),
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                  itemCount: _messages.length + 1,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<String>) return null;
                    final index = _messages.indexWhere(
                      (message) => message.clientMessageId == key.value,
                    );
                    return index < 0 ? null : _messages.length - 1 - index;
                  },
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      if (_realTarget != null) {
                        return const SizedBox.shrink();
                      }
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          '今天 21:08',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0x998A8178),
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    final messageIndex = _messages.length - 1 - index;
                    final message = _messages[messageIndex];
                    return RepaintBoundary(
                      key: message.clientMessageId == null
                          ? ObjectKey(message)
                          : ValueKey(message.clientMessageId),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin:
                              _animatedMessageIds.contains(
                                message.clientMessageId,
                              )
                              ? 0.0
                              : 1.0,
                          end: 1.0,
                        ),
                        duration: const Duration(milliseconds: 220),
                        onEnd: () =>
                            _animatedMessageIds.remove(message.clientMessageId),
                        curve: Curves.easeOutCubic,
                        builder: (_, factor, child) => ClipRect(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            heightFactor: factor,
                            child: child,
                          ),
                        ),
                        child: _MessageRow(
                          timestamp: chatTimestampLabel(
                            message.createdDate,
                            messageIndex == 0
                                ? null
                                : _messages[messageIndex - 1].createdDate,
                          ),
                          avatar: _chat == null || message.senderAccount == null
                              ? null
                              : ChatMemberAvatar(
                                  account: message.senderAccount!,
                                  own: message.mine,
                                  profile: cachedChatAvatarProfile(
                                    _avatarProfiles,
                                    message.senderAccount!,
                                    () => _chat!.messaging.avatarProfile(
                                      message.senderAccount!,
                                    ),
                                  ),
                                ),
                          message: message,
                          imageContent:
                              message.videoDurationMs != null &&
                                  message.messageId != null &&
                                  _chat != null
                              ? ChatVideoView(
                                  repository: _chat!.messaging,
                                  scopeId:
                                      widget.groupId ?? _chat!.conversationId,
                                  messageId: message.messageId!,
                                  group: widget.groupId != null,
                                  width: message.videoWidth ?? 320,
                                  height: message.videoHeight ?? 240,
                                  durationMs: message.videoDurationMs!,
                                  onTap: () {
                                    final repository = _chat!.messaging;
                                    _voicePlayback?.stop();
                                    _inputFocusNode.unfocus();
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) => Scaffold(
                                          backgroundColor: Colors.black,
                                          appBar: AppBar(
                                            backgroundColor: Colors.black,
                                            leading: KingBackButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                            ),
                                            title: const Text('视频'),
                                          ),
                                          body: SafeArea(
                                            child: ChatVideoView(
                                              repository: repository,
                                              scopeId:
                                                  widget.groupId ??
                                                  _chat?.conversationId,
                                              messageId: message.messageId!,
                                              group: widget.groupId != null,
                                              full: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : message.fileName != null &&
                                    message.fileSize != null
                              ? ChatFileCard(
                                  fileName: message.fileName!,
                                  size: message.fileSize!,
                                  onTap:
                                      message.messageId == null ||
                                          message.fileAssetId == null ||
                                          message.fileSha256 == null ||
                                          _chat == null
                                      ? null
                                      : () {
                                          _voicePlayback?.stop();
                                          _inputFocusNode.unfocus();
                                          Navigator.of(context).push<void>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ChatFileDetailsPage(
                                                    repository:
                                                        _chat!.messaging,
                                                    reference: ChatFileReference(
                                                      messageId:
                                                          message.messageId!,
                                                      assetId:
                                                          message.fileAssetId!,
                                                      fileName:
                                                          message.fileName!,
                                                      size: message.fileSize!,
                                                      sha256:
                                                          message.fileSha256!,
                                                      group:
                                                          widget.groupId !=
                                                          null,
                                                      sender: message.mine
                                                          ? _chat!
                                                                .messaging
                                                                .account
                                                          : widget.peerAccount,
                                                    ),
                                                  ),
                                            ),
                                          );
                                        },
                                )
                              : message.location != null
                              ? ChatLocationMessage(
                                  location: message.location!,
                                  mine: message.mine,
                                  onTap: () {
                                    _voicePlayback?.stop();
                                    _inputFocusNode.unfocus();
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) => ChatLocationDetailsPage(
                                          location: message.location!,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : message.voiceDurationMs != null
                              ? _voiceBubble(message)
                              : _realTarget != null &&
                                    message.kind == _FakeMessageKind.image
                              ? message.messageId == null || _chat == null
                                    ? const SizedBox(
                                        width: 142,
                                        height: 100,
                                        child: Center(child: Text('[图片]')),
                                      )
                                    : ChatImageView(
                                        repository: _chat!.messaging,
                                        scopeId:
                                            widget.groupId ??
                                            _chat!.conversationId,
                                        messageId: message.messageId!,
                                        group: widget.groupId != null,
                                      )
                              : null,
                          onAvatarTap: _realTarget == null
                              ? null
                              : () {
                                  _voicePlayback?.stop();
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => PublicMemberPage(
                                        account:
                                            message.senderAccount ??
                                            widget.peerAccount!,
                                        repository: _chat?.messaging,
                                      ),
                                    ),
                                  );
                                },
                          onRetry: () => _realTarget != null
                              ? _chat?.retry(message.clientMessageId!)
                              : setState(
                                  () => _messages[messageIndex] =
                                      _messages[messageIndex].copyWith(
                                        status: _FakeMessageStatus.sent,
                                      ),
                                ),
                          onLongPress: () => _showMessageMenu(messageIndex),
                          onQuoteTap: message.reply?.available == true
                              ? () => _openReply(message.reply!)
                              : null,
                          onTap: () => _openMediaPreview(message),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            ClipRRect(
              key: const ValueKey('direct-chat-bottom-card'),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(
                  60 * MediaQuery.sizeOf(context).width / 750,
                ),
              ),
              child: ColoredBox(
                color: legacyMessagePanel,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _composer(),
                    if (!_readOnly)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        reverseDuration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.bottomCenter,
                        child: _activeComposerPanel(),
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

  Widget _composer() {
    final r = MediaQuery.sizeOf(context).width / 750;
    return Container(
      color: legacyMessagePanel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_quotedDraft != null)
            Container(
              key: const ValueKey('direct-chat-quote-draft'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(58, 8, 14, 0),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF27221E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _quotedDraft!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0x99C9B69E),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('direct-chat-close-quote'),
                    tooltip: '取消引用',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      _quotedDraft = null;
                      _quotedMessageId = null;
                      _captureTextDraft();
                    }),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          Container(
            key: const ValueKey('direct-chat-composer-capsule'),
            margin: EdgeInsets.symmetric(horizontal: 30 * r, vertical: 22 * r),
            padding: EdgeInsets.symmetric(vertical: 5 * r),
            decoration: BoxDecoration(
              color: const Color(0xFF312C27),
              borderRadius: BorderRadius.circular(40 * r),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                IgnorePointer(
                  ignoring: _voiceMode,
                  child: ExcludeSemantics(
                    excluding: _voiceMode,
                    child: AnimatedOpacity(
                      opacity: _voiceMode ? 0 : 1,
                      duration: const Duration(milliseconds: 120),
                      child: Row(
                        children: [
                          _composerIcon(
                            'direct-chat-microphone',
                            '语音',
                            'microphone.svg',
                            _readOnly
                                ? null
                                : () {
                                    _inputFocusNode.unfocus();
                                    setState(() {
                                      _voiceInputToText = false;
                                      _voiceMode = true;
                                      _composerPanel = _ComposerPanel.none;
                                    });
                                  },
                          ),
                          Expanded(
                            child: TextField(
                              key: const ValueKey('direct-chat-input'),
                              controller: _controller,
                              focusNode: _inputFocusNode,
                              enabled: !_readOnly,
                              minLines: 1,
                              maxLines: 4,
                              style: TextStyle(
                                fontSize: 32 * r,
                                height: 1,
                                color: const Color(0xFFBBBBBB),
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText: _readOnly ? '当前不可发送消息' : '',
                                isDense: true,
                                filled: false,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12 * r,
                                  vertical: 19 * r,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _controller,
                            builder: (context, value, _) {
                              if (!_readOnly && value.text.trim().isNotEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: TextButton(
                                    key: const ValueKey('direct-chat-send'),
                                    onPressed: _send,
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(66, 32),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      backgroundColor: const Color(0xFF29B463),
                                      foregroundColor: Colors.black,
                                      shape: const StadiumBorder(),
                                      textStyle: const TextStyle(fontSize: 14),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('发送'),
                                        SizedBox(width: 4),
                                        Icon(Icons.send, size: 12),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _composerIcon(
                                    'direct-chat-emoji',
                                    '表情',
                                    _composerPanel == _ComposerPanel.emoji
                                        ? 'keynote.png'
                                        : 'smail.png',
                                    _readOnly ? null : _insertEmoji,
                                  ),
                                  _composerIcon(
                                    'direct-chat-attachments',
                                    '更多',
                                    'add.png',
                                    _readOnly ? null : _toggleAttachments,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: -5 * r,
                  bottom: -5 * r,
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: LayoutBuilder(
                      builder: (context, bounds) => Align(
                        alignment: Alignment.centerLeft,
                        child: IgnorePointer(
                          ignoring: !_voiceMode,
                          child: AnimatedOpacity(
                            opacity: _voiceMode ? 1 : 0,
                            duration: const Duration(milliseconds: 100),
                            child: AnimatedContainer(
                              key: const ValueKey('direct-chat-voice-surface'),
                              duration: const Duration(milliseconds: 650),
                              curve: _voiceMode
                                  ? const ElasticOutCurve(0.65)
                                  : Curves.easeOutCubic,
                              width: _voiceMode ? bounds.maxWidth : 60 * r,
                              height: _voiceMode ? bounds.maxHeight : 60 * r,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFF2D2A6),
                                    Color(0xFFE4B780),
                                    Color(0xFFD19A60),
                                    Color(0xFFEAC18F),
                                  ],
                                  stops: [0, .32, .78, 1],
                                ),
                                border: Border.all(
                                  color: const Color(0x66F7E9D1),
                                  width: .7,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x30201008),
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                                borderRadius: BorderRadius.circular(40 * r),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: _voiceMode
                                  ? Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Positioned(
                                          top: 2,
                                          left: 12,
                                          right: 12,
                                          height: 12,
                                          child: IgnorePointer(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Color(0x55FFFFFF),
                                                    Color(0x00FFFFFF),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: Listener(
                                            key: const ValueKey(
                                              'direct-chat-hold-to-talk',
                                            ),
                                            behavior: HitTestBehavior.opaque,
                                            onPointerDown: _beginVoiceHold,
                                            onPointerMove: _moveVoiceHold,
                                            onPointerUp: (_) => _endVoiceHold(),
                                            onPointerCancel: (_) =>
                                                _endVoiceHold(
                                                  interrupted: true,
                                                ),
                                            child: Center(
                                              child: Text(
                                                '按住 说话',
                                                style: legacyChatBodyTextStyle
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: const Color(
                                                        0xFF312C27,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              left: 10 * r - .7,
                                            ),
                                            child: IconButton(
                                              key: const ValueKey(
                                                'direct-chat-text-mode',
                                              ),
                                              tooltip: '切回文字',
                                              padding: EdgeInsets.zero,
                                              style: IconButton.styleFrom(
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              constraints:
                                                  BoxConstraints.tightFor(
                                                    width: 60 * r,
                                                    height: 60 * r,
                                                  ),
                                              onPressed: () => setState(
                                                () => _voiceMode = false,
                                              ),
                                              icon: SvgPicture.asset(
                                                'assets/legacy/messaging/keyboard.svg',
                                                width: 56 * r,
                                                height: 56 * r,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeComposerPanel() {
    return switch (_composerPanel) {
      _ComposerPanel.none => const SizedBox.shrink(),
      _ComposerPanel.attachments => _attachmentPanel(),
      _ComposerPanel.gifts => _giftPanel(),
      _ComposerPanel.emoji => _emojiPanel(),
    };
  }

  Future<void> _selectChatLocation() async {
    final chat = _chat;
    if (chat == null || _readOnly) return;
    _voicePlayback?.stop();
    _inputFocusNode.unfocus();
    await Navigator.of(context).push<ChatLocation>(
      MaterialPageRoute(
        builder: (_) => ChatLocationPickerPage(
          onConfirm: (location) async {
            var queued = false;
            await chat.sendLocation(location, onQueued: () => queued = true);
            if (!queued) throw StateError('会话已关闭');
          },
        ),
      ),
    );
  }

  Widget _attachmentPanel() {
    final actions = <Widget>[
      _AttachmentAction(
        assetPath: 'assets/legacy/messaging/more_1.png',
        label: '照片',
        onTap: () => _realTarget == null
            ? _addAttachment(_FakeMessageKind.image)
            : _chooseChatMedia(ImageSource.gallery),
      ),
      _AttachmentAction(
        assetPath: 'assets/legacy/messaging/more_2.png',
        label: '拍摄',
        onTap: () => _realTarget == null
            ? _takeFakePhoto()
            : _chooseChatMedia(ImageSource.camera),
      ),
      _AttachmentAction(
        assetPath: 'assets/legacy/messaging/action_video_call.svg',
        glyphSize: 32,
        label: '视频通话',
        onTap: _chooseCallType,
      ),
      _AttachmentAction(
        assetPath: 'assets/legacy/messaging/action_location.svg',
        glyphSize: 32,
        label: '位置',
        onTap: _selectChatLocation,
      ),
      _AttachmentAction(
        assetPath: 'assets/legacy/messaging/more_3.png',
        label: '金币',
        onTap: _openGoldCoinComposer,
      ),
      _AttachmentAction(
        assetPath: 'assets/legacy/messaging/action_red_packet.svg',
        glyphSize: 32,
        label: '红包',
        onTap: _openRedPacketComposer,
      ),
      _AttachmentAction(
        assetPath: 'assets/legacy/messaging/gift2.png',
        glyphSize: 23,
        label: '礼物',
        onTap: _toggleGifts,
      ),
      _AttachmentAction(
        assetPath: 'assets/legacy/messaging/action_voice_input.svg',
        glyphSize: 32,
        label: '语音输入',
        onTap: () {
          _inputFocusNode.unfocus();
          setState(() {
            _voiceInputToText = true;
            _voiceMode = true;
            _composerPanel = _ComposerPanel.none;
          });
        },
      ),
      _AttachmentAction(
        assetPath: 'assets/legacy/messaging/action_file.svg',
        glyphSize: 32,
        label: '文件',
        onTap: _selectChatFile,
      ),
      _AttachmentAction(
        assetPath: 'assets/legacy/messaging/action_coupon.svg',
        glyphSize: 32,
        label: '卡券',
        onTap: () => KingNotice.of(context).show('卡券分享暂未开放'),
      ),
    ];
    actions.add(
      _AttachmentAction(
        icon: Icons.mic_none,
        label: '语音草稿',
        onTap: () {
          final chat = _chat;
          _voicePlayback?.stop();
          showVoiceDrafts(
            context,
            onSend: chat == null
                ? null
                : (draft) => _voiceSender.send(chat, draft),
          );
        },
      ),
    );
    final pageCount = (actions.length / 8).ceil();
    return Container(
      key: const ValueKey('direct-chat-attachment-panel'),
      height: 242,
      width: double.infinity,
      color: legacyMessagePanel,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              key: const PageStorageKey('chat-attachment-pages'),
              itemCount: pageCount,
              onPageChanged: (page) => setState(() => _attachmentPage = page),
              itemBuilder: (context, page) => Column(
                children: [
                  for (var row = 0; row < 2; row++)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var col = 0; col < 4; col++)
                          Expanded(
                            child: page * 8 + row * 4 + col < actions.length
                                ? actions[page * 8 + row * 4 + col]
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (pageCount > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var page = 0; page < pageCount; page++)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: page == _attachmentPage
                          ? legacyMessageGold
                          : const Color(0x554A4037),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _giftPanel() {
    const categories = ['推荐', '场景特效', '爱意表达', '装饰互动'];
    final visible = _giftCategory == 0
        ? _giftItems
        : _giftItems
              .where((item) => item.category == _giftCategory)
              .toList(growable: false);
    return Container(
      key: const ValueKey('direct-chat-gift-panel'),
      height: 326,
      width: double.infinity,
      color: const Color(0xFF171513),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => ChoiceChip(
                      key: ValueKey('direct-chat-gift-category-$index'),
                      label: Text(categories[index]),
                      selected: _giftCategory == index,
                      onSelected: (_) => setState(() {
                        _giftCategory = index;
                        _selectedGift = null;
                      }),
                      showCheckmark: false,
                      backgroundColor: Colors.transparent,
                      selectedColor: const Color(0xFF342E28),
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: _giftCategory == index
                            ? legacyMessageGold
                            : const Color(0xFFB3AAA2),
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2520),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/legacy/messaging/gold.png',
                        width: 17,
                        height: 17,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$_goldBalance',
                        style: TextStyle(
                          color: legacyMessageGold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x332F2A25)),
          Expanded(
            child: GridView.builder(
              key: const ValueKey('direct-chat-gift-grid'),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.78,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final item = visible[index];
                final selected = _selectedGift == item.id;
                return InkWell(
                  key: ValueKey('direct-chat-gift-${item.id}'),
                  onTap: () => setState(() => _selectedGift = item.id),
                  borderRadius: BorderRadius.circular(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2E2924)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.asset(
                            item.assetPath,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        if (selected)
                          SizedBox(
                            width: double.infinity,
                            height: 24,
                            child: FilledButton(
                              key: ValueKey('direct-chat-gift-send-${item.id}'),
                              onPressed: () => _sendGift(item),
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: legacyMessageGold,
                                foregroundColor: const Color(0xFF24180A),
                                shape: const RoundedRectangleBorder(),
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('赠送'),
                            ),
                          )
                        else ...[
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB8B0A8),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${item.price} 币',
                            style: const TextStyle(
                              color: Color(0xFF6F6963),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || _readOnly) return;
    if (_realTarget != null) {
      final chat = _chat;
      if (chat == null) return;
      _sendRealText(chat, text);
      return;
    }
    final message = _FakeMessage(
      text,
      mine: true,
      quoted: _quotedDraft,
      status: text == '失败'
          ? _FakeMessageStatus.failed
          : _FakeMessageStatus.sending,
    );
    setState(() {
      _messages.add(message);
      _controller.clear();
      _quotedDraft = null;
      _quotedMessageId = null;
      _composerPanel = _ComposerPanel.none;
    });
    _scrollToLatest();
    if (message.status == _FakeMessageStatus.sending) _completeSend(message);
  }

  Future<void> _sendRealText(ChatSessionController chat, String text) async {
    _captureTextDraft();
    final draft = _textDraft;
    final store = _textDrafts;
    try {
      _textDraftTimer?.cancel();
      if (store != null && draft != null) await store.write(draft);
      if (!mounted || !identical(chat, _chat)) return;
      await chat.send(
        text,
        replyToMessageId: draft?.replyTo ?? _quotedMessageId,
        clientMessageId: draft?.id,
        onQueued: () {
          if (store != null && draft != null) {
            unawaited(store.remove(draft.id).catchError((Object _) {}));
          }
          if (mounted &&
              _controller.text.trim() == text &&
              identical(_textDraft, draft)) {
            setState(() {
              _controller.clear();
              _quotedDraft = null;
              _quotedMessageId = null;
              _composerPanel = _ComposerPanel.none;
            });
            _captureTextDraft();
          }
        },
      );
      if (mounted && chat.error != null) {
        KingNotice.of(context).show(chat.error!);
      }
    } catch (error) {
      if (mounted) {
        KingNotice.of(context).show(error.toString());
      }
    }
  }

  bool _requiresRealMedia() {
    if (_realTarget == null) return false;
    KingNotice.of(context).show('该消息功能正在接入，尚未发送');
    return true;
  }

  void _handleInputFocusChanged() {
    if (!_inputFocusNode.hasFocus || _composerPanel == _ComposerPanel.none) {
      return;
    }
    setState(() => _composerPanel = _ComposerPanel.none);
  }

  void _toggleAttachments() {
    final opening = _composerPanel != _ComposerPanel.attachments;
    if (opening) _inputFocusNode.unfocus();
    setState(() {
      _composerPanel = opening
          ? _ComposerPanel.attachments
          : _ComposerPanel.none;
      if (opening) _selectedGift = null;
    });
  }

  void _toggleGifts() {
    if (_requiresRealMedia()) return;
    final opening = _composerPanel != _ComposerPanel.gifts;
    if (opening) _inputFocusNode.unfocus();
    setState(() {
      _composerPanel = opening ? _ComposerPanel.gifts : _ComposerPanel.none;
      _selectedGift = null;
    });
  }

  void _insertEmoji() {
    if (_composerPanel == _ComposerPanel.emoji) {
      setState(() => _composerPanel = _ComposerPanel.none);
      _inputFocusNode.requestFocus();
    } else {
      _inputFocusNode.unfocus();
      setState(() => _composerPanel = _ComposerPanel.emoji);
    }
  }

  Widget _composerIcon(
    String key,
    String label,
    String asset,
    VoidCallback? onTap,
  ) {
    final r = MediaQuery.sizeOf(context).width / 750;
    final gift = asset == 'microphone.svg';
    return Padding(
      padding: EdgeInsets.only(
        left: gift ? 10 * r : 0,
        right: gift ? 0 : (asset == 'add.png' ? 16 : 30) * r,
      ),
      child: SizedBox(
        width: (gift ? 60 : 54) * r,
        height: (gift ? 60 : 54) * r,
        child: IconButton(
          key: ValueKey(key),
          tooltip: label,
          onPressed: onTap,
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: gift ? legacyMessageGold : Colors.transparent,
          ),
          icon: Padding(
            padding: EdgeInsets.zero,
            child: gift
                ? SvgPicture.asset(
                    'assets/legacy/messaging/microphone.svg',
                    width: 32 * r,
                    height: 32 * r,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF312C27),
                      BlendMode.srcIn,
                    ),
                  )
                : Image.asset(
                    'assets/legacy/messaging/$asset',
                    width: (gift ? 32 : 54) * r,
                    height: (gift ? 32 : 54) * r,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _emojiPanel() => ChatEmojiPanel(
    key: const ValueKey('direct-chat-emoji-panel'),
    account: _chat?.messaging.account,
    repository: _chat?.messaging,
    onEmoji: (emoji) {
      final selection = _controller.selection;
      final start = selection.isValid
          ? selection.start
          : _controller.text.length;
      final end = selection.isValid ? selection.end : start;
      _controller.value = TextEditingValue(
        text: _controller.text.replaceRange(start, end, emoji),
        selection: TextSelection.collapsed(offset: start + emoji.length),
      );
    },
    onSticker: (path) {
      if (_realTarget != null) {
        unawaited(_sendSavedSticker(path));
        return;
      }
      if (_requiresRealMedia()) return;
      setState(
        () => _messages.add(
          _FakeMessage(
            '[表情]',
            mine: true,
            kind: _FakeMessageKind.image,
            assetPath: path,
          ),
        ),
      );
      _scrollToLatest();
    },
    onDelete: () {
      final text = _controller.text.characters;
      _controller.text = text.isEmpty
          ? ''
          : text.take(text.length - 1).toString();
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    },
    onSend: _send,
  );

  Future<void> _sendSavedSticker(String path) async {
    if (_selectingImage) return;
    final chat = _chat;
    if (chat == null) {
      KingNotice.of(context).show('会话尚未就绪');
      return;
    }
    _selectingImage = true;
    try {
      final file = File(path);
      final length = await file.length();
      if (length <= 0 || length > 20 * 1024 * 1024) {
        throw StateError('请选择不超过20MB的表情');
      }
      final bytes = await file.readAsBytes();
      if (!mounted || !identical(chat, _chat)) return;
      _voicePlayback?.stop();
      _inputFocusNode.unfocus();
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              ChatImageSendPage(bytes: bytes, chat: chat, title: '发送表情'),
        ),
      );
    } catch (_) {
      if (mounted) KingNotice.of(context).show('无法读取表情，请重新添加后再试');
    } finally {
      _selectingImage = false;
    }
  }

  void _addAttachment(_FakeMessageKind kind) {
    if (_requiresRealMedia()) return;
    final message = switch (kind) {
      _FakeMessageKind.image => const _FakeMessage(
        '现场照片',
        mine: true,
        kind: _FakeMessageKind.image,
        assetPath: 'assets/legacy/home/mock_poster_music.png',
        status: _FakeMessageStatus.sending,
      ),
      _FakeMessageKind.video => const _FakeMessage(
        '现场短视频',
        mine: true,
        kind: _FakeMessageKind.video,
        assetPath: 'assets/legacy/home/mock_hero_recruitment.png',
        status: _FakeMessageStatus.sending,
      ),
      _FakeMessageKind.businessCard => const _FakeMessage(
        '星光香槟套餐',
        mine: true,
        kind: _FakeMessageKind.businessCard,
        status: _FakeMessageStatus.sending,
      ),
      _FakeMessageKind.text => throw StateError('Text uses the composer.'),
      _FakeMessageKind.goldCoin ||
      _FakeMessageKind.redPacket ||
      _FakeMessageKind.gift => throw StateError('Use the dedicated composer.'),
    };
    setState(() {
      _messages.add(message);
      _composerPanel = _ComposerPanel.none;
    });
    _scrollToLatest();
    _completeSend(message);
  }

  bool _selectingFile = false;
  Future<void> _selectChatFile() async {
    if (_selectingFile) return;
    final chat = _chat;
    if (chat == null) {
      KingNotice.of(context).show('会话尚未就绪');
      return;
    }
    _selectingFile = true;
    try {
      _inputFocusNode.unfocus();
      final drafts = await ChatFileDraftStore.open(
        chat.messaging.account,
        widget.groupId != null
            ? 'group:${widget.groupId}'
            : 'peer:${widget.peerAccount}',
      );
      ChatFileDraft? draft;
      try {
        draft = await drafts.read();
      } on FileSystemException {
        /* Reselect a removed source. */
      } on StateError {
        /* Damaged content must be replaced explicitly through picker. */
      }
      if (!mounted || !identical(chat, _chat)) return;
      if (draft == null) {
        final selected = await FilePicker.pickFile();
        if (selected == null || !mounted || !identical(chat, _chat)) return;
        final path = selected.path;
        if (path == null) throw StateError('无法读取该文件，请先下载到手机');
        draft = await drafts.save(File(path), selected.name);
      }
      if (!mounted || !identical(chat, _chat)) return;
      final selectedDraft = draft;
      _voicePlayback?.stop();
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChatFileSendPage(
            file: selectedDraft.file,
            fileName: selectedDraft.name,
            chat: chat,
            draft: selectedDraft,
            drafts: drafts,
          ),
        ),
      );
    } catch (error) {
      if (mounted) KingNotice.of(context).show(error.toString());
    } finally {
      _selectingFile = false;
    }
  }

  Future<void> _chooseChatMedia(ImageSource source) async {
    final chat = _chat;
    if (chat == null || _readOnly) return;
    final video = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF202020),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(source == ImageSource.camera ? '拍照' : '选择照片'),
              onTap: () => Navigator.pop(sheet, false),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(source == ImageSource.camera ? '录制视频' : '选择视频'),
              onTap: () => Navigator.pop(sheet, true),
            ),
          ],
        ),
      ),
    );
    if (!mounted || !identical(chat, _chat) || video == null) return;
    if (!video) {
      await _selectChatImage(source);
      return;
    }
    if (_selectingFile) return;
    _selectingFile = true;
    try {
      _inputFocusNode.unfocus();
      final drafts = await ChatFileDraftStore.open(
        chat.messaging.account,
        widget.groupId != null
            ? 'video-group:${widget.groupId}'
            : 'video-peer:${widget.peerAccount}',
      );
      ChatFileDraft? draft;
      try {
        draft = await drafts.read();
      } on FileSystemException {
        /* Reselect missing draft. */
      } on StateError {
        /* Reselect damaged draft. */
      }
      if (!mounted || !identical(chat, _chat)) return;
      if (draft == null) {
        final selected = await ImagePicker().pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 2),
        );
        if (selected == null || !mounted || !identical(chat, _chat)) return;
        final length = await selected.length();
        if (length < 1 || length > 64 * 1024 * 1024) {
          throw StateError('请选择两分钟以内、不超过64MB的视频');
        }
        draft = await drafts.save(File(selected.path), selected.name);
      }
      if (!mounted || !identical(chat, _chat)) return;
      _voicePlayback?.stop();
      final chosen = draft;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChatVideoSendPage(
            file: chosen.file,
            fileName: chosen.name,
            chat: chat,
            draft: chosen,
            drafts: drafts,
          ),
        ),
      );
    } catch (error) {
      if (mounted) KingNotice.of(context).show(error.toString());
    } finally {
      _selectingFile = false;
    }
  }

  Future<void> _selectChatImage(ImageSource source) async {
    if (_selectingImage) return;
    final chat = _chat;
    if (chat == null) {
      KingNotice.of(context).show('会话尚未就绪');
      return;
    }
    _selectingImage = true;
    try {
      _inputFocusNode.unfocus();
      final drafts = await ChatFileDraftStore.open(
        chat.messaging.account,
        widget.groupId != null
            ? 'image-group:${widget.groupId}'
            : 'image-peer:${widget.peerAccount}',
      );
      ChatFileDraft? draft;
      try {
        draft = await drafts.read();
      } on FileSystemException {
        // Reselect a missing private copy.
      } on StateError {
        // Damaged bytes must be replaced through the picker.
      }
      if (!mounted || !identical(chat, _chat)) return;
      if (draft == null) {
        final file = await ImagePicker().pickImage(source: source);
        if (file == null || !mounted || !identical(chat, _chat)) return;
        final length = await file.length();
        if (length == 0 || length > 20 * 1024 * 1024) {
          throw StateError('请选择不超过20MB的静态图片');
        }
        draft = await drafts.save(File(file.path), file.name);
      }
      if (draft.size == 0 || draft.size > 20 * 1024 * 1024) {
        throw StateError('请选择不超过20MB的静态图片');
      }
      final bytes = await draft.file.readAsBytes();
      if (!mounted || !identical(chat, _chat)) return;
      final selectedDraft = draft;
      _voicePlayback?.stop();
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChatImageSendPage(
            bytes: bytes,
            chat: chat,
            draft: selectedDraft,
            drafts: drafts,
          ),
        ),
      );
    } catch (error) {
      if (mounted) KingNotice.of(context).show(error.toString());
    } finally {
      _selectingImage = false;
    }
  }

  void _takeFakePhoto() {
    if (_requiresRealMedia()) return;
    const message = _FakeMessage(
      '刚刚拍摄',
      mine: true,
      kind: _FakeMessageKind.image,
      assetPath: 'assets/legacy/home/mock_hero_recruitment.png',
      status: _FakeMessageStatus.sending,
    );
    _appendFakeMessage(message);
  }

  Future<void> _openGoldCoinComposer() async {
    if (_requiresRealMedia()) return;
    setState(() => _composerPanel = _ComposerPanel.none);
    final amount = await _showNumberComposer(
      title: '转赠金币',
      helper: '当前可用 $_goldBalance 金币',
      action: '确认赠送',
      max: _goldBalance,
    );
    if (!mounted || amount == null) return;
    setState(() => _goldBalance -= amount);
    _appendFakeMessage(
      _FakeMessage(
        '$amount 枚',
        mine: true,
        kind: _FakeMessageKind.goldCoin,
        status: _FakeMessageStatus.sending,
      ),
    );
  }

  Future<void> _openRedPacketComposer() async {
    if (_requiresRealMedia()) return;
    setState(() => _composerPanel = _ComposerPanel.none);
    final amount = await _showNumberComposer(
      title: '发红包',
      helper: '本地 Mock，不会产生真实扣款',
      action: '塞钱进红包',
      max: 200,
      suffix: '元',
    );
    if (!mounted || amount == null) return;
    _appendFakeMessage(
      _FakeMessage(
        '恭喜发财 · ¥$amount.00',
        mine: true,
        kind: _FakeMessageKind.redPacket,
        status: _FakeMessageStatus.sending,
      ),
    );
  }

  Future<int?> _showNumberComposer({
    required String title,
    required String helper,
    required String action,
    required int max,
    String suffix = '枚',
  }) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171513),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          22,
          24,
          24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: legacyMessageGold,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              helper,
              style: const TextStyle(color: Color(0xFF8A8178), fontSize: 12),
            ),
            const SizedBox(height: 18),
            TextField(
              key: ValueKey('direct-chat-$title-input'),
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 22),
              decoration: InputDecoration(
                hintText: '请输入数量',
                suffixText: suffix,
                filled: true,
                fillColor: const Color(0xFF312C27),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: ValueKey('direct-chat-$title-confirm'),
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value == null || value <= 0 || value > max) return;
                Navigator.pop(sheetContext, value);
              },
              style: FilledButton.styleFrom(
                backgroundColor: legacyMessageGold,
                foregroundColor: const Color(0xFF24180A),
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  void _sendGift(_GiftItem item) {
    if (_requiresRealMedia()) return;
    if (item.price > _goldBalance) {
      KingNotice.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('金币不足，还差 ${item.price - _goldBalance} 枚')),
        );
      return;
    }
    setState(() {
      _goldBalance -= item.price;
      _selectedGift = null;
    });
    _appendFakeMessage(
      _FakeMessage(
        item.name,
        mine: true,
        kind: _FakeMessageKind.gift,
        assetPath: item.assetPath,
        status: _FakeMessageStatus.sending,
      ),
    );
  }

  void _appendFakeMessage(_FakeMessage message) {
    if (_requiresRealMedia()) return;
    setState(() {
      _messages.add(message);
      _composerPanel = _ComposerPanel.none;
    });
    _scrollToLatest();
    _completeSend(message);
  }

  Future<void> _completeSend(_FakeMessage message) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    final index = _messages.indexWhere((item) => identical(item, message));
    if (index == -1) return;
    setState(() {
      _messages[index] = message.copyWith(status: _FakeMessageStatus.sent);
    });
  }

  void _scrollToLatest() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.minScrollExtent;
      if ((_scrollController.position.pixels - target).abs() < 1) return;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _muted = false;

  Future<void> _openDetails() async {
    if (widget.groupId != null) {
      final repository = _chat?.messaging;
      if (repository == null) return;
      _voicePlayback?.stop();
      final departed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => GroupDetailsPage(
            groupId: widget.groupId!,
            repository: GroupChatRepository(repository),
          ),
        ),
      );
      if (mounted) {
        if (departed == true) {
          _chat?.resetVisibleHistory();
          Navigator.pop(context);
          return;
        }
        final chat = _chat;
        if (chat is GroupChatController) chat.invalidateMemberNames();
        await chat?.synchronize();
      }
      return;
    }
    _voicePlayback?.stop();
    final cleared = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        allowSnapshotting: false,
        builder: (_) => DirectChatDetailsPage(
          onCall: _openCall,
          peerName: _displayPeerName,
          peerAccount: widget.peerAccount,
          repository: _chat?.messaging,
          initialPinned: _chat?.settings['pinned'] == true,
          initialOnlyChat: _chat?.settings['onlyChat'] == true,
          loadedHistory:
              _chat?.messages
                  .where((m) => m['sequence'] is num)
                  .map((m) => m['text'])
                  .whereType<String>()
                  .toList() ??
              const [],
          initialMuted: _muted,
          onMutedChanged: (value) {
            _muted = value;
            widget.onMutedChanged?.call(value);
          },
        ),
      ),
    );
    if (cleared == true && mounted) {
      if (_chat case final DirectChatController direct) {
        direct.resetVisibleHistory(hideNearby: true);
      } else if (_chat != null) {
        _chat!.resetVisibleHistory();
      } else {
        setState(_messages.clear);
      }
    }
    await _chat?.synchronize();
  }

  void _openReply(ChatReply reply) {
    final chat = _chat;
    if (chat == null || !reply.available) return;
    _voicePlayback?.stop();
    final repository = chat.messaging;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatHistoryContextPage(
          onCall: widget.groupId == null ? _openCall : null,
          repository: repository,
          groupId: widget.groupId,
          senderLabel: (account) {
            if (account == repository.account) return '我';
            if (widget.groupId == null) return _displayPeerName;
            for (final row in chat.messages) {
              if (row['sender'] == account &&
                  row['senderName'] is String &&
                  row['senderName'] != account) {
                return row['senderName'] as String;
              }
            }
            return '群成员';
          },
          account: repository.account,
          messageId: reply.messageId,
          sequence: reply.sequence!,
          read: ({before, after, required limit}) => widget.groupId == null
              ? repository.history(
                  widget.peerAccount!,
                  before: before,
                  after: after,
                  limit: limit,
                )
              : GroupChatRepository(repository).history(
                  widget.groupId!,
                  before: before,
                  after: after,
                  limit: limit,
                ),
        ),
      ),
    );
  }

  Future<void> _showMessageMenu(int index) async {
    final message = _messages[index];
    final menuChat = _chat;
    if (message.system) return;
    final action = await showModalBottomSheet<_FakeMessageAction>(
      context: context,
      backgroundColor: legacyActionMenuBackground,
      builder: (sheetContext) => LegacyActionMenuStyle(
        child: SafeArea(
          child: Wrap(
            children: [
              if (message.voiceDurationMs != null &&
                  message.messageId != null &&
                  menuChat != null)
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: const Text('转文字'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _FakeMessageAction.transcribe,
                  ),
                ),
              if (message.kind == _FakeMessageKind.text)
                ListTile(
                  key: const ValueKey('direct-chat-copy'),
                  leading: const Icon(Icons.copy_outlined),
                  title: const Text('复制'),
                  onTap: () =>
                      Navigator.pop(sheetContext, _FakeMessageAction.copy),
                ),
              ListTile(
                enabled:
                    _realTarget == null ||
                    (_chat?.canReply == true && message.messageId != null),
                leading: const Icon(Icons.format_quote),
                title: const Text('引用'),
                onTap: () =>
                    Navigator.pop(sheetContext, _FakeMessageAction.quote),
              ),
              ListTile(
                key: const ValueKey('direct-chat-forward'),
                leading: const Icon(Icons.forward),
                title: const Text('转发'),
                onTap: () =>
                    Navigator.pop(sheetContext, _FakeMessageAction.forward),
              ),
              ListTile(
                enabled:
                    _realTarget == null ||
                    (message.messageId != null &&
                        (_chat?.canHideMessage(message.messageId!) ?? false)),
                key: const ValueKey('direct-chat-delete'),
                leading: const Icon(Icons.delete_outline),
                title: const Text('为我删除'),
                onTap: () =>
                    Navigator.pop(sheetContext, _FakeMessageAction.delete),
              ),
              if (message.mine &&
                  (_chat == null ||
                      (message.messageId != null &&
                          _chat!.canRecall(message.messageId!))))
                ListTile(
                  key: const ValueKey('direct-chat-recall'),
                  leading: const Icon(Icons.undo),
                  title: const Text('撤回'),
                  onTap: () =>
                      Navigator.pop(sheetContext, _FakeMessageAction.recall),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (_realTarget != null && !identical(menuChat, _chat)) return;
    if (action == _FakeMessageAction.transcribe &&
        menuChat != null &&
        message.messageId != null) {
      _voicePlayback?.stop();
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MessageVoiceTranscriptionPage(
            repository: menuChat.messaging,
            messageId: message.messageId!,
            group: widget.groupId != null,
          ),
        ),
      );
      return;
    }

    if (_realTarget != null &&
        action == _FakeMessageAction.forward &&
        _chat != null &&
        message.messageId != null &&
        (message.kind == _FakeMessageKind.text ||
            message.kind == _FakeMessageKind.image)) {
      _voicePlayback?.stop();
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ForwardTextPage(
            repository: _chat!.messaging,
            text: message.text,
            location: message.location,
            voiceMessageId: message.voiceDurationMs != null
                ? message.messageId
                : null,
            videoMessageId: message.videoDurationMs != null
                ? message.messageId
                : null,
            imageMessageId: message.kind == _FakeMessageKind.image
                ? message.messageId
                : null,
            sourceGroup: widget.groupId != null,
            file: message.fileAssetId == null
                ? null
                : ChatFileReference(
                    messageId: message.messageId!,
                    assetId: message.fileAssetId!,
                    fileName: message.fileName!,
                    size: message.fileSize!,
                    sha256: message.fileSha256!,
                    group: widget.groupId != null,
                    sender: message.mine
                        ? _chat!.messaging.account
                        : widget.peerAccount,
                  ),
            outbox: widget.chatOutbox,
          ),
        ),
      );
      return;
    }
    if (_realTarget != null &&
        action != _FakeMessageAction.copy &&
        action != _FakeMessageAction.quote &&
        action != _FakeMessageAction.delete &&
        action != _FakeMessageAction.recall) {
      KingNotice.of(context).show('该消息操作正在接入');
      return;
    }
    switch (action) {
      case _FakeMessageAction.transcribe:
        return;
      case _FakeMessageAction.copy:
        Clipboard.setData(ClipboardData(text: message.text));
        KingNotice.of(context)
            .showSnackBar(const SnackBar(content: Text('已复制')));
      case _FakeMessageAction.quote:
        if (_realTarget != null &&
            (_chat?.canReply != true || message.messageId == null)) {
          return;
        }
        setState(() {
          _quotedDraft = _messagePreview(message);
          _quotedMessageId = message.messageId;
          _captureTextDraft();
        });
      case _FakeMessageAction.forward:
        _voicePlayback?.stop();
        await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(
            allowSnapshotting: false,
            builder: (_) => ContactSelectorPage(preview: message.text),
          ),
        );
      case _FakeMessageAction.delete:
        if (_realTarget != null) {
          final controller = _chat;
          final id = message.messageId;
          if (controller == null ||
              id == null ||
              !controller.canHideMessage(id)) {
            return;
          }
          final confirmed = await _confirmMessageAction(
            title: '删除这条消息？',
            action: '删除',
            body: '只从你的聊天记录中删除，对方记录不受影响。',
          );
          if (!confirmed || !mounted || _chat != controller) return;
          try {
            await _voicePlayback?.stop();
            await controller.hideMessage(id);
          } catch (error) {
            if (mounted) KingNotice.of(context).show('删除失败：$error');
          }
          return;
        }
        final confirmed = await _confirmMessageAction(
          title: '删除这条消息？',
          action: '删除',
          body: '只会从当前设备的 Fake 会话中移除。',
        );
        if (confirmed && mounted && index < _messages.length) {
          setState(() => _messages.removeAt(index));
        }
      case _FakeMessageAction.recall:
        if (_chat != null) {
          final id = message.messageId;
          if (id == null) return;
          try {
            _voicePlayback?.stop();
            await _chat!.recall(id);
          } catch (error) {
            if (mounted) KingNotice.of(context).show('撤回失败：$error');
          }
          return;
        }
        final confirmed = await _confirmMessageAction(
          title: '撤回这条消息？',
          action: '撤回',
          body: '撤回后可重新编辑文字消息。',
        );
        if (confirmed && mounted && index < _messages.length) {
          setState(() {
            _messages[index] = const _FakeMessage(
              '你撤回了一条消息',
              mine: true,
              system: true,
            );
          });
        }
    }
  }

  String _messagePreview(_FakeMessage message) => switch (message.kind) {
    _FakeMessageKind.text => message.text,
    _FakeMessageKind.image => '[图片]',
    _FakeMessageKind.video => '[短视频]',
    _FakeMessageKind.businessCard => '[业务卡片] ${message.text}',
    _FakeMessageKind.goldCoin => '[金币] ${message.text}',
    _FakeMessageKind.redPacket => '[红包] ${message.text}',
    _FakeMessageKind.gift => '[礼物] ${message.text}',
  };

  Future<bool> _confirmMessageAction({
    required String title,
    required String action,
    required String body,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: legacyMessagePanel,
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: ValueKey('direct-chat-confirm-$action'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openMediaPreview(_FakeMessage message) async {
    if (message.call != null && widget.groupId == null && _chat != null) {
      await _openCall(message.call!.media);
      return;
    }
    if (_realTarget != null) {
      final repository = _chat?.messaging;
      if (message.messageId == null ||
          repository == null ||
          message.kind != _FakeMessageKind.image) {
        return;
      }
      _voicePlayback?.stop();
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              leading: KingBackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: ChatImageView(
                repository: repository,
                scopeId: widget.groupId ?? _chat?.conversationId,
                messageId: message.messageId!,
                group: widget.groupId != null,
                full: true,
              ),
            ),
          ),
        ),
      );
      return;
    }
    if (message.kind != _FakeMessageKind.image &&
        message.kind != _FakeMessageKind.video) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Material(
        color: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image(
                    image: message.imageProvider,
                    key: const ValueKey('direct-chat-media-preview'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: const ValueKey('direct-chat-close-media'),
                  tooltip: '关闭预览',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              if (message.kind == _FakeMessageKind.video)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 72,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.onRetry,
    required this.onLongPress,
    required this.onTap,
    this.onAvatarTap,
    this.onQuoteTap,
    this.avatar,
    this.imageContent,
    this.timestamp,
  });

  final _FakeMessage message;
  final VoidCallback onRetry;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  final VoidCallback? onAvatarTap, onQuoteTap;
  final Widget? imageContent;
  final Widget? avatar;
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    final label = timestamp;
    if (label == null) return _buildContent(context);
    return Column(
      children: [
        Padding(
          key: ValueKey('chat-timestamp-${message.messageId}'),
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8A8178), fontSize: 12),
          ),
        ),
        _buildContent(context),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.system) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0x998A8178), fontSize: 12),
        ),
      );
    }
    final isMedia =
        message.kind == _FakeMessageKind.image ||
        message.kind == _FakeMessageKind.video;
    final isVisualCard =
        isMedia ||
        message.kind == _FakeMessageKind.goldCoin ||
        message.kind == _FakeMessageKind.redPacket ||
        message.kind == _FakeMessageKind.gift;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: message.mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.mine) ...[
                GestureDetector(
                  onTap: onAvatarTap,
                  child: avatar ?? const LegacyFakeAvatar(size: 42),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!message.mine && message.senderName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0x998A8178),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onLongPress: onLongPress,
                      onTap: onTap,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        padding: isVisualCard
                            ? EdgeInsets.zero
                            : const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                        decoration: BoxDecoration(
                          color: isVisualCard
                              ? Colors.transparent
                              : message.mine
                              ? const Color(0xFF29B463)
                              : const Color(0x33C9B69E),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.quoted != null) ...[
                              GestureDetector(
                                key: ValueKey(
                                  'chat-reply-${message.messageId}',
                                ),
                                behavior: HitTestBehavior.opaque,
                                onTap: onQuoteTap,
                                child: Text(
                                  message.quoted!,
                                  style: TextStyle(
                                    color: message.mine
                                        ? const Color(0x99111111)
                                        : const Color(0x99C9B69E),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                            ],
                            imageContent ?? _MessageContent(message: message),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (message.mine) ...[
                const SizedBox(width: 10),
                avatar ?? const LegacyFakeAvatar(size: 42),
              ],
            ],
          ),
          if (message.status == _FakeMessageStatus.failed)
            TextButton.icon(
              key: const ValueKey('direct-chat-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.error_outline, size: 15),
              label: const Text('发送失败，重试'),
            )
          else if (message.status == _FakeMessageStatus.sending ||
              message.status == _FakeMessageStatus.queued)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 52),
              child: Text(
                message.status == _FakeMessageStatus.queued
                    ? '等待网络恢复…'
                    : '发送中…',
                style: const TextStyle(color: Color(0x66777777), fontSize: 11),
              ),
            )
          else if (message.mine &&
              message.status == _FakeMessageStatus.sent &&
              message.receiptLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 52),
              child: Text(
                message.receiptLabel!,
                key: ValueKey('message-receipt-${message.clientMessageId}'),
                style: const TextStyle(color: Color(0x66777777), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message});

  final _FakeMessage message;

  @override
  Widget build(BuildContext context) {
    switch (message.kind) {
      case _FakeMessageKind.text:
        if (message.call != null) {
          final color = message.mine
              ? const Color(0xFF222222)
              : legacyMessageGold;
          return Row(
            key: ValueKey('chat-call-record-${message.call!.id}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                message.call!.media == CallMedia.audio
                    ? Icons.call
                    : Icons.videocam,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.call!.displayText(outgoing: message.mine),
                  style: legacyChatBodyTextStyle.copyWith(color: color),
                ),
              ),
            ],
          );
        }
        return Text(
          message.text,
          style: legacyChatBodyTextStyle.copyWith(
            color: message.mine ? const Color(0xFF222222) : legacyMessageGold,
          ),
        );
      case _FakeMessageKind.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image(
            image: message.imageProvider,
            key: const ValueKey('direct-chat-image-message'),
            width: 142,
            height: 180,
            fit: BoxFit.cover,
          ),
        );
      case _FakeMessageKind.video:
        return Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image(
                image: message.imageProvider,
                key: const ValueKey('direct-chat-video-message'),
                width: 172,
                height: 112,
                fit: BoxFit.cover,
              ),
            ),
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 42),
          ],
        );
      case _FakeMessageKind.businessCard:
        return SizedBox(
          key: const ValueKey('direct-chat-business-card-message'),
          width: 218,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1611),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_outlined,
                      color: legacyMessageGold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: const TextStyle(
                            color: Color(0xFF222222),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          '08月29日 · KING CLUB',
                          style: TextStyle(
                            color: Color(0x99111111),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0x33222222)),
              const SizedBox(height: 6),
              const Text(
                '入场凭证 · UI Mock',
                style: TextStyle(color: Color(0x99111111), fontSize: 10),
              ),
            ],
          ),
        );
      case _FakeMessageKind.goldCoin:
        return _LegacyValueMessageCard(
          key: const ValueKey('direct-chat-gold-message'),
          assetPath: 'assets/legacy/messaging/more_3.png',
          title: 'KING CLUB 金币',
          subtitle: '${message.text} · 赠送成功',
        );
      case _FakeMessageKind.redPacket:
        return _LegacyValueMessageCard(
          key: const ValueKey('direct-chat-red-packet-message'),
          assetPath: 'assets/legacy/messaging/more_4.png',
          title: 'KING CLUB 红包',
          subtitle: message.text,
        );
      case _FakeMessageKind.gift:
        return Container(
          key: const ValueKey('direct-chat-gift-message'),
          width: 236,
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF231F1B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x554A4037)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image(
                image: message.imageProvider,
                width: 70,
                height: 70,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '赠送礼物',
                      style: TextStyle(
                        color: Color(0xFF8A8178),
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: legacyMessageGold,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _LegacyValueMessageCard extends StatelessWidget {
  const _LegacyValueMessageCard({
    super.key,
    required this.assetPath,
    required this.title,
    required this.subtitle,
  });

  final String assetPath;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 228,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF8B6E48),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(assetPath, width: 42, height: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0x44FFFFFF)),
          const SizedBox(height: 5),
          const Text(
            'KING CLUB',
            style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _AttachmentAction extends StatelessWidget {
  const _AttachmentAction({
    this.icon,
    this.assetPath,
    this.glyphSize = 26,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || assetPath != null);

  final IconData? icon;
  final String? assetPath;
  final double glyphSize;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0x4D323232),
                borderRadius: BorderRadius.circular(6),
              ),
              child: assetPath != null
                  ? Padding(
                      padding: EdgeInsets.all((64 - glyphSize) / 2),
                      child: assetPath!.endsWith('.svg')
                          ? SvgPicture.asset(
                              assetPath!,
                              colorFilter: const ColorFilter.mode(
                                Color(0x99C9B69E),
                                BlendMode.srcIn,
                              ),
                            )
                          : Image.asset(
                              assetPath!,
                              color: const Color(0x99C9B69E),
                              colorBlendMode: BlendMode.srcIn,
                              fit: BoxFit.contain,
                            ),
                    )
                  : Icon(icon, color: legacyMessageGold),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeMessage {
  const _FakeMessage(
    this.text, {
    required this.mine,
    this.quoted,
    this.reply,
    this.call,
    this.clientMessageId,
    this.messageId,
    this.fileName,
    this.fileAssetId,
    this.fileSha256,
    this.fileSize,
    this.videoDurationMs,
    this.videoWidth,
    this.videoHeight,
    this.voiceDurationMs,
    this.voiceAssetId,
    this.location,
    this.senderAccount,
    this.senderName,
    this.createdDate,
    this.receiptLabel,
    this.system = false,
    this.kind = _FakeMessageKind.text,
    this.assetPath,
    this.status = _FakeMessageStatus.sent,
  });

  final String? clientMessageId;
  final String? messageId;
  final String? fileName;
  final String? fileAssetId, fileSha256;
  final int? fileSize;
  final int? videoDurationMs, videoWidth, videoHeight;
  final int? voiceDurationMs;
  final String? voiceAssetId;
  final ChatLocation? location;
  final String? senderAccount;
  final String? senderName;
  final String? createdDate;
  final String? receiptLabel;
  final String text;
  final bool mine;
  final String? quoted;
  final ChatReply? reply;
  final ChatCallHistory? call;
  final bool system;
  final _FakeMessageKind kind;
  final String? assetPath;
  ImageProvider get imageProvider => assetPath!.startsWith('assets/')
      ? AssetImage(assetPath!)
      : FileImage(File(assetPath!));
  final _FakeMessageStatus status;

  _FakeMessage copyWith({_FakeMessageStatus? status}) => _FakeMessage(
    text,
    clientMessageId: clientMessageId,
    messageId: messageId,
    fileName: fileName,
    fileAssetId: fileAssetId,
    fileSha256: fileSha256,
    fileSize: fileSize,
    videoDurationMs: videoDurationMs,
    videoWidth: videoWidth,
    videoHeight: videoHeight,
    voiceDurationMs: voiceDurationMs,
    voiceAssetId: voiceAssetId,
    location: location,
    senderAccount: senderAccount,
    senderName: senderName,
    createdDate: createdDate,
    receiptLabel: receiptLabel,
    mine: mine,
    quoted: quoted,
    reply: reply,
    call: call,
    system: system,
    kind: kind,
    assetPath: assetPath,
    status: status ?? this.status,
  );
}

// Keep the latest message anchored during each viewport layout, without a
// second scroll animation after the keyboard or panel has finished opening.
class _ChatViewportPhysics extends ClampingScrollPhysics {
  const _ChatViewportPhysics({super.parent});
  @override
  _ChatViewportPhysics applyTo(ScrollPhysics? ancestor) =>
      _ChatViewportPhysics(parent: buildParent(ancestor));
  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (oldPosition.viewportDimension != newPosition.viewportDimension &&
        oldPosition.extentBefore < 24) {
      return newPosition.minScrollExtent;
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}
