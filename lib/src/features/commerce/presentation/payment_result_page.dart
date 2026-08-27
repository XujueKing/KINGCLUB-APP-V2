import 'dart:async';

import 'package:flutter/material.dart';

import '../../club/presentation/legacy_club_components.dart';
import 'order_center_page.dart';

class FakePaymentIntentRef {
  const FakePaymentIntentRef(this.opaqueId);

  final String opaqueId;
}

class FakePaymentAttemptRef {
  const FakePaymentAttemptRef(this.opaqueId);

  final String opaqueId;
}

enum PaymentResultScenario {
  normalSuccess,
  providerSuccessPending,
  providerCancelled,
  providerFailed,
  noProviderCallback,
  lateSuccess,
  expiredIntent,
  alreadySucceeded,
  orderStateChanged,
  offline,
  methodUnavailable,
  sessionInvalid,
  zeroAmount,
}

enum PaymentResultStage {
  ready,
  creatingAttempt,
  handingOff,
  verifying,
  succeeded,
  cancelled,
  failed,
  pending,
  expired,
  orderStateChanged,
  offline,
  sessionInvalid,
}

class PaymentResultPage extends StatefulWidget {
  const PaymentResultPage({
    super.key,
    required this.intentRef,
    required this.onClose,
    this.onOpenOrder,
    this.onSessionResetRequested,
    this.onAttemptCreated,
    this.initialScenario = PaymentResultScenario.normalSuccess,
  });

  final FakePaymentIntentRef intentRef;
  final VoidCallback onClose;
  final ValueChanged<FakeOrderRef>? onOpenOrder;
  final VoidCallback? onSessionResetRequested;
  final ValueChanged<FakePaymentAttemptRef>? onAttemptCreated;
  final PaymentResultScenario initialScenario;

  @override
  State<PaymentResultPage> createState() => _PaymentResultPageState();
}

class _PaymentResultPageState extends State<PaymentResultPage> {
  late PaymentResultScenario _scenario;
  late PaymentResultStage _stage;
  FakePaymentAttemptRef? _attemptRef;
  bool _methodAvailable = true;
  int _attemptCount = 0;

  bool get _busy => {
    PaymentResultStage.creatingAttempt,
    PaymentResultStage.handingOff,
    PaymentResultStage.verifying,
  }.contains(_stage);

  bool get _zeroAmount => _scenario == PaymentResultScenario.zeroAmount;

