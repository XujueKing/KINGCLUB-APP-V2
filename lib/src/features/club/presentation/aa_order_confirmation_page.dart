import 'package:flutter/material.dart';

import '../../commerce/presentation/order_detail_page.dart';
import '../../commerce/presentation/payment_result_page.dart';
import 'aa_mock_models.dart';
import 'legacy_club_components.dart';

enum AaConfirmationScenario {
  ready,
  initialLoading,
  quoteExpired,
  invalidRef,
  zeroCash,
  soldOutOnSubmit,
  duplicateReservation,
  resultUnknown,
  ineligibleOnSubmit,
  offline,
  sessionInvalid,
}

enum AaSubmissionOutcome {
  none,
  soldOut,
  duplicateReservation,
  resultUnknown,
  ineligible,
  offline,
  sessionInvalid,
}

class AaOrderConfirmationPage extends StatefulWidget {
  const AaOrderConfirmationPage({
    super.key,
    required this.package,
    required this.serviceDate,
    this.onSessionResetRequested,
  });

  final AaMockPackage package;
  final String serviceDate;
  final VoidCallback? onSessionResetRequested;

  @override
  State<AaOrderConfirmationPage> createState() =>
      _AaOrderConfirmationPageState();
}

class _AaOrderConfirmationPageState extends State<AaOrderConfirmationPage> {
  bool _coupon = false;
  bool _gold = false;
  bool _balance = false;
  bool _agreed = false;
  bool _submitting = false;
  bool _quoteExpired = false;
  bool _requoteLoading = false;
  bool _quoteChanged = false;
  AaConfirmationScenario _scenario = AaConfirmationScenario.ready;
  AaSubmissionOutcome _submissionOutcome = AaSubmissionOutcome.none;

  int get _deduction =>
      (_coupon ? 2000 : 0) + (_gold ? 800 : 0) + (_balance ? 2000 : 0);

  int get _payable => _scenario == AaConfirmationScenario.zeroCash
      ? 0
      : (widget.package.priceMinor - _deduction).clamp(0, 99999999);

  bool get _interactionBlocked =>
      _quoteExpired ||
      _requoteLoading ||
      _submissionOutcome != AaSubmissionOutcome.none;

  bool get _initialLoading =>
      _scenario == AaConfirmationScenario.initialLoading;

  bool get _invalidRef => _scenario == AaConfirmationScenario.invalidRef;

  bool get _zeroCash => _scenario == AaConfirmationScenario.zeroCash;

  String get _paymentButtonLabel => switch (_submissionOutcome) {
    AaSubmissionOutcome.soldOut => '已售罄',
    AaSubmissionOutcome.duplicateReservation => '已有预订',
    AaSubmissionOutcome.resultUnknown => '确认中',
    AaSubmissionOutcome.ineligible => '资格失效',
    AaSubmissionOutcome.offline => '当前离线',
    AaSubmissionOutcome.sessionInvalid => '返回登录',
    AaSubmissionOutcome.none => _zeroCash ? '确认预订' : '立即付款',
  };

