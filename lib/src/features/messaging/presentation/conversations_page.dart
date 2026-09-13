import 'package:flutter_svg/flutter_svg.dart';

import 'legacy_messaging_components.dart';

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
    required this.onOpenSystemNotifications,
    required this.onOpenDirectChat,
  });

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
  final VoidCallback onOpenSystemNotifications;
  final VoidCallback onOpenDirectChat;

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final _searchController = TextEditingController();
  String _query = "";
  bool _matches(String name) => name.toLowerCase().contains(_query);
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                        icon: Icons.wifi_off_outlined,
                        text: _refreshing ? '正在重新连接…' : '网络不可用，已保留最近会话',
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
                    if (_friendPinned && _friendVisible && _matches('卡座搭子'))
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
                    if (_matches('KING CLUB'))
                      _KingClubConversation(
                        unreadCount: widget.systemUnreadCount,
                        onTap: widget.onOpenSystemNotifications,
                      ),
                    if (!_friendPinned && _friendVisible && _matches('卡座搭子'))
                      _friendConversation(),
                    if (_query.isNotEmpty &&
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
    onChat: () {},
    onContacts: widget.onOpenContacts,
    onAdd: widget.onAddFriend,
    onScan: widget.onScan,
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
    required this.date,
    required this.unread,
    this.system = false,
    this.inactive = false,
    this.muted = false,
    this.pinned = false,
  });
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
                    if (system)
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
                          child: Text(
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
    required this.slide,
    required this.muted,
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
                    name: '卡座搭子',
                    pinned: pinned,
                    muted: muted,
                    preview: preview,
                    date: '21:08',
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