  @override
  void initState() {
    super.initState();
    _scenario = widget.initialScenario;
    _stage = _initialStage(_scenario);
    _methodAvailable = _scenario != PaymentResultScenario.methodUnavailable;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _busy) _showBusyExitDialog();
      },
      child: LegacyClubScaffold(
        title: '支付',
        onBack: _requestClose,
        showMockLabel: false,
        onTitleLongPress: _showScenarioPicker,
        child: switch (_stage) {
          PaymentResultStage.ready => _buildReady(),
          PaymentResultStage.creatingAttempt ||
          PaymentResultStage.handingOff ||
          PaymentResultStage.verifying => _buildProcessing(),
          PaymentResultStage.sessionInvalid => _buildSessionInvalid(),
          _ => _buildResult(),
        },
      ),
    );
  }

  Widget _buildReady() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('payment-ready'),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _buildOrderSummary(),
              const SizedBox(height: 12),
              _buildAmountCard(),
              const SizedBox(height: 12),
              if (!_zeroAmount) _buildMethodCard(),
              if (!_zeroAmount) const SizedBox(height: 12),
              _buildSafetyNotice(),
            ],
          ),
        ),
        _buildReadyFooter(),
      ],
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15110E),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF5C4C3A), width: 3),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KINGBAR V8 桌点单',
                  style: TextStyle(
                    color: Color(0xFFE8DED1),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'V8 卡座 · 星光香槟、金标威士忌',
                  style: TextStyle(color: Color(0xFF9B9085), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '待支付',
            style: TextStyle(
              color: Color(0xFFFFB400),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    final amount = _zeroAmount ? 0 : 1156;
    return Container(
      key: const ValueKey('payment-authoritative-amount'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: legacyGold,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            '应付金额',
            style: TextStyle(color: Color(0xFF6E604F), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '¥$amount.00',
            style: const TextStyle(
              color: Color(0xFF181205),
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _zeroAmount
                ? '优惠已覆盖全部金额，无需调用支付方式'
                : '金额来自 Fake PaymentIntent，客户端不能修改',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF796A58), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard() {
    return Container(
      key: const ValueKey('payment-methods'),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF15110E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '支付方式',
            style: TextStyle(
              color: Color(0xFFE8DED1),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _PaymentMethodRow(
            asset: 'assets/legacy/payment/legacy_weipay.png',
            title: '微信支付',
            subtitle: _methodAvailable ? 'Fake provider 外观' : '当前暂不可用',
            selected: _methodAvailable,
            enabled: _methodAvailable,
          ),
          const Divider(color: Color(0x223E362F), height: 1),
          const _PaymentMethodRow(
            icon: Icons.account_balance_wallet_outlined,
            title: '余额支付',
            subtitle: '服务端未开放此方式',
            selected: false,
            enabled: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF251E17),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4D4034)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: legacyGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _zeroAmount
                  ? '0 元订单只查询 Fake 订单确认结果，不创建 PaymentAttempt。'
                  : '本页不会调用真实支付 SDK。provider 返回后仍需 Fake 服务端确认，未确认前请勿重复支付。',
              style: const TextStyle(
                color: Color(0xFFAAA097),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xF20B0907),
        border: Border(top: BorderSide(color: Color(0x334C4033))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          key: const ValueKey('payment-confirm'),
          onPressed: _zeroAmount || _methodAvailable ? _startPayment : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: legacyGold,
            foregroundColor: const Color(0xFF181205),
            shape: const StadiumBorder(),
          ),
          child: Text(_zeroAmount ? '确认 0 元订单' : '确认支付 ¥1156.00'),
        ),
      ),
    );
  }

  Widget _buildProcessing() {
    final data = switch (_stage) {
      PaymentResultStage.creatingAttempt => (
        '正在创建支付请求',
        '正在生成唯一 Fake PaymentAttempt，请勿重复点击',
      ),
      PaymentResultStage.handingOff => (
        '正在交接支付',
        'Fake provider 已接收 attempt，本页没有拉起真实 SDK',
      ),
      _ => ('正在确认支付结果', '无论 provider 返回什么，都以 Fake 服务端查询结果为准'),
    };
    return _CenteredPaymentState(
      key: const ValueKey('payment-processing'),
      visual: const SizedBox.square(
        dimension: 68,
        child: CircularProgressIndicator(color: legacyGold, strokeWidth: 3),
      ),
      title: data.$1,
      subtitle: data.$2,
      footer: '请勿关闭 App 或再次发起支付',
    );
  }

  Widget _buildResult() {
    final result = _resultPresentation;
    return _CenteredPaymentState(
      key: ValueKey('payment-result-${_stage.name}'),
      visual: result.useLegacySuccess
          ? Image.asset(
              'assets/legacy/payment/legacy_payment_success.png',
              width: 92,
              height: 92,
              fit: BoxFit.contain,
            )
          : Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: result.color, width: 3),
              ),
              child: Icon(result.icon, color: result.color, size: 46),
            ),
      title: result.title,
      subtitle: result.subtitle,
      footer: 'SHANGHAI · ZHUZHOU',
      actions: _buildResultActions(),
    );
  }

  List<Widget> _buildResultActions() {
    return switch (_stage) {
      PaymentResultStage.succeeded => [
        _ResultButton(
          key: const ValueKey('payment-view-order'),
          label: '查看订单',
          primary: true,
          onPressed: _openOrder,
        ),
      ],
      PaymentResultStage.cancelled => [
        _ResultButton(label: '稍后支付', primary: true, onPressed: _openOrder),
        _ResultButton(label: '返回订单', onPressed: _openOrder),
      ],
      PaymentResultStage.failed => [
        _ResultButton(
          key: const ValueKey('payment-safe-retry'),
          label: '安全重试',
          primary: true,
          onPressed: _safeRetry,
        ),
        _ResultButton(label: '查看订单', onPressed: _openOrder),
      ],
      PaymentResultStage.pending => [
        _ResultButton(
          key: const ValueKey('payment-reconcile'),
          label: '继续查询',
          primary: true,
          onPressed: _reconcilePending,
        ),
        _ResultButton(label: '查看订单', onPressed: _openOrder),
      ],
      PaymentResultStage.offline => [
        _ResultButton(
          key: const ValueKey('payment-recover-network'),
          label: '恢复网络',
          primary: true,
          onPressed: _recoverNetwork,
        ),
        _ResultButton(label: '查看订单', onPressed: _openOrder),
      ],
      PaymentResultStage.expired || PaymentResultStage.orderStateChanged => [
        _ResultButton(label: '返回订单详情', primary: true, onPressed: _openOrder),
      ],
      _ => const [],
    };
  }

  Widget _buildSessionInvalid() {
    return _CenteredPaymentState(
      key: const ValueKey('payment-session-invalid'),
      visual: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF8D8379), width: 3),
        ),
        child: const Icon(
          Icons.lock_reset_rounded,
          color: Color(0xFFB4AAA0),
          size: 46,
        ),
      ),
      title: '会话已失效',
      subtitle: '支付意图和 attempt 引用已从当前页面清理',
      footer: 'SHANGHAI · ZHUZHOU',
      actions: [
        _ResultButton(
          label: '重新登录',
          primary: true,
          onPressed: widget.onSessionResetRequested,
        ),
      ],
    );
  }

  Future<void> _startPayment() async {
    if (_busy || _stage != PaymentResultStage.ready) return;
    if (_zeroAmount) {
      setState(() => _stage = PaymentResultStage.verifying);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() => _stage = PaymentResultStage.succeeded);
      return;
    }
    setState(() {
      _stage = PaymentResultStage.creatingAttempt;
      _attemptCount += 1;
      _attemptRef = FakePaymentAttemptRef(
        'attempt-${widget.intentRef.opaqueId}-$_attemptCount',
      );
    });
    widget.onAttemptCreated?.call(_attemptRef!);
    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (!mounted) return;
    setState(() => _stage = PaymentResultStage.handingOff);
    await Future<void>.delayed(const Duration(milliseconds: 440));
    if (!mounted) return;
    setState(() => _stage = PaymentResultStage.verifying);
    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (!mounted) return;
    setState(() => _stage = _providerOutcome(_scenario));
  }

  Future<void> _safeRetry() async {
    setState(() {
      _stage = PaymentResultStage.ready;
      _attemptRef = null;
    });
  }

  Future<void> _reconcilePending() async {
    setState(() => _stage = PaymentResultStage.verifying);
    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (!mounted) return;
    setState(() {
      _stage = _scenario == PaymentResultScenario.lateSuccess
          ? PaymentResultStage.succeeded
          : PaymentResultStage.pending;
    });
  }

  void _recoverNetwork() {
    setState(() => _stage = PaymentResultStage.ready);
  }

  void _openOrder() {
    if (widget.onOpenOrder case final callback?) {
      callback(const FakeOrderRef('order-scan-v8-0827'));
    } else {
      showFakeResult(context, '已生成订单详情意图');
    }
  }

  void _requestClose() {
    if (_busy) {
      _showBusyExitDialog();
    } else {
      widget.onClose();
    }
  }

  void _showBusyExitDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF201A15),
        title: const Text('支付结果仍在确认'),
        content: const Text('返回不会取消原 Fake attempt。请勿因为暂时没有结果而再次付款。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('继续等待'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onClose();
            },
            child: const Text('返回订单'),
          ),
        ],
      ),
    );
  }

  void _showScenarioPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF211A14),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: ListView(
            children: PaymentResultScenario.values.map((scenario) {
              return ListTile(
                key: ValueKey('payment-scenario-${scenario.name}'),
                title: Text(_scenarioLabel(scenario)),
                trailing: scenario == _scenario
                    ? const Icon(Icons.check_rounded, color: legacyGold)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _scenario = scenario;
                    _stage = _initialStage(scenario);
                    _attemptRef = null;
                    _attemptCount = 0;
                    _methodAvailable =
                        scenario != PaymentResultScenario.methodUnavailable;
                  });
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  _PaymentResultPresentation get _resultPresentation => switch (_stage) {
    PaymentResultStage.succeeded => const _PaymentResultPresentation(
      title: '支付已确认',
      subtitle: 'Fake 服务端已确认 ¥1156.00 支付成功\n订单状态将以详情页为准',
      color: Colors.white,
      icon: Icons.check_rounded,
      useLegacySuccess: true,
    ),
    PaymentResultStage.cancelled => const _PaymentResultPresentation(
      title: '本次支付已取消',
      subtitle: '没有确认扣款，业务订单仍保持待支付\n稍后可从订单详情重新获取支付意图',
      color: Color(0xFFB7ADA3),
      icon: Icons.close_rounded,
    ),
    PaymentResultStage.failed => const _PaymentResultPresentation(
      title: '支付未完成',
      subtitle: 'Fake 服务端确认本次 attempt 已明确失败\n允许重新获取支付意图后安全重试',
      color: Color(0xFFF08F78),
      icon: Icons.priority_high_rounded,
    ),
    PaymentResultStage.pending => const _PaymentResultPresentation(
      title: '支付结果待确认',
      subtitle: '暂时无法确认是否扣款，请勿重复支付\n可继续查询原 attempt 或返回订单详情',
      color: Color(0xFFFFC761),
      icon: Icons.more_horiz_rounded,
    ),
    PaymentResultStage.expired => const _PaymentResultPresentation(
      title: '支付意图已过期',
      subtitle: '旧意图已经失效，不能继续发起支付\n请返回订单详情获取新的支付入口',
      color: Color(0xFFB7ADA3),
      icon: Icons.timer_off_outlined,
    ),
    PaymentResultStage.orderStateChanged => const _PaymentResultPresentation(
      title: '订单状态已变化',
      subtitle: '当前订单已不允许使用此支付意图\n请返回订单详情查看最新状态',
      color: Color(0xFFB7ADA3),
      icon: Icons.receipt_long_outlined,
    ),
    PaymentResultStage.offline => const _PaymentResultPresentation(
      title: '当前网络不可用',
      subtitle: '订单摘要仅供查看，尚未创建支付 attempt\n恢复网络后可重新加载 Fake 支付意图',
      color: Color(0xFFB7ADA3),
      icon: Icons.cloud_off_rounded,
    ),
    _ => const _PaymentResultPresentation(
      title: '正在更新',
      subtitle: '请稍候',
      color: legacyGold,
      icon: Icons.sync_rounded,
    ),
  };
}

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    this.asset,
    this.icon,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final String? asset;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? const Color(0xFFE8DED1)
        : const Color(0xFF625A52);
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: asset != null
                ? Image.asset(asset!, fit: BoxFit.contain)
                : Icon(icon, color: foreground, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: enabled
                        ? const Color(0xFF8F857B)
                        : const Color(0xFF564F49),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? legacyGold : const Color(0xFF5D554E),
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _CenteredPaymentState extends StatelessWidget {
  const _CenteredPaymentState({
    super.key,
    required this.visual,
    required this.title,
    required this.subtitle,
    required this.footer,
    this.actions = const [],
  });

  final Widget visual;
  final String title;
  final String subtitle;
  final String footer;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 30),
      child: Column(
        children: [
          const Spacer(flex: 2),
          visual,
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE8DED1),
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFA89E94),
              fontSize: 13,
              height: 1.65,
            ),
          ),
          const Spacer(flex: 3),
          ...actions.expand((action) => [action, const SizedBox(height: 10)]),
          const SizedBox(height: 4),
          Text(
            footer,
            style: const TextStyle(
              color: Color(0xFF5E554D),
              fontSize: 9,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultButton extends StatelessWidget {
  const _ResultButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: primary
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: legacyGold,
                foregroundColor: const Color(0xFF181205),
                shape: const StadiumBorder(),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: legacyGold,
                side: const BorderSide(color: Color(0xFF665749)),
                shape: const StadiumBorder(),
              ),
              child: Text(label),
            ),
    );
  }
}

