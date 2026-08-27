import 'package:flutter/material.dart';

const _gold = Color(0xFFC9B69E);
const _rowActionWidth = 72.0;

enum _ConversationAction {
  toggleRead,
  togglePin,
  markRelationshipEnded,
  invalidate,
  restore,
  delete,
}

enum _FriendConversationStatus { active, relationshipEnded, invalid }

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    super.key,
    required this.active,
    required this.systemUnreadCount,
    required this.initialFriendUnreadCount,
    required this.onFriendUnreadChanged,
    required this.onOpenContacts,
    required this.onAddFriend,
    required this.onOpenSystemNotifications,
    required this.onOpenDirectChat,
  });

  final bool active;
  final int systemUnreadCount;
  final int initialFriendUnreadCount;
  final ValueChanged<int> onFriendUnreadChanged;
  final VoidCallback onOpenContacts;
  final VoidCallback onAddFriend;
  final VoidCallback onOpenSystemNotifications;
  final VoidCallback onOpenDirectChat;

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  bool _pinnedExpanded = true;
  bool _friendPinned = false;
  bool _friendVisible = true;
  late int _friendUnread;
  double _friendSlide = 0;
  bool _refreshing = false;
  bool _showOfflineBanner = false;
  bool _conversationRecovering = false;
  int _conversationGeneration = 0;
  _FriendConversationStatus _friendStatus = _FriendConversationStatus.active;

  @override
  void initState() {
    super.initState();
    _friendUnread = widget.initialFriendUnreadCount;
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                  children: [
                    if (_showOfflineBanner)
                      _ConversationOfflineBanner(
                        refreshing: _refreshing,
                        onRetry: () => _refreshConversations(retry: true),
                      ),
                    _PinnedToggle(
                      count: 1 + (_friendPinned && _friendVisible ? 1 : 0),
                      expanded: _pinnedExpanded,
                      onTap: () => setState(() {
                        _friendSlide = 0;
                        _pinnedExpanded = !_pinnedExpanded;
                      }),
                    ),
                    if (_pinnedExpanded)
                      _KingClubConversation(
                        unreadCount: widget.systemUnreadCount,
                        onTap: widget.onOpenSystemNotifications,
                      ),
                    if (_pinnedExpanded && _friendPinned && _friendVisible)
                      _friendConversation(),
                    if (!_friendPinned && _friendVisible) _friendConversation(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 66,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 17,
            child: IconButton(
              tooltip: '添加好友',
              onPressed: widget.onAddFriend,
              icon: const Icon(
                Icons.add_circle_outline,
                color: _gold,
                size: 29,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onOpenContacts,
                child: const Text(
                  '通讯录',
                  style: TextStyle(color: Color(0x66C9B69E), fontSize: 16),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 0, 0, 11),
                child: Text(
                  '聊天',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _friendConversation() {
    final preview = switch (_friendStatus) {
      _FriendConversationStatus.active => '周末 KING CLUB 见？',
      _FriendConversationStatus.relationshipEnded => '好友关系已结束 · 仅可查看历史摘要',
      _FriendConversationStatus.invalid => '会话已失效 · 请本地刷新',
    };
    return _FriendConversation(
      slide: _friendSlide,
      unreadCount: _friendUnread,
      pinned: _friendPinned,
      preview: preview,
      inactive: _friendStatus != _FriendConversationStatus.active,
      onTap: () {
        if (_friendSlide != 0) {
          setState(() => _friendSlide = 0);
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
      backgroundColor: const Color(0xFF171411),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('模拟关系已结束'),
                subtitle: const Text('会话摘要改为只读'),
                onTap: () => Navigator.pop(
                  context,
                  _ConversationAction.markRelationshipEnded,
                ),
              ),
            if (_friendStatus != _FriendConversationStatus.invalid)
              ListTile(
                key: const ValueKey('conversation-menu-invalid'),
                leading: const Icon(Icons.link_off_outlined),
                title: const Text('模拟会话失效'),
                subtitle: const Text('阻止错误导航并提供恢复'),
                onTap: () =>
                    Navigator.pop(context, _ConversationAction.invalidate),
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
                color: Colors.redAccent,
              ),
              title: const Text(
                '删除会话',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () => Navigator.pop(context, _ConversationAction.delete),
            ),
          ],
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
      case _ConversationAction.markRelationshipEnded:
        setState(() {
          _friendSlide = 0;
          _friendStatus = _FriendConversationStatus.relationshipEnded;
          _conversationGeneration++;
        });
        _setFriendUnread(0);
        _showFeedback('已切换为只读摘要（UI Mock）');
      case _ConversationAction.invalidate:
        setState(() {
          _friendSlide = 0;
          _friendStatus = _FriendConversationStatus.invalid;
          _conversationGeneration++;
        });
        _setFriendUnread(0);
        _showFeedback('会话引用已失效（UI Mock）');
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshConversations({bool retry = false}) async {
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

class _ConversationOfflineBanner extends StatelessWidget {
  const _ConversationOfflineBanner({
    required this.refreshing,
    required this.onRetry,
  });

  final bool refreshing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('conversation-offline-banner'),
      height: 58,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF181511),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33C9B69E)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Color(0x99C9B69E),
            size: 18,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '网络不可用，已保留最近会话',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
                ),
                SizedBox(height: 2),
                Text(
                  '缓存更新于 今天 21:08',
                  style: TextStyle(color: Color(0x66FFFFFF), fontSize: 10),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('conversation-refresh-retry'),
            onPressed: refreshing ? null : onRetry,
            child: Text(
              refreshing ? '重试中' : '重试',
              style: const TextStyle(color: _gold, fontSize: 12),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0x202E2922),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const SizedBox(width: 38),
              Icon(
                expanded ? Icons.format_list_bulleted : Icons.push_pin_outlined,
                size: 22,
                color: const Color(0x66C9B69E),
              ),
              const SizedBox(width: 22),
              Text(
                expanded ? '折叠置顶聊天' : '$count 个置顶聊天',
                style: const TextStyle(color: Color(0x66C9B69E), fontSize: 15),
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 116,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x332E2922), width: 1),
            ),
          ),
          child: Row(
            children: [
              const _KingAvatar(size: 58),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KING CLUB',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '收到50枚金币',
                      style: TextStyle(color: Color(0x66FFFFFF), fontSize: 14),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '08月23日',
                    style: TextStyle(color: Color(0x66FFFFFF), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  if (unreadCount > 0)
                    _UnreadBadge(
                      key: const ValueKey('system-conversation-unread-badge'),
                      count: unreadCount,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFE84848),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FriendConversation extends StatelessWidget {
  const _FriendConversation({
    required this.slide,
    required this.unreadCount,
    required this.pinned,
    required this.preview,
    required this.inactive,
    required this.onTap,
    required this.onLongPress,
    required this.onSlideChanged,
    required this.onSlideEnd,
    required this.onToggleRead,
    required this.onTogglePin,
    required this.onDelete,
  });

  final double slide;
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
      height: 92,
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
                  color: pinned ? const Color(0x202E2922) : Colors.black,
                  child: Container(
                    height: 92,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x332E2922), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/legacy/friendship/touxiang.png',
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '卡座搭子',
                                style: TextStyle(
                                  color: Color(0xCCFFFFFF),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: inactive
                                      ? const Color(0x99C9B69E)
                                      : const Color(0x66FFFFFF),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              '21:08',
                              style: TextStyle(
                                color: Color(0x66FFFFFF),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (unreadCount > 0)
                              Container(
                                key: const ValueKey(
                                  'conversation-unread-badge',
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE84848),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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
      height: 92,
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
