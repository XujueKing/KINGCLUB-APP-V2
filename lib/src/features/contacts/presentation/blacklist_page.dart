import 'package:flutter/material.dart';

const _legacyGold = Color(0xFFC9B69E);
const _legacyPink = Color(0xFFFBAFDA);
const _legacyDivider = Color(0xFF300716);

class BlacklistPage extends StatefulWidget {
  const BlacklistPage({
    super.key,
    required this.onOpenAddFriend,
    required this.onOpenUserProfile,
  });

  final VoidCallback onOpenAddFriend;
  final ValueChanged<String> onOpenUserProfile;

  @override
  State<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends State<BlacklistPage> {
  bool _loading = true;
  String? _unblockingTarget;
  late List<_FakeBlockedUser> _users;

  static const _seedUsers = [
    _FakeBlockedUser(
      targetRef: 'contact-alice',
      nickname: '艾琳',
      blockedAt: '2026-08-20',
      signature: '愿每一次相遇都有好心情',
    ),
    _FakeBlockedUser(
      targetRef: 'contact-noah',
      nickname: '阿浩',
      blockedAt: '2026-08-12',
      signature: '今晚不见不散',
    ),
    _FakeBlockedUser(
      targetRef: 'contact-momo',
      nickname: '墨墨',
      blockedAt: '2026-07-28',
      signature: '听歌，交友，记录生活',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _users = List<_FakeBlockedUser>.of(_seedUsers);
    _load();
  }

  Future<void> _load() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已刷新本地 Fake 黑名单')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _LegacyBlacklistHeader(
              onBack: () => Navigator.pop(context),
              onAddFriend: widget.onOpenAddFriend,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: _legacyGold,
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      return RefreshIndicator(
        color: _legacyGold,
        backgroundColor: const Color(0xFF171411),
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('blacklist-empty'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 210),
            Icon(Icons.person_off_outlined, color: Color(0x557A6C5A), size: 44),
            SizedBox(height: 14),
            Center(
              child: Text(
                '黑名单为空',
                style: TextStyle(color: Color(0x997A6C5A), fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _legacyGold,
      backgroundColor: const Color(0xFF171411),
      onRefresh: _refresh,
      child: ListView.builder(
        key: const ValueKey('blacklist-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return _LegacyBlacklistRow(
            key: ValueKey('blacklist-${user.targetRef}'),
            user: user,
            busy: _unblockingTarget == user.targetRef,
            first: index == 0,
            onOpen: () => widget.onOpenUserProfile(user.targetRef),
            onUnblock: () => _confirmUnblock(user),
          );
        },
      ),
    );
  }

  Future<void> _confirmUnblock(_FakeBlockedUser user) async {
    if (_unblockingTarget != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171411),
        title: const Text('解除黑名单'),
        content: Text('确定将 ${user.nickname} 移出黑名单？解除后不会自动恢复好友关系。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('blacklist-confirm-unblock'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF7373),
            ),
            child: const Text('确认解除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _unblockingTarget = user.targetRef);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _users.removeWhere((candidate) => candidate.targetRef == user.targetRef);
      _unblockingTarget = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已在本地演示中解除 ${user.nickname}')));
  }
}

class _LegacyBlacklistHeader extends StatelessWidget {
  const _LegacyBlacklistHeader({
    required this.onBack,
    required this.onAddFriend,
  });

  final VoidCallback onBack;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 48,
              child: IconButton(
                key: const ValueKey('blacklist-back'),
                tooltip: '返回',
                onPressed: onBack,
                icon: Image.asset(
                  'assets/legacy/friendship/back.png',
                  width: 22,
                  color: _legacyGold,
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  '黑名单',
                  style: TextStyle(color: _legacyGold, fontSize: 17),
                ),
              ),
            ),
            SizedBox.square(
              dimension: 48,
              child: IconButton(
                key: const ValueKey('blacklist-add-friend'),
                tooltip: '添加好友',
                onPressed: onAddFriend,
                icon: Image.asset(
                  'assets/legacy/friendship/add.png',
                  width: 20,
                  height: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyBlacklistRow extends StatelessWidget {
  const _LegacyBlacklistRow({
    super.key,
    required this.user,
    required this.busy,
    required this.first,
    required this.onOpen,
    required this.onUnblock,
  });

  final _FakeBlockedUser user;
  final bool busy;
  final bool first;
  final VoidCallback onOpen;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Container(
      constraints: BoxConstraints(minHeight: textScale > 1.5 ? 82 : 60),
      decoration: BoxDecoration(
        border: Border(
          top: first
              ? const BorderSide(color: _legacyDivider, width: 0.7)
              : BorderSide.none,
          bottom: const BorderSide(color: _legacyDivider, width: 0.7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: '查看${user.nickname}资料',
              child: InkWell(
                onTap: busy ? null : onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(25, 12, 8, 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Image.asset(
                          'assets/legacy/friendship/touxiang.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  user.nickname,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  user.blockedAt,
                                  style: const TextStyle(
                                    color: Color(0xFF444444),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.signature,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0x80FFFFFF),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: _legacyPink,
                    ),
                  )
                : Transform.scale(
                    scale: 0.78,
                    child: Switch(
                      key: ValueKey('blacklist-switch-${user.targetRef}'),
                      value: true,
                      activeThumbColor: Colors.white,
                      activeTrackColor: _legacyPink,
                      onChanged: (_) => onUnblock(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FakeBlockedUser {
  const _FakeBlockedUser({
    required this.targetRef,
    required this.nickname,
    required this.blockedAt,
    required this.signature,
  });

  final String targetRef;
  final String nickname;
  final String blockedAt;
  final String signature;
}
