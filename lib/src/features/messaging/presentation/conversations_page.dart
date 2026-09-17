import '../data/chat_outbox.dart';
import '../data/pending_conversation_rows.dart';
import '../data/chat_text_draft_store.dart';
import 'chat_member_avatar.dart';
import 'conversation_draft_preview.dart';
import '../data/group_chat_repository.dart';
import '../data/chat_history_store.dart';
import '../data/conversation_relay_unread.dart';
import '../data/offline_relay_conversations.dart';
import '../data/novorudp_binding_runtime.dart';

import 'dart:async';

import '../data/chat_voice_inbox.dart';

import '../data/messaging_repository.dart';
import '../data/chat_sync_failure.dart';
import 'direct_chat_page.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../../../core/design_system/king_theme.dart';

import 'package:kingclub/src/core/design_system/king_notice.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'legacy_messaging_components.dart';

import 'package:flutter/material.dart';

const _gold = Color(0xFFC9B69E);
const _rowActionWidth = 72.0;

enum _ConversationAction {
  toggleRead,
  togglePin,
  hide,
  toggleBlock,
  restore,
  delete,
}

enum _FriendConversationStatus { active, relationshipEnded, invalid }

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    super.key,
    required this.active,
    this.realData = false,
    this.repository,
    this.openRelayHistory,
    this.openTextDraftStore,
    this.pendingOutbox,
    this.relayChanges,
    this.pendingRequests = 0,
    this.friendMuted = false,
    this.networkUnavailable = false,
    this.otherDeviceCount = 0,
    this.mobileNotificationsDisabled = false,
    required this.systemUnreadCount,
    required this.initialFriendUnreadCount,
    required this.onFriendUnreadChanged,
    required this.onOpenContacts,
    required this.onAddFriend,
    this.onScan,
    this.onPersonalQr,
    required this.onOpenSystemNotifications,
    required this.onOpenDirectChat,
  });

  final ChatOutbox? pendingOutbox;
  final bool realData;
  final int pendingRequests;
  final MessagingRepository? repository;
  final Future<ChatHistoryStore> Function()? openRelayHistory;
  final Future<ChatTextDraftStore> Function(String account, String target)?
  openTextDraftStore;
  final Stream<String>? relayChanges;
  final bool active;
  final bool friendMuted;
  final bool networkUnavailable;
  final int otherDeviceCount;
  final bool mobileNotificationsDisabled;
  final int systemUnreadCount;
  final int initialFriendUnreadCount;
  final ValueChanged<int> onFriendUnreadChanged;
  final VoidCallback onOpenContacts;
  final VoidCallback onAddFriend;
  final VoidCallback? onScan;
  final VoidCallback? onPersonalQr;
  final VoidCallback onOpenSystemNotifications;
  final VoidCallback onOpenDirectChat;

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage>
    with WidgetsBindingObserver {
  MessagingRepository? _repository;
  ChatVoiceInbox? _voiceInbox;
  final _avatarProfiles = <String, Future<Map<String, dynamic>>>{};
  final _realItems = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _pendingMessages = [];
  Map<String, String> _localNames = {};
  StreamSubscription<void>? _pendingEvents;
  int _pendingGeneration = 0;
  Future<void> _refreshPending(MessagingRepository repository) async {
    final generation = ++_pendingGeneration;
    try {
      final messages =
          await (widget.pendingOutbox ?? SecureChatOutbox(repository.account))
              .read();
      if (!mounted ||
          generation != _pendingGeneration ||
          !identical(repository, _repository)) {
        return;
      }
      List<Map<String, dynamic>>? local;
      final names = <String, String>{};
      if (repository.persistHistory || widget.openRelayHistory != null) {
        final history = await _openRelayHistory(repository);
        local = await history.readConversationList();
        for (final row in local) {
          final name = row['remark'] ?? row['nickname'];
          if (name is String &&
              name.trim().isNotEmpty &&
              row['localConfirmed'] != true) {
            names[row['kind'] == 'group'
                    ? 'group:${row['groupId']}'
                    : 'peer:${row['peer']}'] =
                name;
          }
        }
        try {
          for (final contact
              in await history.contactSnapshot() ?? <Map<String, dynamic>>[]) {
            final remark = (contact['remark'] as String?)?.trim();
            final name = remark?.isNotEmpty == true
                ? remark
                : contact['nickname'];
            if (name is String && name.trim().isNotEmpty) {
              names['peer:${contact['peer']}'] = name;
            }
          }
        } catch (_) {
          // A damaged optional name snapshot must not hide pending messages.
        }
      }
      if (!mounted ||
          generation != _pendingGeneration ||
          !identical(repository, _repository)) {
        return;
      }
      setState(() {
        _pendingMessages = messages;
        _localNames = names;
        if (local != null) {
          final merged = mergeConfirmedConversationRows(local, _realItems);
          _realItems
            ..clear()
            ..addAll(merged);
        }
      });
    } catch (_) {}
  }

  Map<String, ChatTextDraft> _drafts = {};
  StreamSubscription<void>? _draftEvents;
  int _draftGeneration = 0;
  Future<ChatTextDraftStore> _draftStore(String target) =>
      (widget.openTextDraftStore ?? ChatTextDraftStore.open)(
        _repository!.account,
        target,
      );

  Future<void> _refreshDrafts(MessagingRepository repository) async {
    final generation = ++_draftGeneration;
    try {
      final store =
          await (widget.openTextDraftStore ?? ChatTextDraftStore.open)(
            repository.account,
            'index',
          );
      final drafts = await store.readConversations();
      if (!mounted ||
          generation != _draftGeneration ||
          !identical(repository, _repository)) {
        return;
      }
      setState(() => _drafts = drafts);
    } catch (_) {
      // A failed local read does not discard a previously loaded snapshot.
    }
  }

  Future<void> _draftMenu(Map<String, dynamic> item) async {
    final repository = _repository;
    final target = item['_draftTarget'] as String;
    final id = item['_draftId'] as String;
    final remove = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF191715),
      builder: (sheet) => SafeArea(
        child: ListTile(
          title: const Text('删除草稿'),
          onTap: () => Navigator.pop(sheet, true),
        ),
      ),
    );
    if (remove != true || !mounted || !identical(repository, _repository)) {
      return;
    }
    try {
      final store = await _draftStore(target);
      await store.remove(id);
      if (repository != null) await _refreshDrafts(repository);
    } catch (_) {
      if (mounted && identical(repository, _repository)) {
        KingNotice.of(context).show('草稿删除失败，请重试');
      }
    }
  }

  final _slides = <String, double>{};
  final _actions = <(MessagingRepository, String)>{};
  StreamSubscription<Map<String, dynamic>>? _events;
  StreamSubscription<void>? _sessions;
  StreamSubscription<String>? _relayEvents;
  StreamSubscription<String>? _readEvents;
  StreamSubscription<ConversationHistoryRemoval>? _clearEvents;
  ChatHistoryStore? _observedHistory;
  StreamSubscription<String>? _remarkEvents;
  StreamSubscription<String?>? _relationshipEvents;
  int _localRead = 0;
  bool get _useRelayUnread =>
      widget.openRelayHistory != null ||
      (_repository?.persistHistory == true &&
          NovoRudpBindingRuntime.relayConfigured);
  Future<ChatHistoryStore> _openRelayHistory(
    MessagingRepository repository,
  ) async {
    final store =
        await (widget.openRelayHistory?.call() ??
            ChatHistoryStore.open(repository.account));
    if (!mounted ||
        store.account != repository.account ||
        !identical(repository, _repository)) {
      throw StateError('Chat account changed');
    }
    if (!identical(_observedHistory, store)) {
      _clearEvents?.cancel();
      _observedHistory = store;
      _clearEvents = store.clearedConversations.listen((removal) {
        if (!mounted || !identical(repository, _repository)) return;
        _localRead++;
        _pendingGeneration++;
        setState(() {
          removal.applyTo(_realItems);
        });
        widget.onFriendUnreadChanged(
          _realItems.fold<int>(
            0,
            (sum, row) => sum + (row['unreadCount'] as num).toInt(),
          ),
        );
        _refreshReal();
      });
    }
    return store;
  }

  int _realGeneration = 0;
  Future<void>? _refreshTask;
  bool _refreshAgain = false;
  bool _loadMoreAgain = false;
  bool _realReady = false;
  bool _hasMore = false;
  int _serverOffset = 0;
  final _searchController = TextEditingController();
  String _query = "";
  bool _matches(String name) => name.toLowerCase().contains(_query);
  @override
  void dispose() {
    _voiceInbox?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _realGeneration++;
    _events?.cancel();
    _sessions?.cancel();
    _relayEvents?.cancel();
    _readEvents?.cancel();
    _clearEvents?.cancel();
    _remarkEvents?.cancel();
    _relationshipEvents?.cancel();
    _pendingEvents?.cancel();
    _pendingGeneration++;
    _pendingMessages = [];
    _localNames = {};
    _draftEvents?.cancel();
    _draftGeneration++;
    _drafts = {};
    _searchController.dispose();
    super.dispose();
  }

  bool _pinnedExpanded = true;
  bool _friendPinned = false;
  bool _friendVisible = true;
  bool _friendBlocked = false;
  late int _friendUnread;
  double _friendSlide = 0;
  bool _refreshing = false;
  bool _showOfflineBanner = false;
  String? _refreshFailure;
  bool _conversationRecovering = false;
  int _conversationGeneration = 0;
  _FriendConversationStatus _friendStatus = _FriendConversationStatus.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _friendUnread = widget.initialFriendUnreadCount;
    if (widget.realData) _connectReal();
  }

  Future<void> _connectReal() async {
    final generation = ++_realGeneration;
    _events?.cancel();
    _sessions?.cancel();
    _relayEvents?.cancel();
    _readEvents?.cancel();
    _clearEvents?.cancel();
    _observedHistory = null;
    _remarkEvents?.cancel();
    _relationshipEvents?.cancel();
    _pendingEvents?.cancel();
    _pendingGeneration++;
    _pendingMessages = [];
    _localNames = {};
    _draftEvents?.cancel();
    _draftGeneration++;
    _drafts = {};
    try {
      final repository = widget.repository ?? await MessagingRepository.open();
      if (!mounted || generation != _realGeneration) return;
      _avatarProfiles.clear();
      _repository = repository;
      if (repository.persistHistory || widget.pendingOutbox != null) {
        _pendingEvents = SecureChatOutbox.changes(repository.account)
            .listen((_) async {
              await _refreshReal();
              if (mounted && identical(repository, _repository)) {
                await _refreshPending(repository);
              }
            });
        unawaited(_refreshPending(repository));
      }
      if (repository.persistHistory || widget.openTextDraftStore != null) {
        _draftEvents = ChatTextDraftStore.accountChanges(repository.account)
            .listen((_) => unawaited(_refreshDrafts(repository)));
        unawaited(_refreshDrafts(repository));
      }
      _relationshipEvents =
          MessagingRepository.relationshipChanges(repository.account)
              .listen((_) {
                if (!mounted || !identical(repository, _repository)) return;
                _avatarProfiles.clear();
                _refreshReal();
              });
      _remarkEvents = MessagingRepository.remarkChanges(repository.account)
          .listen((_) {
            if (mounted && identical(repository, _repository)) _refreshReal();
          });
      _readEvents = MessagingRepository.readChanges(repository.account)
          .listen((_) async {
            await _refreshLocalReads(repository);
            if (mounted && identical(repository, _repository)) _refreshReal();
          });
      if (_useRelayUnread) {
        _relayEvents =
            (widget.relayChanges ??
                    NovoRudpBindingRuntime.textChanges(repository.account))
                .listen((_) async {
                  await _refreshLocalRelay(repository);
                  if (mounted && identical(repository, _repository)) {
                    _refreshReal();
                  }
                });
      }
      _events = KingclubRealtime.shared.events.listen((event) {
        final type = event['eventType'] as String? ?? '';
        if (type == 'connection.ready' ||
            type == 'chat.friend-request.changed' ||
            type == 'chat.relationship.changed') {
          _avatarProfiles.clear();
        }
        if (type.startsWith('chat.') || type == 'connection.ready') {
          _refreshReal();
        }
      });
      _sessions = SecureSessionStore.changes.stream.listen((_) {
        _realGeneration++;
        _repository = null;
        _voiceInbox?.dispose();
        _voiceInbox = null;
        _avatarProfiles.clear();
        _events?.cancel();
        _relayEvents?.cancel();
        _readEvents?.cancel();
        _clearEvents?.cancel();
        _observedHistory = null;
        _remarkEvents?.cancel();
        _relationshipEvents?.cancel();
        _pendingEvents?.cancel();
        _pendingGeneration++;
        _pendingMessages = [];
        _localNames = {};
        _draftEvents?.cancel();
        _draftGeneration++;
        _drafts = {};
        if (mounted) {
          setState(() {
            _realItems.clear();
            _realReady = false;
          });
          widget.onFriendUnreadChanged(0);
          _rebindIfSignedIn();
        }
      });
      if (repository.persistHistory || widget.openRelayHistory != null) {
        try {
          final store = await _openRelayHistory(repository);
          final listRevision = store.conversationListRevision;
          var cached = await store.readConversationList();
          if (_useRelayUnread) {
            cached = await offlineRelayConversations(store, cached);
          }
          cached = (await repository.pendingReadProjection()).apply(cached);
          if (!mounted || !identical(repository, _repository)) return;
          // A realtime refresh may already be in flight; it must not suppress
          // disk restoration, or overwrite a newer server result with disk data.
          if (cached.isNotEmpty &&
              !_realReady &&
              listRevision == store.conversationListRevision) {
            setState(() {
              _realItems
                ..clear()
                ..addAll(cached);
              _realReady = true;
              _hasMore = false;
            });
            widget.onFriendUnreadChanged(
              cached.fold<int>(
                0,
                (sum, item) => sum + (item['unreadCount'] as num).toInt(),
              ),
            );
          }
        } catch (_) {
          // A damaged/missing cache must not prevent a fresh server request.
        }
      }
      await _refreshReal();
    } catch (error) {
      if (mounted) {
        setState(() {
          _showOfflineBanner = true;
          _refreshFailure = chatSyncFailureMessage(error);
        });
      }
    }
  }

  Future<void> _refreshReal({bool more = false}) {
    final pending = _refreshTask;
    if (pending != null) {
      // Repeated pagination must not append the same offset twice. A realtime
      // update during a request still needs one fresh first-page read afterward.
      if (!more) _refreshAgain = true;
      if (more && _hasMore) _loadMoreAgain = true;
      return pending;
    }
    return _refreshTask = _drainRefresh(more);
  }

  Future<void> _drainRefresh(bool more) async {
    try {
      do {
        _refreshAgain = false;
        _loadMoreAgain = false;
        await _fetchReal(more: more);
        more = !_refreshAgain && _loadMoreAgain && _hasMore;
      } while (mounted && (_refreshAgain || more));
    } finally {
      _refreshTask = null;
    }
  }

  Future<void> _fetchReal({bool more = false}) async {
    final repository = _repository;
    if (repository == null) return;
    final generation = ++_realGeneration;
    try {
      final history =
          repository.persistHistory || widget.openRelayHistory != null
          ? await _openRelayHistory(repository)
          : null;
      final listRevision = history?.conversationListRevision;
      final headsBeforeRequest =
          await history?.readConversationList() ?? <Map<String, dynamic>>[];
      final result = _useRelayUnread
          ? await conversationsWithRelayUnread(
              repository: repository,
              history: await _openRelayHistory(repository),
              offset: more ? _serverOffset : 0,
              loadedPeers: more
                  ? _realItems
                        .where(
                          (i) => i['kind'] != 'group' && i['localOnly'] != true,
                        )
                        .map((i) => i['peer'] as String)
                        .toSet()
                  : const {},
            )
          : await repository.conversations(offset: more ? _serverOffset : 0);
      // Absence is authoritative only for a complete first-page snapshot.
      // Never infer deletion from a partial page or a failed request.
      final settledHeads = !more && result['hasMore'] == false
          ? headsBeforeRequest
          : <Map<String, dynamic>>[];
      final serverRowCount = (result['items'] as List).length;
      var pageRows = (result['items'] as List)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList();
      if (history != null) {
        pageRows = mergeConfirmedConversationRows(
          await history.readConversationList(),
          pageRows,
          settledHeads: settledHeads,
        );
      }
      if (_useRelayUnread) {
        if (more) pageRows = mergeConversationRows(_realItems, pageRows);
        pageRows = await offlineRelayConversations(
          await _openRelayHistory(repository),
          pageRows,
          knownRows: _realItems,
        );
      }
      if (!mounted || generation != _realGeneration) return;
      if (history != null && listRevision != history.conversationListRevision) {
        // A clear committed while this request was in flight. Fetch a new
        // server snapshot rather than restoring the old preview/unread count.
        _refreshAgain = true;
        return;
      }
      _localRead++;
      setState(() {
        if (!more) _realItems.clear();
        for (final item in pageRows) {
          _realItems.removeWhere(
            (old) =>
                (old['kind'] == 'group') == (item['kind'] == 'group') &&
                (item['kind'] == 'group'
                    ? old['groupId'] == item['groupId']
                    : old['peer'] == item['peer']),
          );
          _realItems.add(item);
        }
        if (_useRelayUnread) sortConversationRows(_realItems);
        _hasMore = result['hasMore'] == true;
        _serverOffset =
            (result['nextServerOffset'] as int?) ??
            (more ? _serverOffset + serverRowCount : serverRowCount);
        _realReady = true;
        _showOfflineBanner = false;
        _refreshFailure = null;
      });
      if (repository.persistHistory) {
        (_voiceInbox ??= ChatVoiceInbox(repository)).update(_realItems);
      }
      widget.onFriendUnreadChanged(
        _realItems.fold<int>(
          0,
          (sum, item) => sum + (item['unreadCount'] as num).toInt(),
        ),
      );
      if (repository.persistHistory || widget.openRelayHistory != null) {
        try {
          await history!.saveConversationList(
            _realItems,
            expectedRevision: listRevision,
            settledHeads: settledHeads,
          );
        } catch (_) {
          // Cache availability must not turn a successful refresh into an error.
        }
      }
      if (history != null) {
        // Visibility checks run after rendering the list. A slow history
        // endpoint must not hold up the conversation list or pagination.
        unawaited(
          history.reconcileHiddenConfirmedHeads(
            candidates: headsBeforeRequest,
            visible: (result['items'] as List)
                .map((row) => Map<String, dynamic>.from(row as Map))
                .toList(),
            fetch: (group, target) => group
                ? GroupChatRepository(repository).history(target, limit: 1)
                : repository.history(target, limit: 1),
            isActive: () => mounted && identical(repository, _repository),
          ),
        );
      }
    } catch (error) {
      if (mounted && generation == _realGeneration) {
        setState(() {
          _showOfflineBanner = true;
          _refreshFailure = chatSyncFailureMessage(error);
        });
      }
    }
  }

  Future<void> _refreshLocalReads(MessagingRepository repository) async {
    final read = ++_localRead;
    final generation = _realGeneration;
    try {
      final projection = await repository.pendingReadProjection();
      if (!mounted ||
          !identical(repository, _repository) ||
          generation != _realGeneration ||
          read != _localRead) {
        return;
      }
      final rows = projection.apply(_realItems);
      setState(() {
        _realItems
          ..clear()
          ..addAll(rows);
      });
      widget.onFriendUnreadChanged(
        rows.fold<int>(
          0,
          (sum, row) => sum + (row['unreadCount'] as num).toInt(),
        ),
      );
    } catch (_) {
      // Keep the last list if local storage is temporarily unavailable.
    }
  }

  Future<void> _refreshLocalRelay(MessagingRepository repository) async {
    final read = ++_localRead;
    final generation = _realGeneration;
    try {
      final store = await _openRelayHistory(repository);
      final rows = (await repository.pendingReadProjection()).apply(
        await offlineRelayConversations(store, _realItems),
      );
      if (!mounted ||
          !identical(repository, _repository) ||
          generation != _realGeneration ||
          read != _localRead) {
        return;
      }
      setState(() {
        _realItems
          ..clear()
          ..addAll(rows);
        _realReady = true;
      });
      widget.onFriendUnreadChanged(
        rows.fold<int>(
          0,
          (sum, row) => sum + (row['unreadCount'] as num).toInt(),
        ),
      );
    } catch (_) {
      // A local read failure must not block the following server refresh.
    }
  }

  @override
  void didUpdateWidget(covariant ConversationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.realData && !oldWidget.realData) {
      _connectReal();
    } else if (widget.realData && widget.active && !oldWidget.active) {
      if (_repository == null) {
        _rebindIfSignedIn();
      } else {
        _refreshReal();
      }
    }
  }

  Future<void> _rebindIfSignedIn() async {
    final generation = _realGeneration;
    final session = await SecureSessionStore().readSession();
    if (!mounted ||
        generation != _realGeneration ||
        session == null ||
        !widget.realData) {
      return;
    }
    await _connectReal();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !widget.realData) return;
    if (_repository == null) {
      _rebindIfSignedIn();
    } else {
      _refreshReal();
    }
  }

  String _rowKey(Map<String, dynamic> item) => item['kind'] == 'group'
      ? 'group:${item['groupId']}'
      : 'direct:${item['peer']}';

  Future<void> _realAction(
    Map<String, dynamic> item,
    String action,
    MessagingRepository? expected,
  ) async {
    final repository = _repository;
    if (!mounted || repository == null || !identical(repository, expected)) {
      return;
    }
    final key = _rowKey(item);
    final candidates = _realItems.where((row) => _rowKey(row) == key);
    if (candidates.isEmpty) return;
    final lock = (repository, key);
    if (!_actions.add(lock)) return;
    try {
      await _performRealAction(
        repository,
        Map<String, dynamic>.from(candidates.first),
        action,
      );
    } finally {
      _actions.remove(lock);
    }
  }

  Future<void> _performRealAction(
    MessagingRepository repository,
    Map<String, dynamic> item,
    String action,
  ) async {
    bool current() => mounted && identical(repository, _repository);
    final groupId = item['groupId'] as String?;
    if (item['kind'] == 'group' && groupId != null) {
      final groups = GroupChatRepository(repository);
      try {
        switch (action) {
          case 'read':
            final sequence = (item['lastSequence'] as num).toInt();
            if (sequence > 0) await groups.markRead(groupId, sequence);
          case 'pin':
            await groups.settings(groupId, pinned: item['pinned'] != true);
          case 'hide':
            await groups.settings(groupId, hide: true);
            if (!current()) return;
            if (repository.persistHistory || widget.openRelayHistory != null) {
              await (await _openRelayHistory(repository))
                  .clear('group:$groupId');
            }
        }
        if (current()) await _refreshReal();
      } catch (error) {
        if (mounted && current()) KingNotice.of(context).show(error.toString());
      }
      return;
    }
    final peer = item['peer'] as String;
    try {
      switch (action) {
        case 'read':
          if (_useRelayUnread) {
            final store = await _openRelayHistory(repository);
            String? cursor;
            while (true) {
              if (!mounted || !identical(repository, _repository)) return;
              final ids = await store.nearbyUnreadIds(afterId: cursor);
              if (ids.isEmpty) break;
              if (!mounted || !identical(repository, _repository)) return;
              await store.markNearbyMemberRead(peer, ids);
              cursor = ids.last;
              if (ids.length < 200) break;
            }
            await _refreshLocalRelay(repository);
          }
          if (!mounted || !identical(repository, _repository)) return;
          final sequence = (item['lastSequence'] as num).toInt();
          if (sequence > 0) {
            await repository.markRead(peer, sequence);
          }
        case 'pin':
          await repository.settings(peer, pinned: item['pinned'] != true);
        case 'hide':
          await repository.settings(peer, hide: true);
          if (!current()) return;
          if (repository.persistHistory || widget.openRelayHistory != null) {
            await (await _openRelayHistory(repository))
                .clear('direct:$peer', hideNearby: true);
          }
        case 'block':
          await repository.setRelationship(peer, 'block');
      }
      if (current()) await _refreshReal();
    } catch (error) {
      if (mounted && current()) KingNotice.of(context).show(error.toString());
    }
  }

  Future<void> _realMenu(
    Map<String, dynamic> item,
    MessagingRepository? expected,
  ) async {
    final repository = _repository;
    if (!mounted || repository == null || !identical(repository, expected)) {
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: legacyActionMenuBackground,
      builder: (sheet) => LegacyActionMenuStyle(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('标为已读'),
                onTap: () => Navigator.pop(sheet, 'read'),
              ),
              ListTile(
                title: Text(item['pinned'] == true ? '取消置顶' : '置顶'),
                onTap: () => Navigator.pop(sheet, 'pin'),
              ),
              ListTile(
                title: const Text('不显示'),
                onTap: () => Navigator.pop(sheet, 'hide'),
              ),
              if (item['kind'] != 'group')
                ListTile(
                  title: const Text('拉黑'),
                  onTap: () => Navigator.pop(sheet, 'block'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action != null && mounted) await _realAction(item, action, repository);
  }

  Widget _realRow(Map<String, dynamic> item) {
    final repository = _repository;
    final draftOnly = item['_draftTarget'] is String;
    final pendingOnly = item['_pendingOnly'] == true;
    final group = item['kind'] == 'group';
    final target = (group ? item['groupId'] : item['peer']) as String;
    final slideKey = '${group ? 'group' : 'direct'}:$target';
    final localName =
        (pendingOnly ||
            (item['localConfirmed'] == true &&
                const {'好友', '群聊'}.contains(item['nickname'])))
        ? _localNames['${group ? 'group' : 'peer'}:$target']
        : null;
    final name =
        localName ??
        ((item['remark'] as String?)?.isNotEmpty == true
            ? item['remark'] as String
            : item['nickname'] as String? ?? target);
    final time = DateTime.tryParse(item['messageDate'] as String? ?? '')
        ?.toLocal();
    final date = time == null
        ? ''
        : '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return _FriendConversation(
      avatar: group
          ? const Icon(Icons.groups, color: Color(0xFFC9B69E), size: 32)
          : ChatMemberAvatar(
              account: target,
              profile: cachedChatAvatarProfile(
                _avatarProfiles,
                target,
                () => _repository!.avatarProfile(target),
              ),
            ),
      name: name,
      date: date,
      slide: _slides[slideKey] ?? 0,
      muted: item['muted'] == true,
      unreadCount: (item['unreadCount'] as num).toInt(),
      pinned: item['pinned'] == true,
      preview: item['preview'] as String? ?? '',
      previewWidget:
          !draftOnly && !pendingOnly && _repository?.persistHistory == true
          ? ConversationDraftPreview(
              key: ValueKey(
                '${_repository!.account}:${group ? 'group' : 'peer'}:$target',
              ),
              account: _repository!.account,
              target: '${group ? 'group' : 'peer'}:$target',
              preview: item['preview'] as String? ?? '',
              style: TextStyle(
                color: const Color(0x66FFFFFF),
                fontSize: 26 * MediaQuery.sizeOf(context).width / 750,
              ),
            )
          : null,
      inactive: false,
      onTap: () async {
        await Navigator.push<void>(
          context,
          KingPageRoute<void>(
            builder: (_) => DirectChatPage(
              peerAccount: group ? null : target,
              groupId: group ? target : null,
              peerName: name,
              repository: _repository,
              chatOutbox: widget.pendingOutbox,
              initialMuted: item['muted'] == true,
            ),
          ),
        );
        await _refreshReal();
      },
      onLongPress: () {
        if (draftOnly) {
          _draftMenu(item);
        } else if (!pendingOnly) {
          _realMenu(item, repository);
        }
      },
      onSlideChanged: (value) {
        if (!draftOnly && !pendingOnly) {
          setState(() => _slides[slideKey] = value);
        }
      },
      onSlideEnd: () => setState(
        () => _slides[slideKey] = (_slides[slideKey] ?? 0) < -72 ? -216 : 0,
      ),
      onToggleRead: () => _realAction(item, 'read', repository),
      onTogglePin: () => _realAction(item, 'pin', repository),
      onDelete: () => _realAction(item, 'hide', repository),
    );
  }

  List<Widget> _realRows() {
    final visible = pendingConversationRows(
      _repository?.account ?? '',
      _realItems,
      _pendingMessages,
    );
    final existing = visible
        .map(
          (item) => item['kind'] == 'group'
              ? 'group:${item['groupId']}'
              : 'peer:${item['peer']}',
        )
        .toSet();
    final draftRows = [
      for (final entry in _drafts.entries)
        if (!existing.contains(entry.key))
          <String, dynamic>{
            'kind': entry.key.startsWith('group:') ? 'group' : 'direct',
            if (entry.key.startsWith('group:'))
              'groupId': entry.key.substring(6)
            else
              'peer': entry.key.substring(5),
            'nickname':
                entry.value.displayName ??
                _localNames[entry.key] ??
                (entry.key.startsWith('group:') ? '群聊' : '好友'),
            'unreadCount': 0,
            'preview':
                '[草稿] ${entry.value.text.isEmpty ? '引用消息' : entry.value.text}',
            '_draftTarget': entry.key,
            '_draftId': entry.value.id,
          },
    ];
    final filtered = [...draftRows, ...visible]
        .where(
          (item) => _matches(
            '${item['remark'] ?? ''} ${item['nickname'] ?? ''} ${item['peer']} ${item['preview']}',
          ),
        )
        .toList();
    final pinned = filtered.where((item) => item['pinned'] == true).toList();
    return [
      if (pinned.isNotEmpty)
        Container(
          decoration: const BoxDecoration(
            color: Color(0x0DC9B69E),
            border: Border(
              top: BorderSide(color: Color(0x12C9B69E), width: .5),
              bottom: BorderSide(color: Color(0x12C9B69E), width: .5),
            ),
          ),
          child: Column(
            children: [
              if (_pinnedExpanded || _query.isNotEmpty) ...pinned.map(_realRow),
              if (_query.isEmpty)
                _PinnedToggle(
                  count: pinned.length,
                  expanded: _pinnedExpanded,
                  onTap: () =>
                      setState(() => _pinnedExpanded = !_pinnedExpanded),
                ),
            ],
          ),
        ),
      ...filtered.where((item) => item['pinned'] != true).map(_realRow),
      if (_hasMore)
        TextButton(
          onPressed: () => _refreshReal(more: true),
          child: const Text('加载更多'),
        ),
      if (_realReady && filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              _query.isEmpty ? '暂无聊天' : '未找到相关聊天',
              style: const TextStyle(color: Color(0x80C9B69E), fontSize: 14),
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                color: _gold,
                backgroundColor: const Color(0xFF1A1611),
                onRefresh: _refreshConversations,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 110),
                  children: [
                    LegacyConversationSearch(
                      controller: _searchController,
                      onChanged: (value) => setState(() {
                        _query = value.trim().toLowerCase();
                        _friendSlide = 0;
                      }),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),

                    if (widget.networkUnavailable || _showOfflineBanner)
                      _ConversationStatusRow(
                        key: const ValueKey('conversation-offline-banner'),
                        icon: _refreshFailure == null
                            ? Icons.wifi_off_outlined
                            : Icons.info_outline,
                        text: _refreshing
                            ? '正在重新连接…'
                            : (_refreshFailure ?? '网络不可用，已保留最近会话'),
                        onTap: _refreshing
                            ? null
                            : () => _refreshConversations(retry: true),
                      )
                    else if (widget.otherDeviceCount > 0)
                      _ConversationStatusRow(
                        key: const ValueKey('conversation-device-banner'),
                        icon: Icons.devices_outlined,
                        text:
                            '已登录 ${widget.otherDeviceCount} 台其他设备${widget.mobileNotificationsDisabled ? '，手机通知已关闭' : ''}',
                      ),
                    if (widget.realData) ..._realRows(),
                    if (!widget.realData &&
                        _friendPinned &&
                        _friendVisible &&
                        _matches('卡座搭子'))
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0x0DC9B69E),
                          border: Border(
                            top: BorderSide(
                              color: Color(0x12C9B69E),
                              width: .5,
                            ),
                            bottom: BorderSide(
                              color: Color(0x12C9B69E),
                              width: .5,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            if (_pinnedExpanded || _query.isNotEmpty)
                              _friendConversation(),
                            if (_query.isEmpty)
                              _PinnedToggle(
                                count: 1,
                                expanded: _pinnedExpanded,
                                onTap: () => setState(() {
                                  _friendSlide = 0;
                                  _pinnedExpanded = !_pinnedExpanded;
                                }),
                              ),
                          ],
                        ),
                      ),
                    if (!widget.realData && _matches('KING CLUB'))
                      _KingClubConversation(
                        unreadCount: widget.systemUnreadCount,
                        onTap: widget.onOpenSystemNotifications,
                      ),
                    if (!widget.realData &&
                        !_friendPinned &&
                        _friendVisible &&
                        _matches('卡座搭子'))
                      _friendConversation(),
                    if (!widget.realData &&
                        _query.isNotEmpty &&
                        !_matches('KING CLUB') &&
                        !(_friendVisible && _matches('卡座搭子')))
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            '未找到相关聊天',
                            style: TextStyle(
                              color: Color(0x80C9B69E),
                              fontSize: 14,
                            ),
                          ),
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

  Widget _header() => LegacyConversationTabs(
    chatSelected: true,
    pendingRequests: widget.pendingRequests,
    onChat: () {},
    onContacts: widget.onOpenContacts,
    onAdd: widget.onAddFriend,
    onScan: widget.onScan,
    onPersonalQr: widget.onPersonalQr,
  );

  Widget _friendConversation() {
    final preview = switch (_friendStatus) {
      _FriendConversationStatus.active => '周末 KING CLUB 见？',
      _FriendConversationStatus.relationshipEnded => '好友关系已结束 · 仅可查看历史摘要',
      _FriendConversationStatus.invalid => '会话已失效 · 请本地刷新',
    };
    return _FriendConversation(
      slide: _friendSlide,
      muted: widget.friendMuted,
      unreadCount: _friendUnread,
      pinned: _friendPinned,
      preview: preview,
      inactive: _friendStatus != _FriendConversationStatus.active,
      onTap: () {
        if (_friendSlide != 0) {
          setState(() => _friendSlide = 0);
          return;
        }
        if (_friendBlocked) {
          _showFeedback('已拉黑，请先从长按菜单解除拉黑');
          return;
        }
        switch (_friendStatus) {
          case _FriendConversationStatus.active:
            _setFriendUnread(0);
            widget.onOpenDirectChat();
          case _FriendConversationStatus.relationshipEnded:
            _showRelationshipEndedDialog();
          case _FriendConversationStatus.invalid:
            _showConversationInvalidDialog();
        }
      },
      onLongPress: _showFriendActions,
      onSlideChanged: (value) => setState(() => _friendSlide = value),
      onSlideEnd: () => setState(
        () => _friendSlide = _friendSlide < -60 ? -_rowActionWidth * 3 : 0,
      ),
      onToggleRead: () => _handleFriendAction(_ConversationAction.toggleRead),
      onTogglePin: () => _handleFriendAction(_ConversationAction.togglePin),
      onDelete: () => _handleFriendAction(_ConversationAction.delete),
    );
  }

  Future<void> _showFriendActions() async {
    setState(() => _friendSlide = 0);
    final action = await showModalBottomSheet<_ConversationAction>(
      context: context,
      backgroundColor: legacyActionMenuBackground,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (context) => LegacyActionMenuStyle(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0x66B7ADA0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              if (_friendStatus == _FriendConversationStatus.active)
                ListTile(
                  key: const ValueKey('conversation-menu-read'),
                  leading: const Icon(Icons.mark_chat_read_outlined),
                  title: Text(_friendUnread > 0 ? '标为已读' : '标为未读'),
                  onTap: () =>
                      Navigator.pop(context, _ConversationAction.toggleRead),
                ),
              ListTile(
                key: const ValueKey('conversation-menu-pin'),
                leading: Icon(
                  _friendPinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                ),
                title: Text(_friendPinned ? '取消置顶' : '置顶聊天'),
                onTap: () =>
                    Navigator.pop(context, _ConversationAction.togglePin),
              ),
              if (_friendStatus != _FriendConversationStatus.relationshipEnded)
                ListTile(
                  key: const ValueKey('conversation-menu-relationship-ended'),
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: const Text('不显示'),
                  onTap: () => Navigator.pop(context, _ConversationAction.hide),
                ),
              if (_friendStatus != _FriendConversationStatus.invalid)
                ListTile(
                  key: const ValueKey('conversation-menu-invalid'),
                  leading: const Icon(Icons.block_outlined),
                  title: Text(_friendBlocked ? '解除拉黑' : '拉黑'),
                  onTap: () =>
                      Navigator.pop(context, _ConversationAction.toggleBlock),
                ),
              if (_friendStatus != _FriendConversationStatus.active)
                ListTile(
                  key: const ValueKey('conversation-menu-restore'),
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: const Text('恢复正常 Mock 状态'),
                  onTap: () =>
                      Navigator.pop(context, _ConversationAction.restore),
                ),
              ListTile(
                key: const ValueKey('conversation-menu-delete'),
                leading: const Icon(
                  Icons.delete_outline,
                  color: legacyActionMenuForeground,
                ),
                title: const Text('删除会话', style: legacyActionMenuTextStyle),
                onTap: () => Navigator.pop(context, _ConversationAction.delete),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
    if (action != null && mounted) await _handleFriendAction(action);
  }

  Future<void> _handleFriendAction(_ConversationAction action) async {
    switch (action) {
      case _ConversationAction.toggleRead:
        final markRead = _friendUnread > 0;
        setState(() {
          _friendSlide = 0;
        });
        _setFriendUnread(markRead ? 0 : 1);
        _showFeedback(markRead ? '已标为已读' : '已标为未读');
      case _ConversationAction.togglePin:
        final pinned = !_friendPinned;
        setState(() {
          _friendSlide = 0;
          _friendPinned = pinned;
          if (pinned) _pinnedExpanded = true;
        });
        _showFeedback(pinned ? '已置顶' : '已取消置顶');
      case _ConversationAction.hide:
        setState(() {
          _friendSlide = 0;
          _friendVisible = false;
        });
        _setFriendUnread(0);
        _showFeedback('已隐藏会话');
      case _ConversationAction.toggleBlock:
        setState(() {
          _friendSlide = 0;
          _friendBlocked = !_friendBlocked;
        });
        if (_friendBlocked) _setFriendUnread(0);
        _showFeedback(_friendBlocked ? '已拉黑（本地演示）' : '已解除拉黑（本地演示）');
      case _ConversationAction.restore:
        _restoreFriendConversation();
      case _ConversationAction.delete:
        setState(() => _friendSlide = 0);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除会话'),
            content: const Text('确认删除并清空记录？\n当前为本地 UI Mock，不会影响服务器数据。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('conversation-confirm-delete'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定删除'),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          setState(() => _friendVisible = false);
          _setFriendUnread(0);
          _showFeedback('已删除会话');
        }
    }
  }

  Future<void> _showRelationshipEndedDialog() async {
    final goToContacts = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('好友关系已结束'),
        content: const Text('该会话仅保留本地历史摘要，不能继续发送消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('返回通讯录'),
          ),
          FilledButton(
            key: const ValueKey('conversation-readonly-dismiss'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (goToContacts == true && mounted) widget.onOpenContacts();
  }

  Future<void> _showConversationInvalidDialog() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会话已失效'),
        content: const Text('会话引用已过期或已被删除，当前不会打开聊天页。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'contacts'),
            child: const Text('返回通讯录'),
          ),
          FilledButton(
            key: const ValueKey('conversation-invalid-refresh'),
            onPressed: _conversationRecovering
                ? null
                : () => Navigator.pop(context, 'refresh'),
            child: const Text('本地刷新'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'contacts') {
      widget.onOpenContacts();
    } else if (action == 'refresh') {
      await _recoverInvalidConversation();
    }
  }

  Future<void> _recoverInvalidConversation() async {
    if (_conversationRecovering) return;
    final requestedGeneration = _conversationGeneration;
    setState(() => _conversationRecovering = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    if (requestedGeneration != _conversationGeneration ||
        _friendStatus != _FriendConversationStatus.invalid) {
      setState(() => _conversationRecovering = false);
      return;
    }
    setState(() {
      _conversationRecovering = false;
      _friendStatus = _FriendConversationStatus.active;
      _conversationGeneration++;
    });
    _showFeedback('会话已恢复（UI Mock）');
  }

  void _restoreFriendConversation() {
    setState(() {
      _friendSlide = 0;
      _friendVisible = true;
      _friendStatus = _FriendConversationStatus.active;
      _conversationGeneration++;
    });
    _setFriendUnread(1);
    _showFeedback('已恢复正常 Mock 状态');
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    KingNotice.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshConversations({bool retry = false}) async {
    if (widget.realData) {
      _avatarProfiles.clear();
      await _refreshReal();
      return;
    }
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _showOfflineBanner = !retry;
    });
    _showFeedback(retry ? '会话已是最新（UI Mock）' : '刷新失败，已保留最近会话');
  }

  void _setFriendUnread(int count) {
    final next = count < 0 ? 0 : count;
    if (next == _friendUnread) return;
    setState(() => _friendUnread = next);
    widget.onFriendUnreadChanged(next);
  }
}

class _ConversationStatusRow extends StatelessWidget {
  const _ConversationStatusRow({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
  });
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final r = MediaQuery.sizeOf(context).width / 750;
    return Material(
      color: const Color(0xFF202020),
      child: InkWell(
        key: onTap == null
            ? null
            : const ValueKey('conversation-refresh-retry'),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 84 * r),
          padding: EdgeInsets.symmetric(horizontal: 50 * r, vertical: 18 * r),
          child: Row(
            children: [
              Icon(icon, color: const Color(0x66FFFFFF), size: 32 * r),
              SizedBox(width: 30 * r),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: const Color(0x66FFFFFF),
                    fontSize: 26 * r,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedToggle extends StatelessWidget {
  const _PinnedToggle({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('conversation-pinned-toggle'),
        onTap: onTap,
        child: Ink(
          height: 84 * MediaQuery.sizeOf(context).width / 750,
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Row(
            children: [
              SizedBox(width: 70 * MediaQuery.sizeOf(context).width / 750),
              Icon(
                expanded ? Icons.format_list_bulleted : Icons.push_pin_outlined,
                size: 30 * MediaQuery.sizeOf(context).width / 750,
                color: const Color(0x66FFFFFF),
              ),
              SizedBox(width: 35 * MediaQuery.sizeOf(context).width / 750),
              Text(
                expanded ? '折叠置顶聊天' : '$count 个置顶聊天',
                style: TextStyle(
                  color: const Color(0x66FFFFFF),
                  fontSize: 28 * MediaQuery.sizeOf(context).width / 750,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KingClubConversation extends StatelessWidget {
  const _KingClubConversation({required this.unreadCount, required this.onTap});
  final int unreadCount;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: _ConversationContent(
        name: 'KING CLUB',
        preview: '收到50枚金币',
        date: '08月23日',
        unread: unreadCount,
        system: true,
      ),
    ),
  );
}

class _ConversationContent extends StatelessWidget {
  const _ConversationContent({
    required this.name,
    required this.preview,
    this.previewWidget,
    required this.date,
    required this.unread,
    this.avatar,
    this.system = false,
    this.inactive = false,
    this.muted = false,
    this.pinned = false,
  });
  final Widget? avatar;
  final Widget? previewWidget;
  final String name, preview, date;
  final int unread;
  final bool system, inactive, muted, pinned;
  @override
  Widget build(BuildContext context) {
    final r = MediaQuery.sizeOf(context).width / 750;
    return Stack(
      children: [
        Container(
          height: 140 * r,
          padding: EdgeInsets.only(left: 40 * r, right: 50 * r),
          child: Row(
            children: [
              SizedBox(
                width: 96 * r,
                height: 96 * r,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (avatar != null)
                      Positioned.fill(child: avatar!)
                    else if (system)
                      _KingAvatar(size: 96 * r)
                    else
                      ClipOval(
                        child: Image.asset(
                          'assets/legacy/friendship/touxiang.png',
                          width: 96 * r,
                          height: 96 * r,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (unread > 0)
                      Positioned(
                        left: 70 * r,
                        top: -3 * r,
                        child: Container(
                          key: ValueKey(
                            system
                                ? 'system-conversation-unread-badge'
                                : 'conversation-unread-badge',
                          ),
                          width: muted ? 16 * r : null,
                          height: muted ? 16 * r : null,
                          constraints: BoxConstraints(
                            minWidth: (muted ? 16 : 34) * r,
                            minHeight: (muted ? 16 : 34) * r,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: (muted ? 0 : 5) * r,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFB5352),
                            borderRadius: BorderRadius.circular(24 * r),
                          ),
                          alignment: Alignment.center,
                          child: muted
                              ? null
                              : Text(
                                  unread > 99 ? '99' : '$unread',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22 * r,
                                    height: 1,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 25 * r),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xBBFFFFFF),
                              fontSize: 30 * r,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        SizedBox(width: 10 * r),
                        Text(
                          date,
                          style: TextStyle(
                            color: const Color(0x66FFFFFF),
                            fontSize: 24 * r,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5 * r),
                    Row(
                      children: [
                        Expanded(
                          child:
                              previewWidget ??
                              Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: inactive
                                      ? const Color(0x99C9B69E)
                                      : const Color(0x66FFFFFF),
                                  fontSize: 26 * r,
                                ),
                              ),
                        ),
                        if (muted) ...[
                          SizedBox(width: 10 * r),
                          SvgPicture.asset(
                            'assets/legacy/messaging/muted.svg',
                            key: const ValueKey('conversation-muted-icon'),
                            semanticsLabel: '消息免打扰',
                            colorFilter: const ColorFilter.mode(
                              Color(0x66FFFFFF),
                              BlendMode.srcIn,
                            ),
                            width: 26 * r,
                            height: 26 * r,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * .9 - 4,
              height: .5,
              child: ColoredBox(
                color: pinned
                    ? const Color(0x12C9B69E)
                    : const Color(0x1CC9B69E),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendConversation extends StatelessWidget {
  const _FriendConversation({
    this.avatar,
    this.name = '卡座搭子',
    this.date = '21:08',
    required this.slide,
    required this.muted,
    required this.unreadCount,
    required this.pinned,
    required this.preview,
    this.previewWidget,
    required this.inactive,
    required this.onTap,
    required this.onLongPress,
    required this.onSlideChanged,
    required this.onSlideEnd,
    required this.onToggleRead,
    required this.onTogglePin,
    required this.onDelete,
  });

  final Widget? avatar;
  final Widget? previewWidget;
  final String name, date;
  final double slide;
  final bool muted;
  final int unreadCount;
  final bool pinned;
  final String preview;
  final bool inactive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<double> onSlideChanged;
  final VoidCallback onSlideEnd;
  final VoidCallback onToggleRead;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const actionsWidth = _rowActionWidth * 3;
    return SizedBox(
      key: const ValueKey('conversation-seatmate-row'),
      height: 140 * MediaQuery.sizeOf(context).width / 750,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ConversationRowAction(
                      key: const ValueKey('conversation-swipe-read'),
                      color: const Color(0xFF6F7075),
                      label: unreadCount > 0 ? '标已读' : '标未读',
                      onTap: onToggleRead,
                    ),
                    _ConversationRowAction(
                      key: const ValueKey('conversation-swipe-pin'),
                      color: const Color(0xFFFF861D),
                      label: pinned ? '取消置顶' : '置顶',
                      onTap: onTogglePin,
                    ),
                    _ConversationRowAction(
                      key: const ValueKey('conversation-swipe-delete'),
                      color: const Color(0xFFD6403A),
                      label: '删除',
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              transform: Matrix4.translationValues(slide, 0, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                onLongPress: onLongPress,
                onHorizontalDragUpdate: (details) {
                  onSlideChanged(
                    (slide + details.delta.dx).clamp(-actionsWidth, 0),
                  );
                },
                onHorizontalDragEnd: (_) => onSlideEnd(),
                child: ColoredBox(
                  // The sliding foreground must obscure the action tray. Composite
                  // the 5% pinned tint against black instead of making it transparent.
                  key: const ValueKey('conversation-row-surface'),
                  color: pinned
                      ? Color.alphaBlend(const Color(0x0DC9B69E), Colors.black)
                      : Colors.black,
                  child: _ConversationContent(
                    avatar: avatar,
                    name: name,
                    pinned: pinned,
                    muted: muted,
                    preview: preview,
                    previewWidget: previewWidget,
                    date: date,
                    unread: unreadCount,
                    inactive: inactive,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationRowAction extends StatelessWidget {
  const _ConversationRowAction({
    super.key,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _rowActionWidth,
      height: 140 * MediaQuery.sizeOf(context).width / 750,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KingAvatar extends StatelessWidget {
  const _KingAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .12),
      decoration: const BoxDecoration(
        color: Color(0xFF3047D6),
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        'assets/legacy/home/logo_2.png',
        color: Colors.white,
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.contain,
      ),
    );
  }
}
