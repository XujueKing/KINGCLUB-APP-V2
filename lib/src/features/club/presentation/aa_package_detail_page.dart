import 'package:flutter/material.dart';

import 'aa_mock_models.dart';
import 'aa_order_confirmation_page.dart';
import 'legacy_club_components.dart';

enum AaPackageScenario { ready, priceUpdated, soldOut }

String _moneyValue(int minor) => (minor / 100).toStringAsFixed(2);

String _legacyFullServiceDate(String serviceDate) => switch (serviceDate) {
  '08.26' => '2026-08-26 周三',
  '08.27' => '2026-08-27 周四',
  '08.28' => '2026-08-28 周五',
  '08.29' => '2026-08-29 周六',
  '08.30' => '2026-08-30 周日',
  '08.31' => '2026-08-31 周一',
  _ => serviceDate,
};

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
                title: '一起玩套餐',
                onBack: () => Navigator.pop(context),
                onTitleLongPress: _showScenarioSheet,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
                  child: Column(
                    children: [
                      const Text(
                        '随机卡座',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '预订时不选号 · 营业日前一天揭晓',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: legacyGold, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_legacyFullServiceDate(widget.serviceDate)} 20:30-04:00',
                        style: const TextStyle(color: legacyGold, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Image.asset(
                        widget.package.posterAsset ??
                            'assets/legacy/aa/package_3880_v1.png',
                        width: 154,
                        height: 254,
                        fit: BoxFit.contain,
                        semanticLabel: '${widget.package.name}套餐海报',
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 154,
                          height: 254,
                          child: Icon(
                            Icons.local_bar_rounded,
                            color: legacyGold,
                            size: 70,
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
                      const SizedBox(height: 8),
                      Text(
                        widget.package.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 5,
                        children: [
                          for (final item in widget.package.contents)
                            SizedBox(
                              width: 146,
                              height: 18,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  item,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Color(0xFF888888),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        '套餐建议价：￥${_moneyValue(widget.package.suggestedPackagePriceMinor ?? _displayPriceMinor)}元/${widget.package.partySize}人',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 11),
                      const _AgePriceGrid(),
                      const SizedBox(height: 6),
                      const Text(
                        '系统自动匹配1:1男女比例会员拼桌\n女神预定后，即赠送 100元 现金券',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _PackageBottomBar(
                priceMinor: _displayPriceMinor,
                originalPriceMinor: widget.package.originalPriceMinor,
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
                      ? legacyGold
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
        color: const Color(0xFF211B15),
        border: Border.all(color: const Color(0x887D684F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            soldOut ? Icons.event_busy_rounded : Icons.price_change_rounded,
            color: legacyGold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              soldOut
                  ? '刷新后该套餐已售罄，请返回列表选择其他套餐'
                  : '价格由 ${formatAaMoney(oldPriceMinor)} 更新为 ${formatAaMoney(newPriceMinor)}\n${priceAcknowledged ? '新价格已确认，可继续抢订' : '请先确认新价格，再继续抢订'}',
              style: TextStyle(color: legacyGold, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgePriceGrid extends StatelessWidget {
  const _AgePriceGrid();

  @override
  Widget build(BuildContext context) {
    const items = <String>[
      '18-23岁：208.00元/人',
      '24-29岁：268.00元/人',
      '30-35岁：328.00元/人',
      '35岁以上：388.00元/人',
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 5,
      children: [
        for (final item in items)
          SizedBox(
            width: 146,
            height: 18,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item,
                maxLines: 1,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

class _PackageBottomBar extends StatelessWidget {
  const _PackageBottomBar({
    required this.priceMinor,
    required this.originalPriceMinor,
    required this.scenario,
    required this.priceAcknowledged,
    required this.onPressed,
  });

  final int priceMinor;
  final int? originalPriceMinor;
  final AaPackageScenario scenario;
  final bool priceAcknowledged;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final soldOut = scenario == AaPackageScenario.soldOut;
    final priceParts = (priceMinor / 100).toStringAsFixed(2).split('.');
    final showOriginalPrice =
        !soldOut &&
        originalPriceMinor != null &&
        originalPriceMinor != priceMinor;
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
                      if (showOriginalPrice)
                        TextSpan(
                          text: '  原价￥${_moneyValue(originalPriceMinor!)}',
                          style: const TextStyle(
                            color: Color(0xFF6A5B4C),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                  style: const TextStyle(color: Color(0xFF42372B)),
                ),
                Text(
                  soldOut ? '请返回列表刷新其他套餐' : '小姐姐可赠送100元现金券(使用优惠券的除外)',
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
              backgroundColor: const Color(0xFF24180E),
              foregroundColor: legacyGold,
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
                size: 22,
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
                fontWeight: FontWeight.w400,
                letterSpacing: .5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
