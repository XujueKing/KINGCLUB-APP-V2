import 'package:flutter/material.dart';

import 'aa_mock_models.dart';
import 'aa_package_detail_page.dart';
import 'legacy_club_components.dart';

enum AaLandingScenario {
  available,
  pendingPayment,
  confirmed,
  soldOut,
  offline,
  noRecommendation,
}

class AaReservationsPage extends StatefulWidget {
  const AaReservationsPage({
    super.key,
    required this.onBack,
    this.onSessionResetRequested,
    this.onOpenAdmissionTicket,
  });

  final VoidCallback onBack;
  final VoidCallback? onSessionResetRequested;
  final VoidCallback? onOpenAdmissionTicket;

  @override
  State<AaReservationsPage> createState() => _AaReservationsPageState();
}

class _AaReservationsPageState extends State<AaReservationsPage> {
  int _selectedDate = 0;
  bool _opening = false;
  AaLandingScenario _scenario = AaLandingScenario.available;

  @override
  Widget build(BuildContext context) {
    final date = LegacyDateStrip.dates[_selectedDate].$2;
    return LegacyClubScaffold(
      title: '一起玩AA预定',
      onBack: widget.onBack,
      showMockLabel: false,
      onTitleLongPress: _showScenarioSheet,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
        children: [
          LegacyDateStrip(
            selectedIndex: _selectedDate,
            onSelected: (value) => setState(() => _selectedDate = value),
          ),
          const SizedBox(height: 18),
          if (_scenario == AaLandingScenario.offline)
            _OfflineBanner(onRefresh: _restoreAvailable),
          _ReservationStatusCard(
            scenario: _scenario,
            date: date,
            onRandom: () => _openPackage(aaMockPackages.first),
            onAction: _showExistingReservationResult,
          ),
          const SizedBox(height: 18),
          const Text(
            '预定规则：【一起玩】是会员加入随机配对局，消费为AA制套餐。预定好后凭入场凭证到店，请注意穿着精致、文明饮酒并尊重同桌会员。当前页面使用本地模拟套餐，最终价格和规则以确认页为准。',
            style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 12,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in aaMockPackages) ...[
            _PackageCard(
              item: item,
              scenario: _scenario,
              onTap: () => _openPackage(item),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 18),
          const Center(
            child: Text(
              '一个会员只能预定自己一人的座位。\n营业时间：20:30-04:00',
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

  Future<void> _openPackage(AaMockPackage item) async {
    if (_opening ||
        !item.available ||
        (_scenario != AaLandingScenario.available &&
            _scenario != AaLandingScenario.noRecommendation)) {
      return;
    }
    setState(() => _opening = true);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AaPackageDetailPage(
          package: item,
          serviceDate: LegacyDateStrip.dates[_selectedDate].$2,
          onSessionResetRequested: widget.onSessionResetRequested,
        ),
      ),
    );
    if (mounted) setState(() => _opening = false);
  }

  void _restoreAvailable() {
    setState(() => _scenario = AaLandingScenario.available);
    showFakeResult(context, '已恢复默认可订状态');
  }

  void _showExistingReservationResult() {
    if (_scenario == AaLandingScenario.confirmed &&
        widget.onOpenAdmissionTicket != null) {
      widget.onOpenAdmissionTicket!();
      return;
    }
    final message = switch (_scenario) {
      AaLandingScenario.pendingPayment => '已找到待支付预订，真实支付模块尚未接入',
      AaLandingScenario.confirmed => '已找到确认预订',
      _ => '当前没有已有预订',
    };
    showFakeResult(context, message);
  }

  Future<void> _showScenarioSheet() async {
    final selected = await showModalBottomSheet<AaLandingScenario>(
      context: context,
      backgroundColor: const Color(0xFF1A1511),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'AA 页面 Fake 状态',
                style: TextStyle(color: legacyGold, fontSize: 16),
              ),
            ),
            for (final option in AaLandingScenario.values)
              ListTile(
                key: ValueKey('aa-scenario-${option.name}'),
                title: Text(
                  _scenarioLabel(option),
                  style: const TextStyle(color: Color(0xFFD8C8B8)),
                ),
                trailing: Icon(
                  option == _scenario
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: option == _scenario
                      ? legacyPink
                      : const Color(0x668E7E70),
                ),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _scenario = selected);
  }

  String _scenarioLabel(AaLandingScenario value) => switch (value) {
    AaLandingScenario.available => '正常可订',
    AaLandingScenario.pendingPayment => '已有待支付预订',
    AaLandingScenario.confirmed => '已有确认预订',
    AaLandingScenario.soldOut => '当日售罄',
    AaLandingScenario.offline => '离线快照',
    AaLandingScenario.noRecommendation => '无可推荐套餐',
  };
}

class _ReservationStatusCard extends StatelessWidget {
  const _ReservationStatusCard({
    required this.scenario,
    required this.date,
    required this.onRandom,
    required this.onAction,
  });

  final AaLandingScenario scenario;
  final String date;
  final VoidCallback onRandom;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    if (scenario == AaLandingScenario.pendingPayment ||
        scenario == AaLandingScenario.confirmed) {
      final pending = scenario == AaLandingScenario.pendingPayment;
      return Container(
        key: ValueKey(pending ? 'aa-pending-card' : 'aa-confirmed-card'),
        constraints: const BoxConstraints(minHeight: 122),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: pending ? const Color(0xFF281B10) : const Color(0xFF360521),
          border: Border.all(
            color: pending ? const Color(0x887D684F) : const Color(0x88AD016A),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              pending ? Icons.schedule_rounded : Icons.verified_rounded,
              color: pending ? legacyGold : legacyPink,
              size: 34,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pending ? '已有待支付预订' : 'AA预订已确认',
                    style: TextStyle(
                      color: pending ? legacyGold : legacyPink,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    pending
                        ? '$date · 微醺畅饮套餐\n席位还剩 09:42'
                        : '$date · 微醺畅饮套餐\n20:30 后凭入场凭证核验',
                    style: const TextStyle(
                      color: Color(0xAFFFFFFF),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            LegacyClubButton(
              label: pending ? '继续支付' : '查看凭证',
              light: !pending,
              onPressed: onAction,
            ),
          ],
        ),
      );
    }

    final soldOut = scenario == AaLandingScenario.soldOut;
    final offline = scenario == AaLandingScenario.offline;
    final noRecommendation = scenario == AaLandingScenario.noRecommendation;
    final unavailable = soldOut || offline;
    return Container(
      key: ValueKey(soldOut ? 'aa-sold-out-card' : 'aa-available-card'),
      height: 122,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0x33C9B69E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            soldOut
                ? Icons.event_busy_rounded
                : offline
                ? Icons.cloud_off_rounded
                : Icons.cancel_outlined,
            color: legacyGold,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              soldOut
                  ? '$date 当日座位已售罄'
                  : offline
                  ? '$date 离线快照不可预订'
                  : '$date 还未预订AA座位',
              style: const TextStyle(color: legacyGold, fontSize: 13),
            ),
          ),
          LegacyClubButton(
            label: soldOut
                ? '已售罄'
                : offline
                ? '离线'
                : noRecommendation
                ? '暂无推荐'
                : '一键随机选座',
            onPressed: unavailable || noRecommendation ? null : onRandom,
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('aa-offline-banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF241E18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: legacyGold, size: 18),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              '当前为离线快照，仅可查看套餐',
              style: TextStyle(color: legacyGold, fontSize: 12),
            ),
          ),
          TextButton(
            key: const ValueKey('aa-offline-refresh'),
            onPressed: onRefresh,
            child: const Text('刷新', style: TextStyle(color: legacyPink)),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.item,
    required this.scenario,
    required this.onTap,
  });

  final AaMockPackage item;
  final AaLandingScenario scenario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final usable =
        item.available &&
        (scenario == AaLandingScenario.available ||
            scenario == AaLandingScenario.noRecommendation);
    final foreground = usable ? legacyGold : const Color(0x776F6258);
    final buttonLabel = switch (scenario) {
      AaLandingScenario.pendingPayment || AaLandingScenario.confirmed => '已有预订',
      AaLandingScenario.soldOut => '售罄',
      AaLandingScenario.offline => '离线',
      AaLandingScenario.noRecommendation => item.available ? '加入' : '售罄',
      AaLandingScenario.available => item.available ? '加入' : '售罄',
    };
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: usable ? const Color(0x55C9B69E) : const Color(0x88FFFFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.weekend_rounded, color: foreground, size: 36),
                Text(
                  '卡座 ${item.remaining}',
                  style: TextStyle(color: foreground, fontSize: 10),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.ruleSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: usable
                        ? const Color(0x99FFFFFF)
                        : const Color(0x66332222),
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
                '￥${item.priceYuan}/人',
                style: TextStyle(color: foreground, fontSize: 12),
              ),
              const SizedBox(height: 5),
              LegacyClubButton(
                label: buttonLabel,
                onPressed: usable ? onTap : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
