import 'package:flutter/material.dart';

import 'legacy_club_components.dart';

enum VipPartyScenario { ready, empty, offline, full, hostSponsored }

enum _PartyRole { viewer, host }

class VipPartyPage extends StatefulWidget {
  const VipPartyPage({
    super.key,
    required this.onBack,
    required this.onCreateParty,
    required this.onManageParty,
    required this.onOpenTicket,
  });

  final VoidCallback onBack;
  final ValueChanged<String> onCreateParty;
  final VoidCallback onManageParty;
  final VoidCallback onOpenTicket;

  @override
  State<VipPartyPage> createState() => _VipPartyPageState();
}

class _VipPartyPageState extends State<VipPartyPage> {
  int _selectedDate = 0;
  int? _expandedIndex;
  VipPartyScenario _scenario = VipPartyScenario.ready;
  final Set<int> _joinedParties = <int>{};

  static const _parties = [
    _Party('V8', '星光香槟套餐', '688', 6, 8, _PartyRole.host),
    _Party('V6', '微醺派对套餐', '488', 4, 6, _PartyRole.viewer),
  ];

  bool get _offline => _scenario == VipPartyScenario.offline;

  bool get _empty => _scenario == VipPartyScenario.empty;

  @override
  Widget build(BuildContext context) {
    return LegacyClubScaffold(
      title: 'VIP组局',
      onBack: widget.onBack,
      showMockLabel: false,
      onTitleLongPress: _showScenarioSheet,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
        children: [
          LegacyDateStrip(
            selectedIndex: _selectedDate,
            onSelected: (value) => setState(() {
              _selectedDate = value;
              _expandedIndex = null;
            }),
          ),
          const SizedBox(height: 18),
          if (_offline) const _VipStatusBanner.offline(),
          Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0x33C9B69E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${LegacyDateStrip.dates[_selectedDate].$2} 预选卡座和套餐',
                    style: const TextStyle(color: legacyGold, fontSize: 13),
                  ),
                ),
                LegacyClubButton(
                  label: '预定一个新卡座',
                  onPressed: _offline
                      ? null
                      : () => widget.onCreateParty(
                          LegacyDateStrip.dates[_selectedDate].$2,
                        ),
                ),
              ],
            ),
          ),
          if (_empty) const _VipEmptyState(),
          for (var index = 0; !_empty && index < _parties.length; index++) ...[
            const SizedBox(height: 14),
            _PartyCard(
              party: _parties[index],
              filled: _filledFor(index),
              expanded: _expandedIndex == index,
              onTap: () => setState(
                () => _expandedIndex = _expandedIndex == index ? null : index,
              ),
              actionsEnabled: !_offline,
              joined: _joinedParties.contains(index),
              onInvite: (slot) =>
                  showFakeResult(context, '已向第${slot + 1}个位置发送单人邀请'),
              onJoin: () => _confirmJoin(index),
              onTicket: widget.onOpenTicket,
              onManage: widget.onManageParty,
            ),
          ],
          const SizedBox(height: 22),
          const Text(
            '规则：【组局玩】由开台会员先预定卡座和酒水套餐，可设置参加人数，并选择公开AA凑人数或邀请制模式。局长可维护组局成员；费用、赔付与退款以提交订单时确认的规则为准。\n\n请注意穿着精致、文明饮酒并尊重同桌会员。',
            style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 12,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '会员预定VIP沙发卡座，预定后不得退座。\n营业时间：20:30-04:00',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0x66FFFFFF),
                fontSize: 12,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _filledFor(int index) {
    final party = _parties[index];
    if (_scenario == VipPartyScenario.full) return party.total;
    return (party.filled + (_joinedParties.contains(index) ? 1 : 0)).clamp(
      0,
      party.total,
    );
  }

  Future<void> _confirmJoin(int index) async {
    if (_offline || _joinedParties.contains(index)) return;
    final party = _parties[index];
    if (_filledFor(index) >= party.total) {
      showFakeResult(context, '当前组局已满员');
      return;
    }
    final sponsored = _scenario == VipPartyScenario.hostSponsored;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1511),
        title: Text(sponsored ? '确认免费加入' : '确认申请加入'),
        content: Text(
          '${party.table} · ${party.name}\n'
          '${sponsored ? '局长请客，本人应付 ¥0.00' : '成员各付 ¥${party.price}.00'}\n\n'
          '请文明饮酒、尊重同桌会员；确认后将占用一个席位。',
          style: const TextStyle(color: Color(0xFFD8C8B8), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            key: const ValueKey('vip-confirm-join'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认加入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _joinedParties.add(index));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1511),
        title: Text(sponsored ? '加入成功' : '待支付订单已生成'),
        content: Text(
          sponsored
              ? '席位已确认，本次实付 ¥0.00，无需支付。'
              : '席位将保留 10 分钟，待支付 ¥${party.price}.00，请在有效期内完成支付。',
          style: const TextStyle(color: Color(0xFFD8C8B8), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了', style: TextStyle(color: legacyGold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showScenarioSheet() async {
    final selected = await showModalBottomSheet<VipPartyScenario>(
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
              const Text(
                'VIP 组局 Fake 状态',
                style: TextStyle(color: legacyGold, fontSize: 16),
              ),
              for (final option in VipPartyScenario.values)
                ListTile(
                  key: ValueKey('vip-scenario-${option.name}'),
                  title: Text(switch (option) {
                    VipPartyScenario.ready => '正常组局',
                    VipPartyScenario.empty => '当日暂无组局',
                    VipPartyScenario.offline => '离线只读',
                    VipPartyScenario.full => '全部满员',
                    VipPartyScenario.hostSponsored => '局长请客 / 0元加入',
                  }, style: const TextStyle(color: Color(0xFFD8C8B8))),
                  trailing: Icon(
                    option == _scenario
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: option == _scenario
                        ? legacyGold
                        : const Color(0xFF6E604F),
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
      _expandedIndex = null;
      _joinedParties.clear();
    });
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({
    required this.party,
    required this.filled,
    required this.expanded,
    required this.actionsEnabled,
    required this.joined,
    required this.onTap,
    required this.onInvite,
    required this.onJoin,
    required this.onTicket,
    required this.onManage,
  });

  final _Party party;
  final int filled;
  final bool expanded;
  final bool actionsEnabled;
  final bool joined;
  final VoidCallback onTap;
  final ValueChanged<int> onInvite;
  final VoidCallback onJoin;
  final VoidCallback onTicket;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Material(
            color: const Color(0x22202020),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 122,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 124,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              party.table,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(
                              '2026.08.26 21:00-04:00',
                              style: TextStyle(color: legacyGold, fontSize: 9),
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: legacyGold,
                                  size: 14,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'KINGCLUB',
                                  style: TextStyle(
                                    color: legacyGold,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 3,
                              runSpacing: 3,
                              children: List.generate(
                                party.total,
                                (index) => Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: index < filled
                                        ? legacyGold
                                        : const Color(0xFF332B22),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Icon(
                                    index.isEven ? Icons.male : Icons.female,
                                    color: index < filled
                                        ? const Color(0xFF21180F)
                                        : const Color(0xFF8D7B65),
                                    size: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              party.name,
                              style: const TextStyle(
                                color: legacyGold,
                                fontSize: 12,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '￥${party.price}',
                                  style: const TextStyle(
                                    color: legacyGold,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Semantics(
                                  button: party.role == _PartyRole.host,
                                  label: party.role == _PartyRole.host
                                      ? '打开入场凭证'
                                      : '入场凭证仅成员可用',
                                  child: GestureDetector(
                                    key: ValueKey('vip-ticket-${party.table}'),
                                    onTap:
                                        actionsEnabled &&
                                            party.role == _PartyRole.host
                                        ? onTicket
                                        : null,
                                    child: Opacity(
                                      opacity: party.role == _PartyRole.host
                                          ? 1
                                          : .45,
                                      child: Image.asset(
                                        'assets/legacy/home/qrcode2.png',
                                        width: 36,
                                        height: 36,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              color: const Color(0xFF15110E),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Column(
                children: [
                  if (party.role == _PartyRole.host)
                    Container(
                      height: 52,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x665C4C3A)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '局长可管理招募、邀请和未付款占位',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          LegacyClubButton(
                            label: '管理组局',
                            goldFill: true,
                            onPressed: actionsEnabled ? onManage : null,
                          ),
                        ],
                      ),
                    ),
                  ...List.generate(
                    party.total,
                    (index) => Container(
                      height: 58,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x665C4C3A)),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: const Color(0xFF2D251D),
                            child: Icon(
                              index.isEven ? Icons.male : Icons.female,
                              color: legacyGold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              index == 0 && party.role == _PartyRole.host
                                  ? '青铜（局长）'
                                  : joined && index == filled - 1
                                  ? '我（已占位）'
                                  : index < filled
                                  ? '已加入会员'
                                  : '空置',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (index == 0 && party.role == _PartyRole.host)
                            const Text(
                              '局长',
                              style: TextStyle(color: legacyGold),
                            )
                          else if (index >= filled &&
                              party.role == _PartyRole.host)
                            LegacyClubButton(
                              label: '邀请',
                              goldFill: true,
                              onPressed: actionsEnabled
                                  ? () => onInvite(index)
                                  : null,
                            ),
                          if (index == filled &&
                              party.role == _PartyRole.viewer &&
                              !joined)
                            LegacyClubButton(
                              label: filled >= party.total ? '已满员' : '申请加入',
                              goldFill: true,
                              onPressed: actionsEnabled && filled < party.total
                                  ? onJoin
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Party {
  const _Party(
    this.table,
    this.name,
    this.price,
    this.filled,
    this.total,
    this.role,
  );

  final String table;
  final String name;
  final String price;
  final int filled;
  final int total;
  final _PartyRole role;
}

class _VipStatusBanner extends StatelessWidget {
  const _VipStatusBanner.offline();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('vip-offline-banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0x33252018),
        border: Border.all(color: const Color(0x66C9B69E)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: legacyGold, size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '当前离线，正在显示缓存组局；只能查看，不能创建、邀请或加入。',
              style: TextStyle(color: legacyGold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _VipEmptyState extends StatelessWidget {
  const _VipEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('vip-empty-state'),
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.event_seat_outlined, color: Color(0x88C9B69E), size: 48),
          SizedBox(height: 14),
          Text(
            '当日暂无公开组局',
            style: TextStyle(
              color: legacyGold,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '可以切换营业日，或预定一个新卡座。',
            style: TextStyle(color: Color(0x88FFFFFF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
