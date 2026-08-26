import 'package:flutter/material.dart';

import 'legacy_club_components.dart';

class VipPartyPage extends StatefulWidget {
  const VipPartyPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<VipPartyPage> createState() => _VipPartyPageState();
}

class _VipPartyPageState extends State<VipPartyPage> {
  int _selectedDate = 0;
  int? _expandedIndex;

  static const _parties = [
    _Party('V8', '星光香槟套餐', '688', 6, 8),
    _Party('V6', '微醺派对套餐', '488', 4, 6),
  ];

  @override
  Widget build(BuildContext context) {
    return LegacyClubScaffold(
      title: 'VIP组局',
      onBack: widget.onBack,
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
                  onPressed: () => showFakeResult(context, '已打开新卡座配置'),
                ),
              ],
            ),
          ),
          for (var index = 0; index < _parties.length; index++) ...[
            const SizedBox(height: 14),
            _PartyCard(
              party: _parties[index],
              expanded: _expandedIndex == index,
              onTap: () => setState(
                () => _expandedIndex = _expandedIndex == index ? null : index,
              ),
              onInvite: (slot) =>
                  showFakeResult(context, '已生成第${slot + 1}个位置的邀请'),
            ),
          ],
          const SizedBox(height: 22),
          const Text(
            '规则：【组局玩】由开台会员先预定卡座和酒水套餐，可设置参加人数，并选择公开AA凑人数或邀请制模式。局长可维护组局成员，但所有费用和赔付在本阶段均为 Fake。\n\n请注意穿着精致、文明饮酒并尊重同桌会员。',
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
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({
    required this.party,
    required this.expanded,
    required this.onTap,
    required this.onInvite,
  });

  final _Party party;
  final bool expanded;
  final VoidCallback onTap;
  final ValueChanged<int> onInvite;

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
                                    color: index < party.filled
                                        ? legacyPink
                                        : const Color(0x33FBAFDA),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Icon(
                                    index.isEven ? Icons.male : Icons.female,
                                    color: const Color(0xAA3A1830),
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
                                Image.asset(
                                  'assets/legacy/home/qrcode2.png',
                                  width: 36,
                                  height: 36,
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
              color: legacyMagenta,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Column(
                children: List.generate(
                  party.total,
                  (index) => Container(
                    height: 58,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x44470F24)),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: const Color(0x55FBAFDA),
                          child: Icon(
                            index.isEven ? Icons.male : Icons.female,
                            color: legacyPink,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            index == 0
                                ? '青铜（局长）'
                                : index < party.filled
                                ? '已加入会员'
                                : '空置',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (index == 0)
                          const Text('局长', style: TextStyle(color: legacyPink))
                        else if (index >= party.filled)
                          LegacyClubButton(
                            label: '邀请',
                            light: true,
                            onPressed: () => onInvite(index),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Party {
  const _Party(this.table, this.name, this.price, this.filled, this.total);

  final String table;
  final String name;
  final String price;
  final int filled;
  final int total;
}
