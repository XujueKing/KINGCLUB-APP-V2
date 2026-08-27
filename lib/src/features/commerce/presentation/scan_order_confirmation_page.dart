import 'dart:async';

import 'package:flutter/material.dart';

import '../../club/presentation/legacy_club_components.dart';
import 'scan_ordering_cart_page.dart';

enum ScanOrderConfirmationScenario {
  ready,
  quoteExpiring,
  quoteExpired,
  quoteChanged,
  soldOut,
  limitExceeded,
  resultUnknown,
  offline,
  sessionInvalid,
}

class FakeOrderCreatedIntent {
  const FakeOrderCreatedIntent({
    required this.orderRef,
    required this.amountDue,
  });

  final String orderRef;
  final int amountDue;
}

class ScanOrderConfirmationPage extends StatefulWidget {
  const ScanOrderConfirmationPage({
    super.key,
    required this.onBack,
    required this.onModify,
    this.quote,
    this.onOrderCreated,
    this.onOpenOrders,
    this.onSessionResetRequested,
  });

  final VoidCallback onBack;
  final VoidCallback onModify;
  final FakeOrderingQuote? quote;
  final ValueChanged<FakeOrderCreatedIntent>? onOrderCreated;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onSessionResetRequested;

  @override
  State<ScanOrderConfirmationPage> createState() =>
      _ScanOrderConfirmationPageState();
}

class _ScanOrderConfirmationPageState extends State<ScanOrderConfirmationPage> {
  static const _fallbackItems = <FakeOrderingQuoteItem>[
    FakeOrderingQuoteItem(
      name: '星光香槟',
      detail: '香槟 750ml · 含冰桶与香槟杯',
      asset: 'assets/legacy/ordering/product_champagne_v1.png',
      quantity: 1,
      unitPrice: 688,
    ),
    FakeOrderingQuoteItem(
      name: '金标威士忌',
      detail: '威士忌 700ml · 配软与冰块',
      asset: 'assets/legacy/ordering/product_whisky_v1.png',
      quantity: 1,
      unitPrice: 498,
    ),
  ];

  late FakeOrderingQuote _quote;
  Timer? _timer;
  ScanOrderConfirmationScenario _scenario = ScanOrderConfirmationScenario.ready;
  int _secondsRemaining = 272;
  bool _expanded = true;
  bool _submitting = false;
  bool _priceChangeAccepted = false;
  bool _reconciling = false;

  int get _subtotal => _quote.items.fold(0, (sum, item) => sum + item.subtotal);
  int get _discount => _subtotal >= 500 ? 30 : 0;
  int get _changedAmount => _subtotal - _discount + 20;
  int get _amountDue => _scenario == ScanOrderConfirmationScenario.quoteChanged
      ? _changedAmount
      : _subtotal - _discount;

  bool get _canSubmit =>
      !_submitting &&
      !_reconciling &&
      !{
        ScanOrderConfirmationScenario.quoteExpired,
        ScanOrderConfirmationScenario.soldOut,
        ScanOrderConfirmationScenario.limitExceeded,
        ScanOrderConfirmationScenario.resultUnknown,
        ScanOrderConfirmationScenario.offline,
        ScanOrderConfirmationScenario.sessionInvalid,
      }.contains(_scenario) &&
      (_scenario != ScanOrderConfirmationScenario.quoteChanged ||
          _priceChangeAccepted);

