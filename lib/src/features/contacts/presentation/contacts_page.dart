import '../../messaging/presentation/legacy_messaging_components.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_theme.dart';

enum ContactIntentKind { friendRequests, addFriend, blacklist, userProfile }

class ContactRouteIntent {
  const ContactRouteIntent(this.kind, {this.targetRef});

  final ContactIntentKind kind;
  final String? targetRef;

  String get label => switch (kind) {
    ContactIntentKind.friendRequests => '新的朋友',
    ContactIntentKind.addFriend => '添加好友',
    ContactIntentKind.blacklist => '黑名单',
    ContactIntentKind.userProfile => '用户主页',
  };
}

enum ContactsDemoState {
  ready,
  initialLoading,
  empty,
  offlineCached,
  fatalError,
  partialError,
  avatarFailure,
  relationshipChanged,
  sessionInvalid,
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({
    super.key,
    required this.active,
    required this.onIntent,
    this.onOpenChat,
    this.onScan,
    this.onPersonalQr,
    this.initialState = ContactsDemoState.initialLoading,
    this.onSessionResetRequested,
  });

  final bool active;
  final ValueChanged<ContactRouteIntent> onIntent;
  final VoidCallback? onOpenChat;
  final VoidCallback? onScan;
  final VoidCallback? onPersonalQr;
  final ContactsDemoState initialState;
  final VoidCallback? onSessionResetRequested;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  late ContactsDemoState _state;
  String _query = '';
  bool _loadedOnce = false;
  bool _refreshing = false;

