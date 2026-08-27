import 'package:flutter/material.dart';

import 'friend_remark_page.dart';
import 'relationship_permissions_page.dart';
import 'send_friend_request_page.dart';

const _legacyGold = Color(0xFFC9B69E);
const _legacyMuted = Color(0x807F7468);
const _legacyPanel = Color(0x151C1814);
const _legacyLine = Color(0x161C1814);

enum UserProfileRelationship {
  friend,
  stranger,
  incomingPending,
  outgoingPending,
  blockedByMe,
  offlineCached,
  unavailable,
}

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.targetRef,
    this.initialRelationship = UserProfileRelationship.friend,
  });

  final String targetRef;
  final UserProfileRelationship initialRelationship;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late UserProfileRelationship _relationship;
  bool _actionPending = false;
  String? _remarkOverride;

  _FakePublicProfile get _profile =>
      _FakePublicProfile.forRef(widget.targetRef);

  @override
  void initState() {
    super.initState();
    _relationship = widget.initialRelationship;
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LegacyBackButton(onPressed: () => Navigator.maybePop(context)),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 46),
              child: _ProfileIdentity(
                profile: profile,
                displayName: _remarkOverride ?? profile.displayName,
              ),
            ),
            const SizedBox(height: 43),
            _LegacyMenuRow(
              key: const ValueKey('user-profile-details'),
              label: '朋友资料',
              onTap: _relationship == UserProfileRelationship.unavailable
                  ? null
                  : () => _openFriendRemark(profile),
            ),
            const SizedBox(height: 7),
            if (_relationship == UserProfileRelationship.friend ||
                _relationship == UserProfileRelationship.blockedByMe)
              _LegacyMenuRow(
                key: const ValueKey('user-profile-permissions'),
                label: '朋友权限',
                onTap: () => _openRelationshipPermissions(profile),
              )
            else
              _LegacySourceRow(source: _sourceText),
            const SizedBox(height: 7),
            _buildPrimaryAction(),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  String get _sourceText => switch (_relationship) {
    UserProfileRelationship.stranger => '扫一扫',
    UserProfileRelationship.incomingPending => '新的朋友',
    UserProfileRelationship.outgoingPending => '好友申请',
    UserProfileRelationship.offlineCached => '本地缓存',
    UserProfileRelationship.unavailable => '资料已不可用',
    _ => '通讯录',
  };

  Widget _buildPrimaryAction() {
    if (_actionPending) {
      return const _LegacyActionRow(
        key: ValueKey('user-profile-action-pending'),
        label: '正在处理…',
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 1.6),
        ),
      );
    }

    return switch (_relationship) {
      UserProfileRelationship.friend => _LegacyActionRow(
        key: const ValueKey('user-profile-message'),
        label: '发消息',
        icon: Image.asset(
          'assets/legacy/navigation/tabBar_chat.png',
          width: 29,
          height: 29,
          color: _legacyGold,
        ),
        onTap: () =>
            _showLocalResult('已打开与 ${_profile.displayName} 的 Fake 会话入口'),
      ),
      UserProfileRelationship.stranger => _LegacyActionRow(
        key: const ValueKey('user-profile-add'),
        label: '添加到通讯录',
        onTap: _sendRequest,
      ),
      UserProfileRelationship.incomingPending => _IncomingActions(
        onReject: () => _resolveIncoming(false),
        onAccept: () => _resolveIncoming(true),
      ),
      UserProfileRelationship.outgoingPending => const _LegacyActionRow(
        key: ValueKey('user-profile-waiting'),
        label: '等待对方验证',
      ),
      UserProfileRelationship.blockedByMe => _LegacyActionRow(
        key: const ValueKey('user-profile-unblock'),
        label: '解除拉黑',
        onTap: () {
          setState(() => _relationship = UserProfileRelationship.stranger);
          _showLocalResult('已在本地演示中解除拉黑');
        },
      ),
      UserProfileRelationship.offlineCached => const _LegacyActionRow(
        key: ValueKey('user-profile-offline'),
        label: '当前离线，仅可查看资料',
      ),
      UserProfileRelationship.unavailable => const _LegacyActionRow(
        key: ValueKey('user-profile-unavailable'),
        label: '该用户暂时无法访问',
      ),
    };
  }

  Future<void> _sendRequest() async {
    final result = await Navigator.of(context).push<SendFriendRequestResult>(
      MaterialPageRoute<SendFriendRequestResult>(
        builder: (_) => SendFriendRequestPage(
          targetRef: widget.targetRef,
          targetName: _remarkOverride ?? _profile.displayName,
        ),
      ),
    );
    if (!mounted || result != SendFriendRequestResult.sent) return;
    setState(() => _relationship = UserProfileRelationship.outgoingPending);
    _showLocalResult('好友申请已在本地演示中提交');
  }

  Future<void> _resolveIncoming(bool accepted) async {
    setState(() => _actionPending = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _actionPending = false;
      _relationship = accepted
          ? UserProfileRelationship.friend
          : UserProfileRelationship.stranger;
    });
    _showLocalResult(accepted ? '已在本地演示中接受申请' : '已在本地演示中拒绝申请');
  }

  void _showLocalResult(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openFriendRemark(_FakePublicProfile profile) async {
    final result = await Navigator.of(context).push<FriendRemarkResult>(
      MaterialPageRoute<FriendRemarkResult>(
        builder: (_) => FriendRemarkPage(
          targetRef: widget.targetRef,
          initialRemark: _remarkOverride ?? profile.displayName,
          signature: profile.signature,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _remarkOverride = result.remark.isEmpty ? null : result.remark;
    });
  }

  Future<void> _openRelationshipPermissions(_FakePublicProfile profile) async {
    final result = await Navigator.of(context).push<RelationshipChangeResult>(
      MaterialPageRoute<RelationshipChangeResult>(
        builder: (_) => RelationshipPermissionsPage(
          targetRef: widget.targetRef,
          displayName: _remarkOverride ?? profile.displayName,
          isMale: profile.isMale,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _relationship = switch (result) {
        RelationshipChangeResult.blocked => UserProfileRelationship.blockedByMe,
        RelationshipChangeResult.deleted => UserProfileRelationship.stranger,
      };
    });
  }
}

class _LegacyBackButton extends StatelessWidget {
  const _LegacyBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 18),
        child: IconButton(
          key: const ValueKey('user-profile-back'),
          tooltip: '返回',
          onPressed: onPressed,
          icon: Image.asset(
            'assets/legacy/friendship/back.png',
            width: 22,
            color: _legacyGold,
          ),
        ),
      ),
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.profile, required this.displayName});

  final _FakePublicProfile profile;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            'assets/legacy/friendship/touxiang.png',
            key: const ValueKey('user-profile-avatar'),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _legacyGold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    profile.isMale ? Icons.male_rounded : Icons.female_rounded,
                    size: 15,
                    color: profile.isMale
                        ? const Color(0xFF78AFFF)
                        : const Color(0xFFE07A9E),
                  ),
                  if (profile.verified) ...[
                    const SizedBox(width: 5),
                    const Tooltip(
                      message: '已认证',
                      child: Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Color(0xFFD2B377),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '昵称：${profile.nickname}',
                style: const TextStyle(color: _legacyMuted, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                '签名：${profile.signature}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _legacyMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegacyMenuRow extends StatelessWidget {
  const _LegacyMenuRow({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _legacyPanel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 46),
          decoration: const BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: _legacyLine),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: _legacyGold, fontSize: 16),
                ),
              ),
              if (onTap != null)
                Image.asset(
                  'assets/legacy/friendship/next.png',
                  width: 15,
                  color: _legacyGold.withValues(alpha: 0.65),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegacySourceRow extends StatelessWidget {
  const _LegacySourceRow({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 46),
      decoration: const BoxDecoration(
        color: _legacyPanel,
        border: Border.symmetric(horizontal: BorderSide(color: _legacyLine)),
      ),
      child: Row(
        children: [
          const Text('来源', style: TextStyle(color: _legacyGold, fontSize: 16)),
          const SizedBox(width: 54),
          Expanded(
            child: Text(
              '来自 $source',
              style: const TextStyle(color: _legacyMuted, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyActionRow extends StatelessWidget {
  const _LegacyActionRow({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
  });

  final String label;
  final Widget? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _legacyPanel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: const BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: _legacyLine),
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Text(
                label,
                style: TextStyle(
                  color: _legacyGold.withValues(alpha: 0.62),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({required this.onReject, required this.onAccept});

  final VoidCallback onReject;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 46),
      color: _legacyPanel,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: onReject, child: const Text('拒绝')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(onPressed: onAccept, child: const Text('接受')),
          ),
        ],
      ),
    );
  }
}

class _FakePublicProfile {
  const _FakePublicProfile({
    required this.displayName,
    required this.nickname,
    required this.signature,
    required this.isMale,
    required this.verified,
  });

  factory _FakePublicProfile.forRef(String ref) {
    return switch (ref) {
      'contact-alice' => const _FakePublicProfile(
        displayName: '艾琳',
        nickname: 'Alice',
        signature: '愿每一次相遇都有好心情',
        isMale: false,
        verified: true,
      ),
      'contact-lucas' => const _FakePublicProfile(
        displayName: '卡座搭子',
        nickname: 'Lucas',
        signature: '周末一起听现场',
        isMale: true,
        verified: false,
      ),
      'contact-zhou' => const _FakePublicProfile(
        displayName: '周末组局官',
        nickname: '周末组局官',
        signature: '发现同城好玩的局',
        isMale: true,
        verified: true,
      ),
      _ => const _FakePublicProfile(
        displayName: '晨曦',
        nickname: '晨曦',
        signature: '保持热爱，奔赴山海',
        isMale: false,
        verified: true,
      ),
    };
  }

  final String displayName;
  final String nickname;
  final String signature;
  final bool isMale;
  final bool verified;
}
