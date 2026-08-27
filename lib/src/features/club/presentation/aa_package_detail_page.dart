import 'package:flutter/material.dart';

import 'aa_mock_models.dart';
import 'aa_order_confirmation_page.dart';
import 'legacy_club_components.dart';

enum AaPackageScenario { ready, priceUpdated, soldOut }

class AaPackageDetailPage extends StatefulWidget {
  const AaPackageDetailPage({
    super.key,
    required this.package,
    required this.serviceDate,
    this.onSessionResetRequested,
  });

  final AaMockPackage package;
  final String serviceDate;
  final VoidCallback? onSessionResetRequested;

  @override
  State<AaPackageDetailPage> createState() => _AaPackageDetailPageState();
}

class _AaPackageDetailPageState extends State<AaPackageDetailPage> {
  AaPackageScenario _scenario = AaPackageScenario.ready;
  bool _updatedPriceAcknowledged = false;

  int get _displayPriceMinor =>
      widget.package.priceMinor +
      (_scenario == AaPackageScenario.priceUpdated ? 2000 : 0);

  AaMockPackage get _displayPackage => widget.package.copyWith(
    priceMinor: _displayPriceMinor,
    available: _scenario != AaPackageScenario.soldOut,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.56),
            radius: .9,
            colors: [Color(0xEF252018), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _LegacyHeader(
                title: 'POSITIONING CARD',
                onBack: () => Navigator.pop(context),
                onTitleLongPress: _showScenarioSheet,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.weekend_rounded,
                            size: 54,
                            color: legacyPink,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${widget.package.seat} 卡座',
                            style: const TextStyle(
                              color: legacyPink,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${widget.serviceDate} 20:30-04:00',
                        style: const TextStyle(color: legacyPink, fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 188,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0x441A1510),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x337B6650)),
                        ),
                        padding: const EdgeInsets.all(28),
                        child: Image.asset(
                          'assets/legacy/home/logo_2.png',
                          fit: BoxFit.contain,
                          semanticLabel: 'King Club 套餐品牌图',
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.local_bar_rounded,
                            color: legacyGold,
                            size: 76,
                          ),
                        ),
                      ),
                      if (_scenario != AaPackageScenario.ready) ...[
                        const SizedBox(height: 14),
                        _PackageStateBanner(
                          scenario: _scenario,
                          oldPriceMinor: widget.package.priceMinor,
                          newPriceMinor: _displayPriceMinor,
                          priceAcknowledged: _updatedPriceAcknowledged,
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        widget.package.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          for (final item in widget.package.contents)
                            SizedBox(
                              width: 142,
                              child: Text(
                                item,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        '套餐建议价：${formatAaMoney(_displayPriceMinor)} / 本人1席',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '系统随机分桌，最终套餐、活动优惠与可用抵扣以确认订单页的最新 Fake 报价为准。本页尚未锁定真实库存。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _PackageBottomBar(
                priceMinor: _displayPriceMinor,
                scenario: _scenario,
                priceAcknowledged: _updatedPriceAcknowledged,
                onPressed: _handleBottomAction,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBottomAction() {
    if (_scenario == AaPackageScenario.soldOut) {
      Navigator.pop(context);
      return;
    }
    if (_scenario == AaPackageScenario.priceUpdated &&
        !_updatedPriceAcknowledged) {
      setState(() => _updatedPriceAcknowledged = true);
      showFakeResult(context, '已确认更新后的价格，再次点击抢订进入确认订单');
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AaOrderConfirmationPage(
          package: _displayPackage,
          serviceDate: widget.serviceDate,
          onSessionResetRequested: widget.onSessionResetRequested,
        ),
      ),
    );
  }

  Future<void> _showScenarioSheet() async {
    final selected = await showModalBottomSheet<AaPackageScenario>(
      context: context,
      backgroundColor: const Color(0xFF1A1511),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '套餐详情 Fake 状态',
                style: TextStyle(color: legacyGold, fontSize: 16),
              ),
            ),
            for (final option in AaPackageScenario.values)
              ListTile(
                key: ValueKey('aa-package-scenario-${option.name}'),
                title: Text(switch (option) {
                  AaPackageScenario.ready => '正常可订',
                  AaPackageScenario.priceUpdated => '刷新后价格变化',
                  AaPackageScenario.soldOut => '刷新后售罄',
                }, style: const TextStyle(color: Color(0xFFD8C8B8))),
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
    if (selected != null && mounted) {
      setState(() {
        _scenario = selected;
        _updatedPriceAcknowledged = false;
      });
    }
  }
}

class _PackageStateBanner extends StatelessWidget {
  const _PackageStateBanner({
    required this.scenario,
    required this.oldPriceMinor,
    required this.newPriceMinor,
    required this.priceAcknowledged,
  });

  final AaPackageScenario scenario;
  final int oldPriceMinor;
  final int newPriceMinor;
  final bool priceAcknowledged;

  @override
  Widget build(BuildContext context) {
    final soldOut = scenario == AaPackageScenario.soldOut;
    return Container(
      key: ValueKey(
        soldOut ? 'aa-package-sold-out' : 'aa-package-price-updated',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: soldOut ? const Color(0xFF28221D) : const Color(0xFF360521),
        border: Border.all(
          color: soldOut ? const Color(0x887D684F) : const Color(0x88FBAFDA),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            soldOut ? Icons.event_busy_rounded : Icons.price_change_rounded,
            color: soldOut ? legacyGold : legacyPink,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              soldOut
                  ? '刷新后该套餐已售罄，请返回列表选择其他套餐'
                  : '价格由 ${formatAaMoney(oldPriceMinor)} 更新为 ${formatAaMoney(newPriceMinor)}\n${priceAcknowledged ? '新价格已确认，可继续抢订' : '请先确认新价格，再继续抢订'}',
              style: TextStyle(
                color: soldOut ? legacyGold : legacyPink,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageBottomBar extends StatelessWidget {
  const _PackageBottomBar({
    required this.priceMinor,
    required this.scenario,
    required this.priceAcknowledged,
    required this.onPressed,
  });

  final int priceMinor;
  final AaPackageScenario scenario;
  final bool priceAcknowledged;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final soldOut = scenario == AaPackageScenario.soldOut;
    final priceParts = (priceMinor / 100).toStringAsFixed(2).split('.');
    final buttonLabel = soldOut
        ? '返回列表'
        : scenario == AaPackageScenario.priceUpdated && !priceAcknowledged
        ? '确认新价格'
        : '抢订';
    final buttonWidth = soldOut
        ? 118.0
        : scenario == AaPackageScenario.priceUpdated && !priceAcknowledged
        ? 138.0
        : 104.0;
    return Container(
      height: 102,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 12, 18, 12),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.centerLeft,
          radius: 1.5,
          colors: [Colors.white, legacyGold],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: soldOut ? '' : '￥',
                        style: const TextStyle(fontSize: 16),
                      ),
                      TextSpan(
                        text: soldOut ? '该套餐已售罄' : priceParts.first,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: soldOut ? '' : '.${priceParts.last} 元',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                  style: const TextStyle(color: Color(0xFF42372B)),
                ),
                Text(
                  soldOut ? '请返回列表刷新其他套餐' : '以确认页最新报价为准',
                  style: const TextStyle(
                    color: Color(0xFF5C4E3E),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            key: const ValueKey('aa-package-bottom-action'),
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: legacyPink,
              foregroundColor: const Color(0xFF33261D),
              minimumSize: Size(buttonWidth, 48),
              maximumSize: Size(buttonWidth, 48),
              fixedSize: Size(buttonWidth, 48),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _LegacyHeader extends StatelessWidget {
  const _LegacyHeader({
    required this.title,
    required this.onBack,
    required this.onTitleLongPress,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 6,
            child: IconButton(
              tooltip: '返回',
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: legacyGold,
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('aa-package-title'),
            onLongPress: onTitleLongPress,
            child: Text(
              title,
              style: const TextStyle(
                color: legacyGold,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: .5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