  @override
  Widget build(BuildContext context) {
    final sessionInvalid =
        _submissionOutcome == AaSubmissionOutcome.sessionInvalid;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: sessionInvalid
            ? Column(
                children: [
                  _Header(
                    onBack: _requestSessionReset,
                    onTitleLongPress: _showScenarioSheet,
                  ),
                  Expanded(
                    child: _SessionInvalidView(onReset: _requestSessionReset),
                  ),
                ],
              )
            : _invalidRef
            ? Column(
                children: [
                  _Header(
                    onBack: () => Navigator.pop(context),
                    onTitleLongPress: _showScenarioSheet,
                  ),
                  Expanded(
                    child: _InvalidQuoteView(
                      onReturn: () => Navigator.pop(context),
                    ),
                  ),
                ],
              )
            : _initialLoading
            ? Column(
                children: [
                  _Header(
                    onBack: () => Navigator.pop(context),
                    onTitleLongPress: _showScenarioSheet,
                  ),
                  Expanded(child: _InitialLoadingView(onLoaded: _finishLoad)),
                  _PaymentBottomBar(
                    payable: 0,
                    amountHidden: true,
                    enabled: false,
                    submitting: false,
                    buttonLabel: '加载中',
                    onPay: () {},
                  ),
                ],
              )
            : Column(
                children: [
                  _Header(
                    onBack: () => Navigator.pop(context),
                    onTitleLongPress: _showScenarioSheet,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        _Section(
                          children: [
                            _InfoRow(
                              label: '预定位置',
                              value: '${widget.package.seat}卡座',
                            ),
                            _InfoRow(
                              label: '时间',
                              value: '${widget.serviceDate} 20:30-04:00',
                            ),
                            _InfoRow(label: '套餐', value: widget.package.name),
                            _InfoRow(
                              label: 'AA人次价',
                              value: formatAaMoney(widget.package.priceMinor),
                            ),
                          ],
                        ),
                        if (_quoteExpired)
                          _QuoteExpiredBanner(onRefresh: _refreshQuote),
                        if (_requoteLoading || _quoteChanged)
                          _RequoteBanner(
                            loading: _requoteLoading,
                            onDismiss: () =>
                                setState(() => _quoteChanged = false),
                          ),
                        if (_submissionOutcome != AaSubmissionOutcome.none)
                          _SubmissionOutcomeBanner(
                            outcome: _submissionOutcome,
                            querying: _submitting,
                            onAction: switch (_submissionOutcome) {
                              AaSubmissionOutcome.resultUnknown =>
                                _reconcileUnknownSubmission,
                              AaSubmissionOutcome.offline => _restoreConnection,
                              _ => _returnToAaList,
                            },
                          ),
                        _Section(
                          children: [
                            _DeductionRow(
                              title: '优惠券',
                              detail: _coupon ? '已选20元AA券' : '未选择',
                              selected: _coupon,
                              enabled: !_interactionBlocked,
                              onChanged: (value) =>
                                  _requote(() => _coupon = value),
                            ),
                            _DeductionRow(
                              title: '金币兑换',
                              detail: _gold ? '抵扣8.00元' : '可用50金币',
                              selected: _gold,
                              enabled: !_interactionBlocked,
                              onChanged: (value) =>
                                  _requote(() => _gold = value),
                            ),
                            _DeductionRow(
                              title: '余额',
                              detail: _balance ? '抵扣20.00元' : '可用¥38.00',
                              selected: _balance,
                              enabled: !_interactionBlocked,
                              onChanged: (value) =>
                                  _requote(() => _balance = value),
                            ),
                          ],
                        ),
                        const _Section(children: [_PaymentRow()]),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Checkbox(
                                key: const ValueKey('aa-terms-checkbox'),
                                value: _agreed,
                                activeColor: legacyGold,
                                checkColor: Colors.black,
                                side: const BorderSide(color: legacyGold),
                                onChanged: _interactionBlocked
                                    ? null
                                    : (value) => setState(
                                        () => _agreed = value ?? false,
                                      ),
                              ),
                              const Text(
                                '我已阅读并同意本次预订、迟到和取消规则',
                                maxLines: 1,
                                style: TextStyle(
                                  color: Color(0xFFB9AEA4),
                                  fontSize: 12,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 5),
                              TextButton(
                                onPressed: _showTerms,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  '查看',
                                  style: TextStyle(
                                    color: legacyGold,
                                    fontSize: 12,
                                    height: 1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _deduction == 0
                                    ? '暂无抵扣'
                                    : '已优惠 ${formatAaMoney(_deduction)}',
                                style: const TextStyle(
                                  color: Color(0xFF8E7E70),
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                '报价剩余 04:32',
                                style: TextStyle(
                                  color: Color(0xFF8E7E70),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PaymentBottomBar(
                    payable: _payable,
                    amountHidden: false,
                    enabled: _agreed && !_submitting && !_interactionBlocked,
                    submitting: _submitting,
                    buttonLabel: _paymentButtonLabel,
                    subtitle: _zeroCash ? '本单无需支付' : '提交后进入支付',
                    onPay: _submitFakeOrder,
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _requote(VoidCallback mutation) async {
    if (_interactionBlocked) return;
    setState(() {
      _requoteLoading = true;
      _quoteChanged = false;
      _agreed = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      mutation();
      _requoteLoading = false;
      _quoteChanged = true;
    });
  }

  void _finishLoad() {
    setState(() {
      _scenario = AaConfirmationScenario.ready;
      _quoteChanged = false;
      _agreed = false;
    });
  }

  void _refreshQuote() {
    setState(() {
      _quoteExpired = false;
      _scenario = AaConfirmationScenario.ready;
      _submissionOutcome = AaSubmissionOutcome.none;
      _agreed = false;
      _requoteLoading = false;
      _quoteChanged = false;
    });
    showFakeResult(context, '已获取最新报价，请重新确认规则');
  }

  Future<void> _showTerms() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1511),
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Text(
            '预订规则\n\n1. 本次预订仅包含本人一席。\n2. 到店后凭有效入场凭证核验。\n3. 请文明饮酒并尊重同桌会员。\n4. 最终金额以提交时确认结果为准。',
            style: TextStyle(color: Color(0xFFD8C8B8), height: 1.8),
          ),
        ),
      ),
    );
  }

  Future<void> _submitFakeOrder() async {
    if (!_agreed || _submitting || _interactionBlocked) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final outcome = switch (_scenario) {
      AaConfirmationScenario.soldOutOnSubmit => AaSubmissionOutcome.soldOut,
      AaConfirmationScenario.duplicateReservation =>
        AaSubmissionOutcome.duplicateReservation,
      AaConfirmationScenario.resultUnknown => AaSubmissionOutcome.resultUnknown,
      AaConfirmationScenario.ineligibleOnSubmit =>
        AaSubmissionOutcome.ineligible,
      AaConfirmationScenario.ready ||
      AaConfirmationScenario.initialLoading ||
      AaConfirmationScenario.quoteExpired ||
      AaConfirmationScenario.invalidRef ||
      AaConfirmationScenario.zeroCash ||
      AaConfirmationScenario.offline ||
      AaConfirmationScenario.sessionInvalid => AaSubmissionOutcome.none,
    };
    setState(() {
      _submitting = false;
      _submissionOutcome = outcome;
      if (outcome != AaSubmissionOutcome.none) _agreed = false;
    });
    if (outcome != AaSubmissionOutcome.none) return;
    if (_zeroCash) {
      await _showNoCashConfirmation();
    } else {
      await _showPendingPaymentResult();
    }
  }

  Future<void> _showNoCashConfirmation() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1511),
        title: const Text('预订已确认'),
        content: const Text(
          '实付 ¥0.00\n本次优惠已抵扣全部金额。',
          style: TextStyle(color: Color(0xFFD8C8B8), height: 1.6),
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

  Future<void> _showPendingPaymentResult() async {
    final quoteMask = (_coupon ? 1 : 0) | (_gold ? 2 : 0) | (_balance ? 4 : 0);
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (paymentContext) => PaymentResultPage(
          intentRef: FakePaymentIntentRef('payment-intent-aa-v5-r$quoteMask'),
          onClose: () => Navigator.of(paymentContext).maybePop(),
          onOpenOrder: (orderRef) {
            Navigator.of(paymentContext).pushReplacement<void, void>(
              MaterialPageRoute<void>(
                builder: (orderContext) => OrderDetailPage(
                  orderRef: orderRef,
                  onBack: () => Navigator.of(orderContext).maybePop(),
                  onSessionResetRequested: widget.onSessionResetRequested,
                ),
              ),
            );
          },
          onSessionResetRequested: widget.onSessionResetRequested,
        ),
      ),
    );
  }

  Future<void> _showScenarioSheet() async {
    final selected = await showModalBottomSheet<AaConfirmationScenario>(
      context: context,
      backgroundColor: const Color(0xFF1A1511),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '确认订单 Fake 状态',
                  style: TextStyle(color: legacyGold, fontSize: 16),
                ),
              ),
              for (final option in AaConfirmationScenario.values)
                ListTile(
                  key: ValueKey('aa-confirmation-scenario-${option.name}'),
                  title: Text(switch (option) {
                    AaConfirmationScenario.ready => '正常提交',
                    AaConfirmationScenario.initialLoading => '首次加载',
                    AaConfirmationScenario.quoteExpired => '报价已失效',
                    AaConfirmationScenario.invalidRef => '报价引用无效',
                    AaConfirmationScenario.zeroCash => '零元确认',
                    AaConfirmationScenario.soldOutOnSubmit => '提交时突然售罄',
                    AaConfirmationScenario.duplicateReservation => '检测到已有预订',
                    AaConfirmationScenario.resultUnknown => '提交结果未知',
                    AaConfirmationScenario.ineligibleOnSubmit => '提交时资格失效',
                    AaConfirmationScenario.offline => '当前离线',
                    AaConfirmationScenario.sessionInvalid => '会话失效',
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
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scenario = selected;
      _quoteExpired = selected == AaConfirmationScenario.quoteExpired;
      _submissionOutcome = switch (selected) {
        AaConfirmationScenario.offline => AaSubmissionOutcome.offline,
        AaConfirmationScenario.sessionInvalid =>
          AaSubmissionOutcome.sessionInvalid,
        _ => AaSubmissionOutcome.none,
      };
      _agreed = false;
      _submitting = false;
      _requoteLoading = false;
      _quoteChanged = false;
      if (selected == AaConfirmationScenario.sessionInvalid ||
          selected == AaConfirmationScenario.invalidRef) {
        _coupon = false;
        _gold = false;
        _balance = false;
      }
    });
  }

  Future<void> _reconcileUnknownSubmission() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submissionOutcome = AaSubmissionOutcome.none;
      _scenario = AaConfirmationScenario.ready;
    });
    await _showPendingPaymentResult();
  }

