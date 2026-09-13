import '../data/contact_groups_repository.dart';
import '../data/contacts_controller.dart';
import '../../messaging/data/messaging_repository.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import 'relationship_groups_page.dart';
import '../../messaging/presentation/legacy_messaging_components.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
    this.realData = false,
    this.repository,
    this.onScan,
    this.onPersonalQr,
    this.initialState = ContactsDemoState.ready,
    this.onSessionResetRequested,
  });

  final bool active;
  final bool realData;
  final MessagingRepository? repository;
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
  final _scrollController = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};
  int _indexRequest = 0;
  List<ContactGroup> _groups = [];
  Timer? _searchDebounce;
  late ContactsDemoState _state;
  String _query = '';
  bool _loadedOnce = false;
  bool _refreshing = false;
  ContactsController? _real;
  ContactGroupsRepository? _groupRepository;
  StreamSubscription<void>? _sessions;
  StreamSubscription<Map<String, dynamic>>? _events;
  int _connectionGeneration = 0;

  Future<void> _connectReal() async {
    final generation = ++_connectionGeneration;
    try {
      final repository = widget.repository ?? await MessagingRepository.open();
      if (!mounted || generation != _connectionGeneration) return;
      final controller = ContactsController(repository);
      _real = controller;
      _groupRepository = ContactGroupsRepository(repository);
      unawaited(_loadGroups());
      controller.addListener(() {
        if (!mounted) return;
        setState(() {
          _state = controller.error != null
              ? ContactsDemoState.partialError
              : controller.hasSnapshot && controller.contacts.isEmpty
              ? ContactsDemoState.empty
              : ContactsDemoState.ready;
        });
      });
      _events = KingclubRealtime.shared.events.listen((event) {
        if (event['eventType'] == 'chat.groups.changed' ||
            event['eventType'] == 'connection.ready') {
          unawaited(_loadGroups());
        }
        if (event['eventType'] == 'chat.relationship.changed' ||
            event['eventType'] == 'chat.friend-request.changed' ||
            event['eventType'] == 'chat.settings.changed' ||
            event['eventType'] == 'connection.ready') {
          unawaited(controller.refresh());
        }
      });
      await controller.refresh();
    } catch (e) {
      if (!mounted || generation != _connectionGeneration) return;
      setState(() => _state = ContactsDemoState.partialError);
    }
  }

  List<_FakeContact> get _realContacts {
    final rows = (_real?.contacts ?? const <MemberContact>[]).map((contact) {
      final initial = contact.displayName.characters.firstOrNull ?? '#';
      final section = RegExp(r'^[A-Za-z]$').hasMatch(initial)
          ? initial.toUpperCase()
          : '#';
      return _FakeContact(
        section,
        contact.account,
        contact.nickname,
        contact.remark,
        initial,
        false,
        contact.gender,
      );
    }).toList();
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#';
    rows.sort((a, b) {
      final section = alphabet
          .indexOf(a.section)
          .compareTo(alphabet.indexOf(b.section));
      return section != 0
          ? section
          : (a.remark ?? a.nickname).compareTo(b.remark ?? b.nickname);
    });
    return rows;
  }

  static const _allContacts = [
    _FakeContact('A', 'contact-alice', 'Alice', '艾琳', 'A', true, 2),
    _FakeContact('C', 'contact-chenxi', '晨曦', null, '晨', true, 1),
    _FakeContact('L', 'contact-lucas', 'Lucas', '卡座搭子', 'L', false, 1),
    _FakeContact('S', 'contact-summer', 'Summer', null, 'S', false, 2),
    _FakeContact('Z', 'contact-zhou', '周末组局官', null, '局', true, null),
    _FakeContact('#', 'contact-77', '77号朋友', '阿七', '7', false, null),
  ];

  @override
  void initState() {
    super.initState();
    _state = widget.realData ? ContactsDemoState.ready : widget.initialState;
    if (widget.realData) {
      _sessions = SecureSessionStore.changes.stream.listen((_) {
        _connectionGeneration++;
        _events?.cancel();
        _real?.dispose();
        _real = null;
        _groupRepository = null;
        _groups = [];
        if (mounted) {
          setState(() {
            _query = '';
            _searchController.clear();
            _state = ContactsDemoState.empty;
          });
        }
      });
      unawaited(_connectReal());
    }
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
    if (widget.realData && widget.active && !oldWidget.active) {
      unawaited(_real?.refresh());
    }
    if (!oldWidget.active && widget.active && !_loadedOnce) {
      unawaited(_loadFirst());
    }
  }

  Future<void> _loadFirst() async {
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
    if (widget.realData) {
      if (_real == null) {
        await _connectReal();
      } else {
        await _real!.refresh();
      }
      return;
    }
    if (_refreshing) return;
    setState(() => _refreshing = true);
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
    var contacts = widget.realData ? _realContacts : _allContacts;
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
    _connectionGeneration++;
    _sessions?.cancel();
    _events?.cancel();
    _real?.dispose();
    _searchDebounce?.cancel();
    _indexRequest++;
    _scrollController.dispose();
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
            controller: _scrollController,
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
                    _ContactRow(
                      title: '我的关系',
                      leading: const ColoredBox(
                        color: Color(0xFFAD8B55),
                        child: Icon(
                          Icons.people_alt_outlined,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      onTap: _openRelationships,
                    ),
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
            right: 0,
            top: 48,
            bottom: 110,
            child: _ContactAlphabetIndex(onSelect: _jumpToLetter),
          ),
      ],
    );
  }

  Future<void> _jumpToLetter(String letter) async {
    final request = ++_indexRequest;
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#';
    final sections = _visibleContacts.map((c) => c.section).toSet().toList();
    if (sections.isEmpty || !_scrollController.hasClients) return;
    final target = sections.firstWhere(
      (s) => alphabet.indexOf(s) >= alphabet.indexOf(letter),
      orElse: () => sections.last,
    );
    // Seek lazily built sections without assuming row heights or font metrics.
    while (mounted &&
        request == _indexRequest &&
        _scrollController.hasClients) {
      final sectionContext = _sectionKeys[target]?.currentContext;
      final render = sectionContext?.findRenderObject();
      if (render != null && render.attached) {
        final viewport = RenderAbstractViewport.of(render);
        final offset = viewport.getOffsetToReveal(render, 0).offset;
        _scrollController.jumpTo(
          offset.clamp(0, _scrollController.position.maxScrollExtent),
        );
        return;
      }
      final built = sections
          .where((s) => _sectionKeys[s]?.currentContext != null)
          .toList();
      final backwards =
          built.isNotEmpty &&
          sections.indexOf(target) < sections.indexOf(built.first);
      final position = _scrollController.position;
      final next =
          (position.pixels +
                  (backwards ? -1 : 1) * position.viewportDimension * .7)
              .clamp(0.0, position.maxScrollExtent);
      if ((next - position.pixels).abs() < .5) return;
      _scrollController.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> _loadGroups() async {
    final generation = _connectionGeneration;
    try {
      final groups = await _groupRepository?.load();
      if (mounted && generation == _connectionGeneration && groups != null) {
        setState(() => _groups = groups);
      }
    } catch (_) {
      /* The groups page exposes an explicit retry. */
    }
  }

  void _openRelationships() {
    if (widget.realData &&
        (_groupRepository == null || _real?.hasSnapshot != true)) {
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RelationshipGroupsPage(
          contacts: {
            for (final c in (widget.realData ? _realContacts : _allContacts))
              c.ref: c.remark ?? c.nickname,
          },
          groups: _groups,
          repository: widget.realData
              ? ContactGroupsRepository(_groupRepository!.messaging)
              : null,
          onChanged: (groups) {
            if (mounted) setState(() => _groups = groups);
          },
        ),
      ),
    );
  }

  ContactGroup? _groupFor(String ref) {
    for (final g in _groups) {
      if (g.members.contains(ref)) return g;
    }
    return null;
  }

  Widget _quickActions(BuildContext context) => _ContactRow(
    title: '新的朋友',
    badge: widget.realData ? 0 : 2,
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
            key: _sectionKeys.putIfAbsent(entry.key, () => GlobalKey()),
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
                group: _groupFor(contact.ref),
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
    this.gender,
    this.group,
    this.rowKey,
  });
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final int? badge;
  final bool verified;
  final int? gender;
  final ContactGroup? group;
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
                            if (gender == 1 || gender == 2) ...[
                              const SizedBox(width: 4),
                              Image.asset(
                                'assets/legacy/friendship/${gender == 1 ? 'man3' : 'woman3'}.png',
                                width: 12,
                                height: 12,
                                semanticLabel: gender == 1 ? '男' : '女',
                              ),
                            ],
                            if (group != null) ...[
                              const SizedBox(width: 4),
                              Tooltip(
                                message: group!.name,
                                child: Icon(
                                  relationshipIcons[group!.icon],
                                  key: ValueKey('contact-relation-$title'),
                                  size: 12,
                                  color: legacyMessageGold,
                                ),
                              ),
                            ],
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
                          SizedBox(height: 2 * r),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: const Color(0x66FFFFFF),
                              fontSize: 22 * r,
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
    this.group,
    required this.onTap,
  });
  final _FakeContact contact;
  final bool avatarFailed;
  final ContactGroup? group;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _ContactRow(
    title: contact.remark ?? contact.nickname,
    subtitle: contact.remark == null ? null : '昵称：${contact.nickname}',
    verified: contact.verified,
    gender: contact.gender,
    group: group,
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
    this.gender,
  );

  final String section;
  final String ref;
  final String nickname;
  final String? remark;
  final String initial;
  final bool verified;
  final int? gender;
}