  @override
  void initState() {
    super.initState();
    _quote =
        widget.quote ??
        const FakeOrderingQuote(
          itemCount: 2,
          total: 1186,
          items: _fallbackItems,
        );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _secondsRemaining <= 0) return;
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining == 0) {
          _scenario = ScanOrderConfirmationScenario.quoteExpired;
        } else if (_secondsRemaining <= 60 &&
            _scenario == ScanOrderConfirmationScenario.ready) {
          _scenario = ScanOrderConfirmationScenario.quoteExpiring;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LegacyClubScaffold(
      title: '确认点单',
      onBack: widget.onBack,
      showMockLabel: false,
      onTitleLongPress: _showScenarioPicker,
      child: Column(
        children: [
          ...switch (_statusBanner) {
            final banner? => [banner],
            null => const <Widget>[],
          },
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('order-confirm-scroll'),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 26),
              child: Column(
                children: [
                  _buildOrderInfoCard(),
                  _buildItemsCard(),
                  _buildQuoteCard(),
                  _buildPaymentNoticeCard(),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return _LegacyConfirmationCard(
      key: const ValueKey('order-info-card'),
      child: Column(
        children: [
          _infoRow('订单日期：', '2026-08-27 20:18'),
          _infoRow('门店：', 'KINGBAR 湖南工大店'),
          _infoRow('桌号：', 'V8'),
          _infoRow(
            '报价剩余：',
            _formatDuration(_secondsRemaining),
            valueKey: const ValueKey('quote-countdown'),
            valueColor: _secondsRemaining <= 60
                ? const Color(0xFF9A2F21)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    final visible = _expanded ? _quote.items : _quote.items.take(1).toList();
    return _LegacyConfirmationCard(
      key: const ValueKey('order-items-card'),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'KINGBAR 湖南工大店',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          for (final item in visible) _buildItem(item),
          if (_quote.items.length > 1)
            TextButton.icon(
              key: const ValueKey('order-toggle-items'),
              onPressed: () => setState(() => _expanded = !_expanded),
              iconAlignment: IconAlignment.end,
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(
                '${_expanded ? '收起' : '展开'}更多（共${_quote.itemCount}件物品）',
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xAA181205),
              ),
            ),
          const Divider(color: Color(0x22181205)),
          _amountRow('商品总价：', _subtotal),
          if (_discount > 0) ...[
            _amountRow('会员活动优惠：', -_discount, compact: true),
            _amountRow('商品原价：', _subtotal, compact: true, strike: true),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(FakeOrderingQuoteItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1A181205))),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.asset(
              item.asset,
              width: 54,
              height: 76,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, height: 1.35),
                ),
                Text(
                  '单价¥${item.unitPrice}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '数量 x ${item.quantity}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                '小计¥${item.subtotal}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard() {
    return _LegacyConfirmationCard(
      key: const ValueKey('order-quote-card'),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '报价确认',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          _amountRow('商品小计', _subtotal, compact: true),
          _amountRow('优惠', -_discount, compact: true),
          if (_scenario == ScanOrderConfirmationScenario.quoteChanged)
            _amountRow('库存价格调整', 20, compact: true),
          const Divider(color: Color(0x33181205)),
          _amountRow('应付金额', _amountDue, emphasized: true),
          if (_scenario == ScanOrderConfirmationScenario.quoteChanged) ...[
            const SizedBox(height: 10),
            Container(
              key: const ValueKey('quote-change-card'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0D8),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFF9A2F21)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '报价已变化',
                    style: TextStyle(
                      color: Color(0xFF7A2117),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '新应付¥$_changedAmount，比原报价增加¥20。确认后才能提交。',
                    style: const TextStyle(
                      color: Color(0xFF7A2117),
                      fontSize: 12,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      key: const ValueKey('accept-quote-change'),
                      value: _priceChangeAccepted,
                      onChanged: (value) =>
                          setState(() => _priceChangeAccepted = value ?? false),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF55493C),
                      title: const Text(
                        '我已确认新价格',
                        style: TextStyle(
                          color: Color(0xFF40271F),
                          fontSize: 13,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentNoticeCard() {
    return _LegacyConfirmationCard(
      key: const ValueKey('order-payment-notice'),
      child: const Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF423528)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '支付方式',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  '订单创建后选择；本页不手填余额、金币或现金分摊',
                  style: TextStyle(fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Color(0x66181205)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('order-confirm-footer'),
        height: 82,
        padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE6000000), Colors.black],
          ),
          border: Border(top: BorderSide(color: Color(0x40C9B69E))),
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
                        const TextSpan(
                          text: '应付 ¥',
                          style: TextStyle(
                            color: Color(0x88DDCBB5),
                            fontSize: 13,
                          ),
                        ),
                        TextSpan(
                          text: '$_amountDue',
                          style: const TextStyle(
                            color: Color(0xFFDDCBB5),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '最终以当前 Fake Quote 为准',
                    style: TextStyle(color: Color(0x887E7163), fontSize: 10),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const ValueKey('order-modify'),
              onPressed: _submitting ? null : widget.onModify,
              child: const Text('返回修改'),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 112,
              height: 48,
              child: FilledButton(
                key: const ValueKey('order-submit'),
                onPressed: _canSubmit ? _submitOrder : null,
                style: FilledButton.styleFrom(
                  backgroundColor: legacyGold,
                  foregroundColor: const Color(0xFF1B1206),
                  disabledBackgroundColor: const Color(0xFF39332D),
                  disabledForegroundColor: const Color(0xFF756B61),
                  shape: const StadiumBorder(),
                ),
                child: _submitting || _reconciling
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        '提交订单',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? get _statusBanner {
    final data = switch (_scenario) {
      ScanOrderConfirmationScenario.quoteExpiring => (
        Icons.timer_outlined,
        '报价即将过期，请尽快确认',
      ),
      ScanOrderConfirmationScenario.quoteExpired => (
        Icons.timer_off_outlined,
        '报价已过期，刷新后才能提交',
      ),
      ScanOrderConfirmationScenario.quoteChanged => (
        Icons.price_change_outlined,
        '价格发生变化，需要重新确认',
      ),
      ScanOrderConfirmationScenario.soldOut => (
        Icons.remove_shopping_cart_outlined,
        '金标威士忌已售罄，请返回修改',
      ),
      ScanOrderConfirmationScenario.limitExceeded => (
        Icons.production_quantity_limits_outlined,
        '商品数量超出单桌限购，请返回修改',
      ),
      ScanOrderConfirmationScenario.resultUnknown => (
        Icons.sync_outlined,
        '提交结果未知，只允许对账原提交',
      ),
      ScanOrderConfirmationScenario.offline => (
        Icons.cloud_off_outlined,
        '当前离线，报价只读且不可提交',
      ),
      ScanOrderConfirmationScenario.sessionInvalid => (
        Icons.lock_reset_outlined,
        '会话已失效，QuoteRef 已清理',
      ),
      _ => null,
    };
    if (data == null) return null;
    final showRefresh = _scenario == ScanOrderConfirmationScenario.quoteExpired;
    final showReconcile =
        _scenario == ScanOrderConfirmationScenario.resultUnknown;
    final showLogin = _scenario == ScanOrderConfirmationScenario.sessionInvalid;
    final showModify = {
      ScanOrderConfirmationScenario.soldOut,
      ScanOrderConfirmationScenario.limitExceeded,
    }.contains(_scenario);
    return Container(
      key: const ValueKey('order-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      color: const Color(0xFF33291D),
      child: Row(
        children: [
          Icon(data.$1, color: legacyGold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data.$2,
              style: const TextStyle(color: legacyGold, fontSize: 12),
            ),
          ),
          if (showRefresh)
            TextButton(onPressed: _refreshQuote, child: const Text('刷新报价')),
          if (showReconcile)
            TextButton(
              key: const ValueKey('order-reconcile'),
              onPressed: _reconciling ? null : _reconcileSubmission,
              child: const Text('查询结果'),
            ),
          if (showModify)
            TextButton(onPressed: widget.onModify, child: const Text('返回修改')),
          if (showLogin)
            TextButton(
              onPressed: widget.onSessionResetRequested,
              child: const Text('重新登录'),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    Key? valueKey,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              key: valueKey,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF181205),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(
    String label,
    int amount, {
    bool compact = false,
    bool emphasized = false,
    bool strike = false,
  }) {
    final amountText = amount < 0 ? '-¥${amount.abs()}' : '¥$amount';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 3 : 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasized ? 16 : (compact ? 13 : 14),
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const Spacer(),
          Text(
            amountText,
            style: TextStyle(
              fontSize: emphasized ? 22 : (compact ? 13 : 18),
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              decoration: strike ? TextDecoration.lineThrough : null,
              color: emphasized ? const Color(0xFF4C2D12) : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshQuote() async {
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _secondsRemaining = 272;
      _scenario = ScanOrderConfirmationScenario.ready;
      _priceChangeAccepted = false;
    });
  }

  Future<void> _submitOrder() async {
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _submitting = false);
    await _emitOrderCreated();
  }

  Future<void> _reconcileSubmission() async {
    setState(() => _reconciling = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _reconciling = false);
    await _emitOrderCreated();
  }

  Future<void> _emitOrderCreated() async {
    final intent = FakeOrderCreatedIntent(
      orderRef: 'fake-order-v8-0827',
      amountDue: _amountDue,
    );
    if (widget.onOrderCreated case final callback?) {
      callback(intent);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF191510),
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_rounded, color: legacyGold, size: 42),
            const SizedBox(height: 12),
            const Text(
              '待支付订单已创建',
              key: ValueKey('order-created-title'),
              style: TextStyle(
                color: Color(0xFFF3E9DC),
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '应付¥${intent.amountDue} · ${intent.orderRef}',
              style: const TextStyle(color: legacyGold),
            ),
            const SizedBox(height: 8),
            const Text(
              '这是离线 Fake 订单，未调用超级接口、支付 SDK，也不表示支付成功。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9C9186), fontSize: 12),
            ),
            if (widget.onOpenOrders != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onOpenOrders!();
                  },
                  child: const Text('查看我的订单'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showScenarioPicker() async {
    final selected = await showModalBottomSheet<ScanOrderConfirmationScenario>(
      context: context,
      backgroundColor: const Color(0xFF181512),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('确认页 Fake 场景'),
              subtitle: Text('仅用于 UI 验收，长按标题再次打开'),
            ),
            for (final scenario in ScanOrderConfirmationScenario.values)
              ListTile(
                leading: Icon(
                  scenario == _scenario
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: scenario == _scenario
                      ? legacyGold
                      : const Color(0xFF756B61),
                ),
                title: Text(_scenarioLabel(scenario)),
                onTap: () => Navigator.pop(context, scenario),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scenario = selected;
      _priceChangeAccepted = false;
      if (selected == ScanOrderConfirmationScenario.quoteExpiring) {
        _secondsRemaining = 42;
      } else if (selected == ScanOrderConfirmationScenario.quoteExpired) {
        _secondsRemaining = 0;
      } else if (selected == ScanOrderConfirmationScenario.ready) {
        _secondsRemaining = 272;
      }
    });
  }

  String _scenarioLabel(ScanOrderConfirmationScenario scenario) =>
      switch (scenario) {
        ScanOrderConfirmationScenario.ready => '正常报价',
        ScanOrderConfirmationScenario.quoteExpiring => '报价即将过期',
        ScanOrderConfirmationScenario.quoteExpired => '报价已过期',
        ScanOrderConfirmationScenario.quoteChanged => '价格变化',
        ScanOrderConfirmationScenario.soldOut => '提交前售罄',
        ScanOrderConfirmationScenario.limitExceeded => '超出限购',
        ScanOrderConfirmationScenario.resultUnknown => '提交结果未知',
        ScanOrderConfirmationScenario.offline => '离线只读',
        ScanOrderConfirmationScenario.sessionInvalid => '会话失效',
      };
}

class _LegacyConfirmationCard extends StatelessWidget {
  const _LegacyConfirmationCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: legacyGold,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Color(0xFF181205)),
        child: IconTheme.merge(
          data: const IconThemeData(color: Color(0xFF181205)),
          child: child,
        ),
      ),
    );
  }
}