  void _restoreConnection() {
    setState(() {
      _scenario = AaConfirmationScenario.ready;
      _submissionOutcome = AaSubmissionOutcome.none;
      _agreed = false;
      _requoteLoading = false;
      _quoteChanged = false;
    });
    showFakeResult(context, '网络已恢复，请重新确认规则');
  }

  void _requestSessionReset() {
    _coupon = false;
    _gold = false;
    _balance = false;
    _agreed = false;
    widget.onSessionResetRequested?.call();
    if (widget.onSessionResetRequested != null) return;
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
  }

  void _returnToAaList() {
    final navigator = Navigator.of(context);
    var routesToKeep = 0;
    navigator.popUntil((route) {
      if (route.isFirst || routesToKeep >= 2) return true;
      routesToKeep += 1;
      return false;
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onTitleLongPress});

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
            key: const ValueKey('aa-confirmation-title'),
            onLongPress: onTitleLongPress,
            child: const Text(
              '确认订单',
              style: TextStyle(
                color: legacyGold,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteExpiredBanner extends StatelessWidget {
  const _QuoteExpiredBanner({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('aa-quote-expired-banner'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF211B15),
        border: Border.all(color: const Color(0x887D684F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: legacyGold, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '报价已失效，请刷新后重新确认金额和规则',
              style: TextStyle(color: legacyGold, fontSize: 12, height: 1.4),
            ),
          ),
          TextButton(
            key: const ValueKey('aa-refresh-quote'),
            onPressed: onRefresh,
            child: const Text('刷新报价', style: TextStyle(color: legacyGold)),
          ),
        ],
      ),
    );
  }
}

class _RequoteBanner extends StatelessWidget {
  const _RequoteBanner({required this.loading, required this.onDismiss});

  final bool loading;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(
        loading ? 'aa-requote-loading-banner' : 'aa-quote-changed-banner',
      ),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF211B15),
        border: Border.all(color: const Color(0x887D684F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: legacyGold,
              ),
            )
          else
            const Icon(Icons.update_rounded, color: legacyGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading ? '正在重新计算报价' : '报价已更新',
                  style: const TextStyle(
                    color: legacyGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  loading ? '暂时保留原金额，完成前不能提交' : '抵扣与实付金额已更新，请重新确认规则',
                  style: const TextStyle(
                    color: Color(0xFFD8C8B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!loading)
            TextButton(
              key: const ValueKey('aa-dismiss-quote-changed'),
              onPressed: onDismiss,
              child: const Text('知道了', style: TextStyle(color: legacyGold)),
            ),
        ],
      ),
    );
  }
}