class _ContactAlphabetIndex extends StatefulWidget {
  const _ContactAlphabetIndex({required this.onSelect});
  final ValueChanged<String> onSelect;
  @override
  State<_ContactAlphabetIndex> createState() => _ContactAlphabetIndexState();
}

class _ContactAlphabetIndexState extends State<_ContactAlphabetIndex> {
  static const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#';
  int? _active;
  void _select(double y, double height) {
    final index = (y / (height / letters.length)).floor().clamp(
      0,
      letters.length - 1,
    );
    if (_active == index) return;
    setState(() => _active = index);
    widget.onSelect(letters[index]);
  }

  void _clear() => setState(() => _active = null);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.clamp(0.0, 432.0);
        final cell = height / letters.length;
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 36,
            height: height,
            child: GestureDetector(
              key: const ValueKey('contacts-alphabet-index'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (d) => _select(d.localPosition.dy, height),
              onVerticalDragUpdate: (d) => _select(d.localPosition.dy, height),
              onVerticalDragEnd: (_) => _clear(),
              onVerticalDragCancel: _clear,
              onTapDown: (d) => _select(d.localPosition.dy, height),
              onTapUp: (_) => _clear(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      for (var i = 0; i < letters.length; i++)
                        Expanded(
                          child: Center(
                            child: Text(
                              letters[i],
                              style: TextStyle(
                                fontSize: 10,
                                color: _active == i
                                    ? legacyMessageGold
                                    : const Color(0xA6C9B69E),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_active != null)
                    Positioned(
                      right: 44,
                      top: ((_active! + .5) * cell - 28).clamp(
                        0.0,
                        (height - 56).clamp(0.0, double.infinity),
                      ),
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _AlphabetBubblePainter(),
                          child: SizedBox(
                            width: 64,
                            height: 56,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Center(
                                child: Text(
                                  letters[_active!],
                                  key: const ValueKey('contacts-index-bubble'),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
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
          ),
        );
      },
    ),
  );
}

class _AlphabetBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFA6A6A6);
    canvas.drawCircle(const Offset(28, 28), 28, paint);
    canvas.drawPath(
      Path()
        ..moveTo(52, 21)
        ..lineTo(64, 28)
        ..lineTo(52, 35)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AlphabetBubblePainter oldDelegate) => false;
}
