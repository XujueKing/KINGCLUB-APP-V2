import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/king_theme.dart';

const _legacyGold = Color(0xFFC9B69E);

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
  });

  final bool active;
  final ValueChanged<ContactRouteIntent> onIntent;
  final VoidCallback? onOpenChat;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  ContactsDemoState _state = ContactsDemoState.initialLoading;
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
    if (widget.active) unawaited(_loadFirst());
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

  Widget _header() {
    return SizedBox(
      height: 67,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 17,
            child: IconButton(
              tooltip: '添加好友',
              onPressed: () => widget.onIntent(
                const ContactRouteIntent(ContactIntentKind.addFriend),
              ),
              icon: const Icon(
                Icons.add_circle_outline,
                color: _legacyGold,
                size: 29,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 0, 11),
                child: Text(
                  '通讯录',
                  style: TextStyle(
                    color: _legacyGold,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onOpenChat,
                child: const Text(
                  '聊天',
                  style: TextStyle(color: Color(0x66C9B69E), fontSize: 16),
                ),
              ),
            ],
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 0,
            child: Divider(height: 1, thickness: 1, color: Color(0x332E2922)),
          ),
        ],
      ),
    );
  }

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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverList.list(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      maxLength: 40,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      decoration: InputDecoration(
                        hintText: '搜索备注或昵称',
                        counterText: '',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _clearSearch,
                                tooltip: '清除搜索',
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _quickActions(context),
                    const SizedBox(height: 14),
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
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
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
                color: KingColors.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: KingColors.border),
              ),
              child: const Column(
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
      ],
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.person_add_alt_1_outlined,
            title: '新的朋友',
            subtitle: '2 个新申请',
            badge: 2,
            onTap: () => widget.onIntent(
              const ContactRouteIntent(ContactIntentKind.friendRequests),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.add_circle_outline,
            title: '添加好友',
            subtitle: '昵称或好友码',
            onTap: () => widget.onIntent(
              const ContactRouteIntent(ContactIntentKind.addFriend),
            ),
          ),
        ),
      ],
    );
  }

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

    final hideIndex = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final result = <Widget>[];
    for (final entry in sections.entries) {
      result.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, hideIndex ? 20 : 42, 6),
            child: Semantics(
              header: true,
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: KingColors.brandStrong),
              ),
            ),
          ),
        ),
      );
      result.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 0, hideIndex ? 12 : 34, 0),
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

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KingColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KingColors.border),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: KingColors.elevated,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: KingColors.brandStrong),
                ),
                if (badge != null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: KingColors.danger,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final displayName = contact.remark ?? contact.nickname;
    return Semantics(
      button: true,
      label:
          '$displayName${contact.remark == null ? '' : '，公开昵称 ${contact.nickname}'}${contact.verified ? '，已认证' : ''}',
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        leading: CircleAvatar(
          radius: 23,
          backgroundColor: avatarFailed
              ? KingColors.border
              : KingColors.elevated,
          foregroundColor: avatarFailed
              ? KingColors.textSecondary
              : KingColors.brandStrong,
          child: avatarFailed
              ? const Icon(Icons.person_outline, size: 24)
              : Text(
                  contact.initial,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (contact.verified) ...[
              const SizedBox(width: 5),
              const Tooltip(
                message: '已认证',
                child: Icon(
                  Icons.verified_outlined,
                  size: 17,
                  color: KingColors.info,
                ),
              ),
            ],
          ],
        ),
        subtitle: contact.remark == null
            ? null
            : Text('昵称：${contact.nickname}'),
        trailing: const Icon(
          Icons.chevron_right,
          color: KingColors.textSecondary,
        ),
      ),
    );
  }
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