class _InitialLoadingView extends StatelessWidget {
  const _InitialLoadingView({required this.onLoaded});

  final VoidCallback onLoaded;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(30, 24, 30, 40),
        child: Column(
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: legacyGold,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              '正在获取最新报价',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '正在核对套餐、库存和可用抵扣\n金额返回前不会开放提交',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB9AEA4),
                fontSize: 13,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 180,
              height: 46,
              child: OutlinedButton(
                key: const ValueKey('aa-initial-load-action'),
                onPressed: onLoaded,
                style: OutlinedButton.styleFrom(
                  foregroundColor: legacyGold,
                  side: const BorderSide(color: legacyGold),
                  shape: const StadiumBorder(),
                ),
                child: const Text('重新加载'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvalidQuoteView extends StatelessWidget {
  const _InvalidQuoteView({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(30, 24, 30, 40),
        child: Column(
          children: [
            const Icon(Icons.link_off_rounded, color: legacyGold, size: 58),
            const SizedBox(height: 20),
            const Text(
              '报价已失效',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '这份报价无法继续使用，金额、抵扣、规则确认和提交信息已清除。请返回套餐详情重新获取。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB9AEA4),
                fontSize: 13,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 190,
              height: 48,
              child: FilledButton(
                key: const ValueKey('aa-invalid-ref-action'),
                onPressed: onReturn,
                style: FilledButton.styleFrom(
                  backgroundColor: legacyGold,
                  foregroundColor: const Color(0xFF33261D),
                  shape: const StadiumBorder(),
                ),
                child: const Text('返回套餐详情'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionOutcomeBanner extends StatelessWidget {
  const _SubmissionOutcomeBanner({
    required this.outcome,
    required this.querying,
    required this.onAction,
  });

  final AaSubmissionOutcome outcome;
  final bool querying;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final (icon, title, detail, actionLabel) = switch (outcome) {
      AaSubmissionOutcome.soldOut => (
        Icons.event_busy_rounded,
        '套餐刚刚售罄',
        '本次未创建订单，也不会扣款。请返回套餐列表刷新其他套餐。',
        '返回套餐列表',
      ),
      AaSubmissionOutcome.duplicateReservation => (
        Icons.receipt_long_rounded,
        '检测到已有AA预订',
        'KC-AA-0826-01 · 待支付\n席位保留 08:36，不会再创建第二张订单。',
        '返回查看',
      ),
      AaSubmissionOutcome.resultUnknown => (
        Icons.sync_rounded,
        '预订结果待确认',
        '请勿重复提交或支付。继续查询将沿用本次请求编号。',
        '继续查询',
      ),
      AaSubmissionOutcome.ineligible => (
        Icons.no_accounts_rounded,
        '当前账号暂不可预订',
        '会员资格状态已更新，本次未创建订单，也不会扣款。请确认会员审核状态后再试。',
        '返回AA列表',
      ),
      AaSubmissionOutcome.offline => (
        Icons.cloud_off_rounded,
        '当前网络不可用',
        '正在显示缓存报价，仅供查看。离线时不能重报价、创建订单或支付。',
        '恢复联网',
      ),
      AaSubmissionOutcome.sessionInvalid => throw StateError(
        'Session invalid uses a full-page state',
      ),
      AaSubmissionOutcome.none => throw StateError('No outcome banner'),
    };
    return Container(
      key: ValueKey('aa-submission-outcome-${outcome.name}'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF211B15),
        border: Border.all(color: const Color(0x887D684F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: legacyGold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: legacyGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFFD8C8B8),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('aa-submission-outcome-action'),
            onPressed: querying ? null : onAction,
            child: querying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    actionLabel,
                    style: const TextStyle(color: legacyGold, fontSize: 12),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionInvalidView extends StatelessWidget {
  const _SessionInvalidView({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(30, 24, 30, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_reset_rounded, color: legacyGold, size: 58),
            const SizedBox(height: 20),
            const Text(
              '登录状态已失效',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '订单报价、抵扣、规则确认和提交上下文已安全清除。请重新登录后获取最新预订状态。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB9AEA4),
                fontSize: 13,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 190,
              height: 48,
              child: FilledButton(
                key: const ValueKey('aa-session-reset-action'),
                onPressed: onReset,
                style: FilledButton.styleFrom(
                  backgroundColor: legacyGold,
                  foregroundColor: const Color(0xFF33261D),
                  shape: const StadiumBorder(),
                ),
                child: const Text('返回登录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF17120E),
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFF34291F)),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(
          children: [
            Text(
              '$label：',
              style: const TextStyle(color: legacyGold, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeductionRow extends StatelessWidget {
  const _DeductionRow({
    required this.title,
    required this.detail,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String detail;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              semanticLabel: '$title，$detail',
              activeColor: legacyGold,
              checkColor: Colors.black,
              side: const BorderSide(color: Color(0xFFB9AEA4)),
              onChanged: enabled ? (value) => onChanged(value ?? false) : null,
            ),
            Text(
              title,
              style: const TextStyle(color: legacyGold, fontSize: 14),
            ),
            const Spacer(),
            Text(
              detail,
              style: TextStyle(
                color: selected
                    ? const Color(0xCCFFFFFF)
                    : const Color(0x55FFFFFF),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Color(0x66FFFFFF)),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 64,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF1AAD19),
            ),
            SizedBox(width: 12),
            Text('微信支付', style: TextStyle(color: Colors.white)),
            Spacer(),
            Icon(Icons.chevron_right_rounded, color: Color(0x66FFFFFF)),
          ],
        ),
      ),
    );
  }
}

class _PaymentBottomBar extends StatelessWidget {
  const _PaymentBottomBar({
    required this.payable,
    required this.amountHidden,
    required this.enabled,
    required this.submitting,
    required this.buttonLabel,
    this.subtitle = '提交后进入支付',
    required this.onPay,
  });

  final int payable;
  final bool amountHidden;
  final bool enabled;
  final bool submitting;
  final String buttonLabel;
  final String subtitle;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final amount = (payable / 100).toStringAsFixed(2).split('.');
    return Container(
      height: 102,
      padding: const EdgeInsets.fromLTRB(20, 12, 18, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFF3EADF), legacyGold]),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (amountHidden)
                  const Text(
                    '实付￥--',
                    style: TextStyle(
                      color: Color(0xFF3B2B1D),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: '实付￥',
                          style: TextStyle(fontSize: 15),
                        ),
                        TextSpan(
                          text: amount.first,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '.${amount.last} 元',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                    style: const TextStyle(color: Color(0xFF3B2B1D)),
                  ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF5C4E3E),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            key: const ValueKey('aa-pay-button'),
            onPressed: enabled ? onPay : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF24180E),
              foregroundColor: legacyGold,
              disabledBackgroundColor: const Color(0x663B2B1D),
              minimumSize: const Size(118, 48),
              maximumSize: const Size(118, 48),
              fixedSize: const Size(118, 48),
              shape: const StadiumBorder(),
            ),
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