  static const _allContacts = [
    _FakeContact('A', 'contact-alice', 'Alice', '艾琳', 'A', true),
    _FakeContact('C', 'contact-chenxi', '晨曦', null, '晨', true),
    _FakeContact('L', 'contact-lucas', 'Lucas', '卡座搭子', 'L', false),
    _FakeContact('S', 'contact-summer', 'Summer', null, 'S', false),
    _FakeContact('Z', 'contact-zhou', '周末组局官', null, '局', true),
    _FakeContact('#', 'contact-77', '77号朋友', '阿七', '7', false),
  ];

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _loadedOnce = _state != ContactsDemoState.initialLoading;
    if (_state == ContactsDemoState.sessionInvalid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSessionInvalid(),
      );
    } else if (widget.active && !_loadedOnce) {
      unawaited(_loadFirst());
    }
  }

  @override
  void didUpdateWidget(covariant ContactsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active && !_loadedOnce) {
      unawaited(_loadFirst());
    }
  }

  Future<void> _loadFirst() async {
    setState(() => _state = ContactsDemoState.initialLoading);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || !widget.active) return;
    setState(() {
      _loadedOnce = true;
      _state = ContactsDemoState.ready;
    });
  }

  Future<void> _showSessionInvalid() async {
    _searchController.clear();
    _searchDebounce?.cancel();
    _query = '';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('contacts-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('好友快照和搜索词已清除，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('contacts-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) widget.onSessionResetRequested?.call();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      if (_state != ContactsDemoState.empty) {
        _state = ContactsDemoState.ready;
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  List<_FakeContact> get _visibleContacts {
    var contacts = _allContacts;
    if (_state == ContactsDemoState.relationshipChanged) {
      contacts = contacts
          .where((contact) => contact.ref != 'contact-lucas')
          .toList();
    }
    if (_query.isEmpty) return contacts;
    return contacts
        .where(
          (contact) =>
              contact.nickname.toLowerCase().contains(_query) ||
              (contact.remark?.toLowerCase().contains(_query) ?? false),
        )
        .toList();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    setState(() => _query = '');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _header(),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _header() => LegacyConversationTabs(
    chatSelected: false,
    onScan: widget.onScan,
    onPersonalQr: widget.onPersonalQr,
    onChat: _state == ContactsDemoState.sessionInvalid
        ? null
        : widget.onOpenChat,
    onContacts: () {},
    onAdd: _state == ContactsDemoState.sessionInvalid
        ? null
        : () => widget.onIntent(
            const ContactRouteIntent(ContactIntentKind.addFriend),
          ),
  );

  Widget _buildBody(BuildContext context) {
    if (!widget.active && !_loadedOnce) {
      return const _ContactsCenteredState(
        icon: Icons.contacts_outlined,
        title: '通讯录',
        message: '进入消息分支后加载 KingClub 好友',
      );
    }
    if (_state == ContactsDemoState.initialLoading) {
      return const _ContactsCenteredState(
        icon: Icons.contacts_outlined,
        title: '正在加载好友',
        message: '不会读取或上传手机通讯录',
        busy: true,
      );
    }
    if (_state == ContactsDemoState.fatalError) {
      return _ContactsCenteredState(
        icon: Icons.cloud_off_outlined,
        title: '通讯录加载失败',
        message: '当前没有展示任何联系人数据，可以安全重试。',
        actionLabel: '重新加载',
        onAction: _loadFirst,
      );
    }
    if (_state == ContactsDemoState.sessionInvalid) {
      return const _ContactsCenteredState(
        icon: Icons.lock_reset_outlined,
        title: '登录状态已失效',
        message: '好友快照与搜索词已清除；正式流程将由全局会话重置处理。',
      );
    }

    final hideIndex = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refresh,
          color: KingColors.onBrand,
          backgroundColor: KingColors.brand,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: LegacyConversationSearch(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                  hint: '搜索',
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.zero,
                sliver: SliverList.list(
                  children: [
                    _quickActions(context),
                    _LegacyBlacklistEntry(
                      onTap: () => widget.onIntent(
                        const ContactRouteIntent(ContactIntentKind.blacklist),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_state == ContactsDemoState.offlineCached)
                      const _StatusBanner(
                        icon: Icons.cloud_off_outlined,
                        title: '离线缓存',
                        message: '显示 10 分钟前更新的好友列表',
                        color: KingColors.warning,
                      ),
                    if (_state == ContactsDemoState.partialError)
                      const _StatusBanner(
                        icon: Icons.sync_problem_outlined,
                        title: '更多好友加载失败',
                        message: '已显示的好友仍可使用，下拉可重试',
                        color: KingColors.warning,
                      ),
                    if (_state == ContactsDemoState.relationshipChanged)
                      const _StatusBanner(
                        icon: Icons.person_remove_outlined,
                        title: '好友关系已更新',
                        message: '已移除不再是好友的联系人',
                        color: KingColors.info,
                      ),
                  ],
                ),
              ),
              ..._contactsSlivers(context),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
        if (!hideIndex && _state != ContactsDemoState.empty && _query.isEmpty)
          Positioned(
            right: 5,
            top: 258,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const DefaultTextStyle(
                style: TextStyle(fontSize: 11, color: Color(0x80C9B69E)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('A'),
                    Text('C'),
                    Text('L'),
                    Text('S'),
                    Text('Z'),
                    Text('#'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _quickActions(BuildContext context) => _ContactRow(
    title: '新的朋友',
    badge: 2,
    leading: Image.asset(
      'assets/legacy/friendship/addfriend.png',
      fit: BoxFit.cover,
    ),
    onTap: () => widget.onIntent(
      const ContactRouteIntent(ContactIntentKind.friendRequests),
    ),
  );

  List<Widget> _contactsSlivers(BuildContext context) {
    if (_state == ContactsDemoState.empty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ContactsCenteredState(
            icon: Icons.people_outline,
            title: '还没有好友',
            message: '可以通过公开昵称或短期好友码添加 KingClub 好友。',
            actionLabel: '添加好友',
            onAction: () => widget.onIntent(
              const ContactRouteIntent(ContactIntentKind.addFriend),
            ),
          ),
        ),
      ];
    }

    final contacts = _visibleContacts;
    if (_query.isNotEmpty && contacts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ContactsCenteredState(
            icon: Icons.search_off_outlined,
            title: '没有匹配的好友',
            message: '只能搜索自己的好友备注或公开昵称。',
            actionLabel: '清除搜索',
            onAction: _clearSearch,
          ),
        ),
      ];
    }

    final sections = <String, List<_FakeContact>>{};
    for (final contact in contacts) {
      sections.putIfAbsent(contact.section, () => []).add(contact);
    }

    final result = <Widget>[];
    for (final entry in sections.entries) {
      result.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              40 * MediaQuery.sizeOf(context).width / 750,
              12,
              20,
              4,
            ),
            child: Semantics(
              header: true,
              child: Text(
                entry.key,
                style: const TextStyle(fontSize: 12, color: Color(0x66FFFFFF)),
              ),
            ),
          ),
        ),
      );
      result.add(
        SliverPadding(
          padding: EdgeInsets.zero,
          sliver: SliverList.builder(
            itemCount: entry.value.length,
            itemBuilder: (context, index) {
              final contact = entry.value[index];
              return _ContactTile(
                contact: contact,
                avatarFailed:
                    _state == ContactsDemoState.avatarFailure && index == 0,
                onTap: () => widget.onIntent(
                  ContactRouteIntent(
                    ContactIntentKind.userProfile,
                    targetRef: contact.ref,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    return result;
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.verified = false,
    this.rowKey,
  });
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final int? badge;
  final bool verified;
  final Key? rowKey;
  @override
  Widget build(BuildContext context) {
    final r = MediaQuery.sizeOf(context).width / 750;
    return Material(
      color: Colors.black,
      child: InkWell(
        key: rowKey,
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              constraints: BoxConstraints(minHeight: 124 * r),
              padding: EdgeInsets.fromLTRB(40 * r, 12 * r, 50 * r, 12 * r),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        width: 84 * r,
                        height: 84 * r,
                        child: ClipOval(child: leading),
                      ),
                      if (badge != null && badge! > 0)
                        Positioned(
                          left: 60 * r,
                          top: -3 * r,
                          child: Container(
                            constraints: BoxConstraints(
                              minWidth: 34 * r,
                              minHeight: 34 * r,
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 5 * r),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFB5352),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${badge! > 99 ? 99 : badge}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22 * r,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 25 * r),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: const Color(0xBBFFFFFF),
                                  fontSize: 28 * r,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            if (verified) ...[
                              const SizedBox(width: 5),
                              const Tooltip(
                                message: '已认证',
                                child: Icon(
                                  Icons.verified_outlined,
                                  size: 14,
                                  color: Color(0x80C9B69E),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (subtitle != null) ...[
                          SizedBox(height: 5 * r),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: const Color(0x66FFFFFF),
                              fontSize: 24 * r,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width * .9 - 4,
                  height: .5,
                  child: const ColoredBox(color: Color(0x1CC9B69E)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyBlacklistEntry extends StatelessWidget {
  const _LegacyBlacklistEntry({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _ContactRow(
    rowKey: const ValueKey('contacts-blacklist'),
    title: '黑名单',
    onTap: onTap,
    leading: Image.asset(
      'assets/legacy/friendship/blacklist.png',
      fit: BoxFit.cover,
    ),
  );
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.avatarFailed,
    required this.onTap,
  });
  final _FakeContact contact;
  final bool avatarFailed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _ContactRow(
    title: contact.remark ?? contact.nickname,
    subtitle: contact.remark == null ? null : '昵称：${contact.nickname}',
    verified: contact.verified,
    onTap: onTap,
    leading: ColoredBox(
      color: legacyMessagePanel,
      child: Center(
        child: avatarFailed
            ? const Icon(
                Icons.person_outline,
                size: 24,
                color: Color(0xFFB7ADA0),
              )
            : Text(
                contact.initial,
                style: const TextStyle(fontSize: 18, color: Color(0xFFB7ADA0)),
              ),
      ),
    ),
  );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactsCenteredState extends StatelessWidget {
  const _ContactsCenteredState({
    required this.icon,
    required this.title,
    required this.message,
    this.busy = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: KingColors.brandStrong),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (busy) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FakeContact {
  const _FakeContact(
    this.section,
    this.ref,
    this.nickname,
    this.remark,
    this.initial,
    this.verified,
  );

  final String section;
  final String ref;
  final String nickname;
  final String? remark;
  final String initial;
  final bool verified;
}
