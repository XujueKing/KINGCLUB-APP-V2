import 'package:flutter/material.dart';

import 'legacy_club_components.dart';

enum VipPartyManagementScenario {
  ready,
  versionConflict,
  offline,
  locked,
  permissionLost,
}

class VipPartyManagementPage extends StatefulWidget {
  const VipPartyManagementPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<VipPartyManagementPage> createState() => _VipPartyManagementPageState();
}

class _VipPartyManagementPageState extends State<VipPartyManagementPage> {
  int _tab = 0;
  bool _recruiting = true;
  bool _hasInvitation = true;
  bool _hasUnpaidHold = true;
  bool _submitting = false;
  String? _newInvitee;
  VipPartyManagementScenario _scenario = VipPartyManagementScenario.ready;

  bool get _readOnly =>
      _scenario == VipPartyManagementScenario.offline ||
      _scenario == VipPartyManagementScenario.locked ||
      _scenario == VipPartyManagementScenario.permissionLost;

  @override
  Widget build(BuildContext context) {
    return LegacyClubScaffold(
      title: 'V8 卡座',
      onBack: widget.onBack,
      showMockLabel: false,
      onTitleLongPress: _showScenarioSheet,
      child: Column(
        children: [
          if (_scenario != VipPartyManagementScenario.ready)
            _StatusBanner(scenario: _scenario),
          _LegacyTabs(
            selected: _tab,
            onSelected: (value) => setState(() => _tab = value),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [_buildOverview(), _buildBill(), _buildMembers()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    if (_scenario == VipPartyManagementScenario.permissionLost) {
      return const _PermissionLostView();
    }
    return ListView(
      key: const ValueKey('vip-manage-overview'),
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 40),
      children: [
        const _TableOverview(),
        const SizedBox(height: 8),
        const _SpendSummary(),
        _InfoRow(
          label: '招募状态',
          value: _recruiting ? '对外招募中' : '已关闭招募',
          valueColor: _recruiting ? const Color(0xFF07C160) : legacyGold,
          trailing: Switch(
            key: const ValueKey('vip-recruitment-switch'),
            value: _recruiting,
            onChanged: _readOnly || _submitting ? null : _confirmRecruitment,
          ),
        ),
        const _InfoRow(label: '卡座单号', value: 'KC202608270088'),
        const _HostRow(),
        const _InfoRow(label: '费用方式', value: '成员各付'),
        const _InfoRow(label: '可见范围', value: '公开组局'),
        const _InfoRow(label: '核心配置', value: '已锁定，不可修改'),
        const _InfoRow(label: '下单时间', value: '2026-08-27 11:28'),
      ],
    );
  }

  Widget _buildBill() {
    return ListView(
      key: const ValueKey('vip-manage-bill'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
      children: const [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _BillMetric(label: '数量', value: '1'),
            _BillMetric(label: '合计', value: '¥688.00'),
            _BillMetric(label: '待付', value: '¥172.00', alert: true),
          ],
        ),
        SizedBox(height: 18),
        _BillItem(),
        SizedBox(height: 14),
        Text(
          '本页只展示消费者可见的 Fake 账单摘要。商品确认、服务员分配和追加点单不在本页面范围。',
          style: TextStyle(color: Color(0x66FFFFFF), fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildMembers() {
    if (_scenario == VipPartyManagementScenario.permissionLost) {
      return const _PermissionLostView();
    }
    final rows = <Widget>[
      const _MemberRow(
        name: '青铜',
        subtitle: '已确认 · 局长',
        sex: _MemberSex.male,
        status: '局长',
      ),
      const _MemberRow(
        name: '小鹿',
        subtitle: '已付款 · 20:58',
        sex: _MemberSex.female,
        status: '已确认',
      ),
      if (_hasUnpaidHold)
        _MemberRow(
          key: const ValueKey('vip-unpaid-member'),
          name: '阿哲',
          subtitle: '待付款 · 还剩 08:42',
          sex: _MemberSex.male,
          actionLabel: '释放占位',
          actionKey: const ValueKey('vip-release-hold'),
          enabled: !_readOnly && !_submitting,
          onAction: _confirmReleaseHold,
        ),
      if (_hasInvitation)
        _MemberRow(
          key: const ValueKey('vip-invited-member'),
          name: '安安',
          subtitle: '已邀请 · 等待接受',
          sex: _MemberSex.female,
          actionLabel: '撤销邀请',
          actionKey: const ValueKey('vip-revoke-invite'),
          enabled: !_readOnly && !_submitting,
          onAction: _confirmRevokeInvite,
        ),
      if (_newInvitee != null)
        _MemberRow(
          name: _newInvitee!,
          subtitle: '刚刚邀请 · 等待接受',
          sex: _MemberSex.female,
          actionLabel: '撤销邀请',
          enabled: !_readOnly && !_submitting,
          onAction: _confirmRevokeNewInvite,
        ),
      _MemberRow(
        name: '等待中…',
        subtitle: _recruiting ? '空余席位' : '招募已关闭',
        sex: _MemberSex.empty,
        actionLabel: '邀请',
        actionKey: const ValueKey('vip-invite-friend'),
        lightAction: true,
        enabled: !_readOnly && !_submitting && _recruiting,
        onAction: _inviteFriend,
      ),
      const _MemberRow(name: '等待中…', subtitle: '空余席位', sex: _MemberSex.empty),
    ];
    return Column(
      key: const ValueKey('vip-manage-members'),
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('座位总数：8 位', style: _mutedStyle),
              Text('当前确认：2 位', style: _mutedStyle),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: rows,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRecruitment(bool open) async {
    final confirmed = await _confirm(
      title: open ? '重新开启招募？' : '关闭招募？',
      body: open ? '开启后，符合条件的会员可以继续申请加入。' : '关闭后将保留现有成员和邀请，但不再接受新的公开申请。',
      confirmLabel: open ? '开启招募' : '关闭招募',
    );
    if (confirmed != true || !mounted) return;
    if (_scenario == VipPartyManagementScenario.versionConflict) {
      showFakeResult(context, '组局状态刚刚发生变化，已重新读取最新版本');
      return;
    }
    setState(() {
      _submitting = true;
      _recruiting = open;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _submitting = false);
    showFakeResult(context, open ? '已重新开启招募' : '已关闭招募');
  }

  Future<void> _inviteFriend() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF171310),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择一位 KingClub 好友',
                  style: TextStyle(
                    color: legacyGold,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final friend in const [
              ('林晚', '最近聊天'),
              ('Mia', '互相关注'),
              ('周末', 'KingClub 好友'),
            ])
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x334A90E2),
                  child: Icon(Icons.person, color: legacyGold),
                ),
                title: Text(
                  friend.$1,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  friend.$2,
                  style: const TextStyle(color: Color(0x88FFFFFF)),
                ),
                trailing: const Icon(Icons.chevron_right, color: legacyGold),
                onTap: () => Navigator.pop(sheetContext, friend.$1),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final confirmed = await _confirm(
      title: '邀请 $selected？',
      body: '一次只邀请一位好友。对方接受并完成应付流程后，席位才会变为已确认。',
      confirmLabel: '发送邀请',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _newInvitee = selected);
    showFakeResult(context, '已向 $selected 发送单人邀请');
  }

  Future<void> _confirmRevokeInvite() async {
    if (await _confirm(
              title: '撤销对安安的邀请？',
              body: '对方尚未接受，撤销后该邀请立即失效。',
              confirmLabel: '撤销邀请',
            ) !=
            true ||
        !mounted) {
      return;
    }
    setState(() => _hasInvitation = false);
    showFakeResult(context, '邀请已撤销');
  }

  Future<void> _confirmRevokeNewInvite() async {
    if (await _confirm(
              title: '撤销这条邀请？',
              body: '对方尚未接受，撤销后该邀请立即失效。',
              confirmLabel: '撤销邀请',
            ) !=
            true ||
        !mounted) {
      return;
    }
    setState(() => _newInvitee = null);
    showFakeResult(context, '邀请已撤销');
  }

  Future<void> _confirmReleaseHold() async {
    if (await _confirm(
              title: '释放未付款占位？',
              body: '阿哲尚未完成付款。释放后席位会重新开放，已付款成员不会受到影响。',
              confirmLabel: '释放占位',
            ) !=
            true ||
        !mounted) {
      return;
    }
    setState(() => _hasUnpaidHold = false);
    showFakeResult(context, '未付款占位已释放');
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1511),
        title: Text(title),
        content: Text(
          body,
          style: const TextStyle(color: Color(0xFFD8C8B8), height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _showScenarioSheet() async {
    final selected = await showModalBottomSheet<VipPartyManagementScenario>(
      context: context,
      backgroundColor: const Color(0xFF1A1511),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .72,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  '组局管理 Fake 状态',
                  style: TextStyle(
                    color: legacyGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final option in VipPartyManagementScenario.values)
                ListTile(
                  key: ValueKey('vip-manage-scenario-${option.name}'),
                  title: Text(switch (option) {
                    VipPartyManagementScenario.ready => '正常管理',
                    VipPartyManagementScenario.versionConflict => '版本冲突',
                    VipPartyManagementScenario.offline => '离线只读',
                    VipPartyManagementScenario.locked => '临近活动已锁定',
                    VipPartyManagementScenario.permissionLost => '局长权限失效',
                  }, style: const TextStyle(color: Color(0xFFD8C8B8))),
                  trailing: Icon(
                    option == _scenario
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: option == _scenario ? legacyPink : legacyGold,
                  ),
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scenario = selected;
      _tab = 0;
      _recruiting = true;
      _hasInvitation = true;
      _hasUnpaidHold = true;
      _newInvitee = null;
    });
  }
}

const _mutedStyle = TextStyle(color: Color(0x66FFFFFF), fontSize: 12);

class _LegacyTabs extends StatelessWidget {
  const _LegacyTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['概况', '账单', '成员'];
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = selected == index;
          return Expanded(
            child: InkWell(
              key: ValueKey('vip-manage-tab-$index'),
              onTap: () => onSelected(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0x88FFFFFF),
                      fontSize: active ? 17 : 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 9),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 2,
                    width: 44,
                    color: active
                        ? const Color(0xFFFFB400)
                        : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TableOverview extends StatelessWidget {
  const _TableOverview();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 22),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
    ),
    child: const Row(
      children: [
        SizedBox(
          width: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'V8',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text('星光香槟套餐', style: TextStyle(color: legacyGold, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('订座日期：2026-08-27', style: _mutedStyle),
              SizedBox(height: 7),
              Text('预订人数：4 / 8 人', style: _mutedStyle),
              SizedBox(height: 7),
              Text('最低消费：¥688.00', style: _mutedStyle),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SpendSummary extends StatelessWidget {
  const _SpendSummary();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0x0AFFFFFF),
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: const Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('当前已付 ', style: _mutedStyle),
            Text(
              '¥516.00',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            Text(' / 合计 ¥688.00', style: _mutedStyle),
          ],
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BillMetric(label: '微信支付', value: '344.00'),
            _BillMetric(label: '钱包', value: '172.00'),
            _BillMetric(label: '待付', value: '172.00', alert: true),
          ],
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 62),
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 14),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0x88FFFFFF),
            fontSize: 13,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

class _HostRow extends StatelessWidget {
  const _HostRow();
  @override
  Widget build(BuildContext context) => Container(
    height: 78,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Color(0x332D65F2),
          child: Icon(Icons.person, color: legacyGold),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '青铜（局长）',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text('KingClub 会员', style: _mutedStyle),
            ],
          ),
        ),
        Text('已确认', style: TextStyle(color: Color(0xFF07C160), fontSize: 13)),
      ],
    ),
  );
}

class _BillMetric extends StatelessWidget {
  const _BillMetric({
    required this.label,
    required this.value,
    this.alert = false,
  });
  final String label;
  final String value;
  final bool alert;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: alert ? const Color(0xFFFF7777) : Colors.white,
          fontSize: 15,
        ),
      ),
      const SizedBox(height: 5),
      Text(label, style: _mutedStyle),
    ],
  );
}

class _BillItem extends StatelessWidget {
  const _BillItem();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0x0FFFFFFF),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0x22FFFFFF)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('1', style: TextStyle(color: Colors.white, fontSize: 16)),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '星光香槟套餐 × 1',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('香槟 × 1 · 果盘 × 1 · 软饮 × 6', style: _mutedStyle),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '¥688.00',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              '原价 ¥788.00',
              style: TextStyle(
                color: Color(0x55FFFFFF),
                fontSize: 11,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

enum _MemberSex { male, female, empty }

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.sex,
    this.status,
    this.actionLabel,
    this.actionKey,
    this.lightAction = false,
    this.enabled = true,
    this.onAction,
  });
  final String name;
  final String subtitle;
  final _MemberSex sex;
  final String? status;
  final String? actionLabel;
  final Key? actionKey;
  final bool lightAction;
  final bool enabled;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 82),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    decoration: const BoxDecoration(
      color: Color(0x08FFFFFF),
      border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0x22FFFFFF),
          child: Icon(
            sex == _MemberSex.empty
                ? Icons.person_outline
                : sex == _MemberSex.male
                ? Icons.male
                : Icons.female,
            color: sex == _MemberSex.male
                ? const Color(0xFF75A9FF)
                : sex == _MemberSex.female
                ? legacyPink
                : const Color(0x66FFFFFF),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: sex == _MemberSex.empty
                      ? const Color(0x88FFFFFF)
                      : Colors.white,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 5),
              Text(subtitle, style: _mutedStyle),
            ],
          ),
        ),
        if (status != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: Text(
              status!,
              style: const TextStyle(color: legacyGold, fontSize: 12),
            ),
          ),
        if (actionLabel != null)
          LegacyClubButton(
            key: actionKey,
            label: actionLabel!,
            light: lightAction,
            onPressed: enabled ? onAction : null,
          ),
      ],
    ),
  );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.scenario});
  final VipPartyManagementScenario scenario;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('vip-manage-status-banner'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    color: const Color(0x33252018),
    child: Text(switch (scenario) {
      VipPartyManagementScenario.ready => '',
      VipPartyManagementScenario.versionConflict =>
        '其他端刚刚修改了组局；下一次提交将模拟版本冲突并重读。',
      VipPartyManagementScenario.offline => '当前离线，仅可查看缓存内容，管理动作已禁用。',
      VipPartyManagementScenario.locked => '临近活动，组局已锁定；成员和招募动作暂停。',
      VipPartyManagementScenario.permissionLost => '当前账号已不再拥有局长权限，成员资料已清除。',
    }, style: const TextStyle(color: legacyGold, fontSize: 12, height: 1.4)),
  );
}

class _PermissionLostView extends StatelessWidget {
  const _PermissionLostView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: legacyGold, size: 44),
          SizedBox(height: 16),
          Text(
            '局长管理权限已失效',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '成员与邀请信息已从本页清除，请返回普通组局详情。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0x88FFFFFF), height: 1.5),
          ),
        ],
      ),
    ),
  );
}