class _PaymentResultPresentation {
  const _PaymentResultPresentation({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.useLegacySuccess = false,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool useLegacySuccess;
}

PaymentResultStage _initialStage(PaymentResultScenario scenario) =>
    switch (scenario) {
      PaymentResultScenario.expiredIntent => PaymentResultStage.expired,
      PaymentResultScenario.alreadySucceeded => PaymentResultStage.succeeded,
      PaymentResultScenario.orderStateChanged =>
        PaymentResultStage.orderStateChanged,
      PaymentResultScenario.offline => PaymentResultStage.offline,
      PaymentResultScenario.sessionInvalid => PaymentResultStage.sessionInvalid,
      _ => PaymentResultStage.ready,
    };

PaymentResultStage _providerOutcome(PaymentResultScenario scenario) =>
    switch (scenario) {
      PaymentResultScenario.normalSuccess => PaymentResultStage.succeeded,
      PaymentResultScenario.providerSuccessPending =>
        PaymentResultStage.pending,
      PaymentResultScenario.providerCancelled => PaymentResultStage.cancelled,
      PaymentResultScenario.providerFailed => PaymentResultStage.failed,
      PaymentResultScenario.noProviderCallback ||
      PaymentResultScenario.lateSuccess => PaymentResultStage.pending,
      _ => PaymentResultStage.succeeded,
    };

String _scenarioLabel(PaymentResultScenario scenario) => switch (scenario) {
  PaymentResultScenario.normalSuccess => 'provider 成功 + 服务端成功',
  PaymentResultScenario.providerSuccessPending => 'provider 成功 + 服务端待确认',
  PaymentResultScenario.providerCancelled => 'provider 取消',
  PaymentResultScenario.providerFailed => 'provider 失败',
  PaymentResultScenario.noProviderCallback => 'provider 无回调',
  PaymentResultScenario.lateSuccess => '结果未知后晚到成功',
  PaymentResultScenario.expiredIntent => '支付意图过期',
  PaymentResultScenario.alreadySucceeded => '订单已经支付',
  PaymentResultScenario.orderStateChanged => '订单状态变化',
  PaymentResultScenario.offline => '网络中断',
  PaymentResultScenario.methodUnavailable => '支付方式不可用',
  PaymentResultScenario.sessionInvalid => '会话失效',
  PaymentResultScenario.zeroAmount => '0 元订单',
};
