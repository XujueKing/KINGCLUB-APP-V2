import 'package:flutter/material.dart';

import 'legacy_club_components.dart';

class AaReservationsPage extends StatefulWidget {
  const AaReservationsPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AaReservationsPage> createState() => _AaReservationsPageState();
}

class _AaReservationsPageState extends State<AaReservationsPage> {
  int _selectedDate = 0;

  static const _packages = [
    _AaPackage('A6', '微醺畅饮套餐', '不限制', '35岁以内', '4/6', '198', true),
    _AaPackage('A8', '经典派对套餐', '80分以上', '32岁以内', '6/8', '288', true),
    _AaPackage('A10', '限定香槟套餐', '85分以上', '30岁以内', '10/10', '388', false),
  ];

  @override
  Widget build(BuildContext context) {
    return LegacyClubScaffold(
      title: '一起玩AA预定',
      onBack: widget.onBack,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
        children: [
          LegacyDateStrip(
            selectedIndex: _selectedDate,
            onSelected: (value) => setState(() => _selectedDate = value),
          ),
          const SizedBox(height: 18),
          _NoReservationCard(
            date: LegacyDateStrip.dates[_selectedDate].$2,
            onRandom: () => _showPackage(_packages.first),
          ),
          const SizedBox(height: 18),
          const Text(
            '预定规则：【一起玩】是会员加入到随机配对局，每一组卡座对应的男女比例为 1:1，消费都为AA制套餐。预定好后凭二维码入场，请注意穿着精致、文明饮酒并尊重同桌会员。',
            style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 12,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in _packages) ...[
            _PackageCard(item: item, onTap: () => _showPackage(item)),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 18),
          const Center(
            child: Text(
              '一个会员只能预定自己一人的座位，预定后不得退座。\n营业时间：20:30-04:00',
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

  Future<void> _showPackage(_AaPackage item) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF18130F),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  color: legacyGold,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '卡座 ${item.seat} · 当前 ${item.remaining}\n卡颜：${item.beauty} · 卡年龄：${item.age}\n￥${item.price}/人',
                style: const TextStyle(color: Color(0xCCFFFFFF), height: 1.7),
              ),
              const SizedBox(height: 18),
              LegacyClubButton(
                label: item.available ? '模拟加入' : '已经售罄',
                light: true,
                onPressed: item.available
                    ? () {
                        Navigator.pop(sheetContext);
                        showFakeResult(context, '已选择${item.name}');
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoReservationCard extends StatelessWidget {
  const _NoReservationCard({required this.date, required this.onRandom});

  final String date;
  final VoidCallback onRandom;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 122,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0x33C9B69E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: legacyGold, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$date 还未预订AA座位',
              style: const TextStyle(color: legacyGold, fontSize: 13),
            ),
          ),
          LegacyClubButton(label: '一键随机选座', onPressed: onRandom),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.item, required this.onTap});

  final _AaPackage item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: item.available
            ? const Color(0x55C9B69E)
            : const Color(0x55FFFFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.weekend_rounded,
                  color: item.available ? legacyGold : Colors.black38,
                  size: 36,
                ),
                Text(
                  '卡座 ${item.remaining}',
                  style: const TextStyle(
                    color: Color(0xAAFFFFFF),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: legacyGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '卡颜：${item.beauty}\n卡年龄：${item.age}',
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '￥${item.price}/人',
                style: const TextStyle(color: legacyGold, fontSize: 12),
              ),
              const SizedBox(height: 5),
              LegacyClubButton(
                label: item.available ? '加入' : '售罄',
                onPressed: item.available ? onTap : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AaPackage {
  const _AaPackage(
    this.seat,
    this.name,
    this.beauty,
    this.age,
    this.remaining,
    this.price,
    this.available,
  );

  final String seat;
  final String name;
  final String beauty;
  final String age;
  final String remaining;
  final String price;
  final bool available;
}
