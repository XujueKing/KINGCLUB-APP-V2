import 'dart:async';

import 'package:flutter/material.dart';

import '../../club/presentation/legacy_club_components.dart';
import 'order_center_page.dart';

enum OrderDetailScenario {
  awaitingPayment,
  confirmed,
  completed,
  refunding,
  refunded,
  cancelled,
  offlineCached,
  unknownStatus,
  invalidRef,
  sessionInvalid,
  cancelConflict,
  cancelResultUnknown,
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.orderRef,
    required this.onBack,
    this.onPaymentIntent,
    this.onAdmission,
    this.onContactSupport,
    this.onSessionResetRequested,
    this.initialScenario,
  });

  final FakeOrderRef orderRef;
  final VoidCallback onBack;
  final ValueChanged<String>? onPaymentIntent;
  final ValueChanged<String>? onAdmission;
  final ValueChanged<FakeOrderRef>? onContactSupport;
  final VoidCallback? onSessionResetRequested;
  final OrderDetailScenario? initialScenario;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late OrderDetailScenario _scenario;
  bool _submitting = false;
  bool _cancelledLocally = false;
  bool _conflictResolved = false;
  bool _resultUnknown = false;

  @override
  void initState() {
    super.initState();
    _scenario = widget.initialScenario ?? _scenarioForRef(widget.orderRef);
  }

  @override
  Widget build(BuildContext context) {
    return LegacyClubScaffold(
      title: '订单详情',
      onBack: widget.onBack,
      showMockLabel: false,
      onTitleLongPress: _showScenarioPicker,
      child: switch (_scenario) {
        OrderDetailScenario.invalidRef => _buildSafeError(),
        OrderDetailScenario.sessionInvalid => _buildSessionInvalid(),
        _ => _buildContent(),
      },
    );
  }

  Widget _buildContent() {
    final presentation = _presentation;
    return Column(
      children: [
        ?_banner,
        Expanded(
          child: RefreshIndicator(
            color: legacyGold,
            backgroundColor: const Color(0xFF251E17),
            onRefresh: _refresh,
            child: ListView(
              key: const ValueKey('order-detail-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 110),
              children: [
                _buildStatusCard(presentation),
                const SizedBox(height: 10),
                _buildOrderInfoCard(presentation),
                const SizedBox(height: 10),
                _buildProductCard(presentation),
                const SizedBox(height: 10),
                _buildAmountCard(presentation),
                const SizedBox(height: 10),
                _buildTimelineCard(presentation),
              ],
            ),
          ),
        ),
        _buildActionBar(presentation),
      ],
    );
  }

  Widget _buildStatusCard(_OrderDetailPresentation data) {
    return Container(
      key: const ValueKey('order-detail-status'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15110E),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF5C4C3A), width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: data.statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: data.statusColor.withValues(alpha: .32),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.statusLabel,
                  style: TextStyle(
                    color: data.statusColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.statusHint,
                  style: const TextStyle(
                    color: Color(0xFF9B9085),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF30271E),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF554638)),
            ),
            child: Text(
              data.type,
              style: const TextStyle(color: legacyGold, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(_OrderDetailPresentation data) {
    return _LegacyOrderCard(
      key: const ValueKey('order-detail-info'),
      child: Column(
        children: [
          _DetailRow(label: '订单', value: data.title, emphasized: true),
          _DetailRow(label: '门店', value: 'KING CLUB · 建宁店'),
          _DetailRow(label: '桌位', value: data.table),
          _DetailRow(label: '下单时间', value: data.createdAt),
          _DetailRow(label: '订单编号', value: 'KC••••$_maskedSuffix'),
        ],
      ),
    );
  }

  Widget _buildProductCard(_OrderDetailPresentation data) {
    return _LegacyOrderCard(
      key: const ValueKey('order-detail-products'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '商品明细',
            style: TextStyle(
              color: Color(0xFF181205),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...data.items.map(_buildProductRow),
        ],
      ),
    );
  }

  Widget _buildProductRow(_FakeOrderLine item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x16000000))),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              item.asset,
              width: 58,
              height: 72,
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
                    color: Color(0xFF181205),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.spec,
                  style: const TextStyle(
                    color: Color(0xFF6E604F),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '单价 ¥${item.unitPrice}',
                  style: const TextStyle(
                    color: Color(0xFF6E604F),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '数量 × ${item.quantity}',
                style: const TextStyle(color: Color(0xFF6E604F), fontSize: 10),
              ),
              const SizedBox(height: 8),
              Text(
                '小计 ¥${item.subtotal}',
                style: const TextStyle(
                  color: Color(0xFF181205),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(_OrderDetailPresentation data) {
    return _LegacyOrderCard(
      key: const ValueKey('order-detail-amounts'),
      child: Column(
        children: [
          _MoneyRow(label: '商品总价', amount: data.originalAmount),
          if (data.discount > 0)
            _MoneyRow(label: '优惠减免', amount: -data.discount),
          _MoneyRow(label: '应付金额', amount: data.paidAmount, strong: true),
          if (data.refundAmount > 0)
            _MoneyRow(
              label: '退款金额',
              amount: data.refundAmount,
              strong: true,
              refund: true,
            ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '金额为 Fake 权威详情投影，客户端未参与计算',
              style: TextStyle(color: Color(0xFF796A58), fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(_OrderDetailPresentation data) {
    return Container(
      key: const ValueKey('order-detail-timeline'),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF15110E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '订单进度',
            style: TextStyle(
              color: Color(0xFFE8DED1),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          ...data.timeline.indexed.map(
            (entry) => _TimelineRow(
              text: entry.$2.$1,
              time: entry.$2.$2,
              active: entry.$1 == 0,
              last: entry.$1 == data.timeline.length - 1,
              color: data.statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(_OrderDetailPresentation data) {
    final isReadOnly =
        _scenario == OrderDetailScenario.offlineCached ||
        _scenario == OrderDetailScenario.unknownStatus ||
        _resultUnknown;
    final canPay = data.canPay && !isReadOnly;
    final canCancel = data.canCancel && !isReadOnly;
    final canViewAdmission = data.canViewAdmission && !isReadOnly;
    return Container(
      key: const ValueKey('order-detail-actions'),
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0xF20B0907),
        border: Border(top: BorderSide(color: Color(0x334C4033))),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12)],
      ),
      child: Row(
        children: [
          TextButton(
            key: const ValueKey('order-contact-support'),
            onPressed: _contactSupport,
            child: const Text('联系客服'),
          ),
          const Spacer(),
          if (_resultUnknown)
            _ActionButton(
              key: const ValueKey('order-reconcile-cancel'),
              label: _submitting ? '查询中…' : '查询处理结果',
              primary: true,
              onPressed: _submitting ? null : _reconcileCancel,
            )
          else ...[
            if (canCancel)
              _ActionButton(
                key: const ValueKey('order-cancel'),
                label: _submitting ? '处理中…' : '取消订单',
                onPressed: _submitting ? null : _confirmCancel,
              ),
            if (canCancel && (canPay || canViewAdmission))
              const SizedBox(width: 8),
            if (canPay)
              _ActionButton(
                key: const ValueKey('order-pay'),
                label: '继续支付',
                primary: true,
                onPressed: _openPayment,
              ),
            if (canViewAdmission)
              _ActionButton(
                key: const ValueKey('order-admission'),
                label: '查看凭证',
                primary: true,
                onPressed: _openAdmission,
              ),
            if (!canCancel && !canPay && !canViewAdmission)
              _ActionButton(
                key: const ValueKey('order-refresh'),
                label: '刷新状态',
                onPressed: _refresh,
              ),
          ],
        ],
      ),
    );
  }

  Widget? get _banner {
    final data = switch (_scenario) {
      OrderDetailScenario.offlineCached => (
        Icons.cloud_off_rounded,
        '离线缓存 · 更新于 20:12 · 写操作已停用',
      ),
      OrderDetailScenario.unknownStatus => (
        Icons.help_outline_rounded,
        '状态暂未识别，详情已保留为只读',
      ),
      _ when _conflictResolved => (
        Icons.info_outline_rounded,
        '订单已更新为“已确认”，本次取消未执行',
      ),
      _ when _resultUnknown => (
        Icons.sync_problem_rounded,
        '取消结果暂不确定，请使用原请求查询结果',
      ),
      _ when _cancelledLocally => (
        Icons.check_circle_outline_rounded,
        'Fake 订单已取消，未发生真实退款',
      ),
      _ => null,
    };
    if (data == null) return null;
    return Container(
      key: const ValueKey('order-detail-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      color: const Color(0xFF30261B),
      child: Row(
        children: [
          Icon(data.$1, color: legacyGold, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data.$2,
              style: const TextStyle(color: legacyGold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeError() {
    return _DetailEmptyState(
      icon: Icons.receipt_long_outlined,
      title: '无法查看此订单',
      subtitle: '订单不存在、已失效或不属于当前账号时均显示此提示',
      action: '返回订单中心',
      onAction: widget.onBack,
    );
  }

  Widget _buildSessionInvalid() {
    return _DetailEmptyState(
      icon: Icons.lock_reset_rounded,
      title: '会话已失效',
      subtitle: '订单详情和动作引用已从当前页面清理',
      action: '重新登录',
      onAction: widget.onSessionResetRequested,
    );
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() {
      _scenario = _scenarioForRef(widget.orderRef);
      _conflictResolved = false;
      _resultUnknown = false;
      _cancelledLocally = false;
    });
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF201A15),
        title: const Text('确认取消订单？'),
        content: const Text('此处只演示 Fake 取消流程，不代表退款或付款已经完成。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('暂不取消'),
          ),
          FilledButton(
            key: const ValueKey('order-cancel-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _submitCancel();
  }

  Future<void> _submitCancel() async {
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 480));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (_scenario == OrderDetailScenario.cancelConflict) {
        _conflictResolved = true;
      } else if (_scenario == OrderDetailScenario.cancelResultUnknown) {
        _resultUnknown = true;
      } else {
        _cancelledLocally = true;
      }
    });
  }

  Future<void> _reconcileCancel() async {
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 480));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _resultUnknown = false;
      _cancelledLocally = true;
    });
  }

  void _openPayment() {
    final ref = 'payment-intent-${widget.orderRef.opaqueId}';
    if (widget.onPaymentIntent case final callback?) {
      callback(ref);
    } else {
      showFakeResult(context, '已生成继续支付意图 $ref');
    }
  }

  void _openAdmission() {
    final ref = 'admission-${widget.orderRef.opaqueId}';
    if (widget.onAdmission case final callback?) {
      callback(ref);
    } else {
      showFakeResult(context, '已生成入场凭证意图 $ref');
    }
  }

  void _contactSupport() {
    if (widget.onContactSupport case final callback?) {
      callback(widget.orderRef);
    } else {
      showFakeResult(context, '已生成客服支持意图');
    }
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
            children: OrderDetailScenario.values.map((scenario) {
              return ListTile(
                key: ValueKey('order-detail-scenario-${scenario.name}'),
                title: Text(_scenarioLabel(scenario)),
                trailing: scenario == _scenario
                    ? const Icon(Icons.check_rounded, color: legacyGold)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _scenario = scenario;
                    _submitting = false;
                    _cancelledLocally = false;
                    _conflictResolved = false;
                    _resultUnknown = false;
                  });
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String get _maskedSuffix {
    if (_presentation.title == _confirmedPresentation.title) return '0828';
    if (_presentation.title == _completedPresentation.title) return '0826';
    if (_presentation.title == _refundingPresentation.title) return '0825';
    if (_presentation.title == _refundedPresentation.title) return '0818';
    if (_presentation.title == _cancelledPresentation.title) return '0823';
    final raw = widget.orderRef.opaqueId;
    return raw.substring(raw.length > 4 ? raw.length - 4 : 0).toUpperCase();
  }

  _OrderDetailPresentation get _presentation {
    if (_cancelledLocally) return _cancelledPresentation;
    if (_conflictResolved) return _confirmedPresentation;
    return switch (_scenario) {
      OrderDetailScenario.confirmed => _confirmedPresentation,
      OrderDetailScenario.completed => _completedPresentation,
      OrderDetailScenario.refunding => _refundingPresentation,
      OrderDetailScenario.refunded => _refundedPresentation,
      OrderDetailScenario.cancelled => _cancelledPresentation,
      OrderDetailScenario.unknownStatus => _unknownPresentation,
      _ => _awaitingPaymentPresentation,
    };
  }
}

class _LegacyOrderCard extends StatelessWidget {
  const _LegacyOrderCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: legacyGold,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6E604F), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: const Color(0xFF181205),
                fontSize: emphasized ? 14 : 12,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amount,
    this.strong = false,
    this.refund = false,
  });

  final String label;
  final int amount;
  final bool strong;
  final bool refund;

  @override
  Widget build(BuildContext context) {
    final prefix = amount < 0 ? '-¥' : '¥';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: strong ? 7 : 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF4C4033),
              fontSize: strong ? 14 : 12,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const Spacer(),
          Text(
            '$prefix${amount.abs()}',
            style: TextStyle(
              color: refund ? const Color(0xFF76520B) : const Color(0xFF181205),
              fontSize: strong ? 20 : 13,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.text,
    required this.time,
    required this.active,
    required this.last,
    required this.color,
  });

  final String text;
  final String time;
  final bool active;
  final bool last;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: active ? 9 : 7,
                  height: active ? 9 : 7,
                  decoration: BoxDecoration(
                    color: active ? color : const Color(0xFF62594F),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 1, color: const Color(0xFF3E362F)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: active
                            ? const Color(0xFFE8DED1)
                            : const Color(0xFF8B8178),
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      color: Color(0xFF655D56),
                      fontSize: 10,
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
      height: 42,
      child: primary
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                backgroundColor: legacyGold,
                foregroundColor: const Color(0xFF181205),
                shape: const StadiumBorder(),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                foregroundColor: legacyGold,
                side: const BorderSide(color: Color(0xFF6D5D4C)),
                shape: const StadiumBorder(),
              ),
              child: Text(label),
            ),
    );
  }
}

class _DetailEmptyState extends StatelessWidget {
  const _DetailEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF756A5E), size: 58),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFE8DED1),
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF887F76),
                fontSize: 12,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 22),
            LegacyClubButton(label: action, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}

class _FakeOrderLine {
  const _FakeOrderLine({
    required this.name,
    required this.spec,
    required this.unitPrice,
    required this.quantity,
    required this.asset,
  });

  final String name;
  final String spec;
  final int unitPrice;
  final int quantity;
  final String asset;

  int get subtotal => unitPrice * quantity;
}

class _OrderDetailPresentation {
  const _OrderDetailPresentation({
    required this.type,
    required this.title,
    required this.table,
    required this.createdAt,
    required this.statusLabel,
    required this.statusHint,
    required this.statusColor,
    required this.items,
    required this.originalAmount,
    required this.discount,
    required this.paidAmount,
    required this.refundAmount,
    required this.timeline,
    this.canPay = false,
    this.canCancel = false,
    this.canViewAdmission = false,
  });

  final String type;
  final String title;
  final String table;
  final String createdAt;
  final String statusLabel;
  final String statusHint;
  final Color statusColor;
  final List<_FakeOrderLine> items;
  final int originalAmount;
  final int discount;
  final int paidAmount;
  final int refundAmount;
  final List<(String, String)> timeline;
  final bool canPay;
  final bool canCancel;
  final bool canViewAdmission;
}

const _scanItems = <_FakeOrderLine>[
  _FakeOrderLine(
    name: '星光香槟',
    spec: '750ml · 冰桶与香槟杯',
    unitPrice: 668,
    quantity: 1,
    asset: 'assets/legacy/ordering/product_champagne_v1.png',
  ),
  _FakeOrderLine(
    name: '金标威士忌',
    spec: '700ml · 经典调饮套装',
    unitPrice: 488,
    quantity: 1,
    asset: 'assets/legacy/ordering/product_whisky_v1.png',
  ),
];

const _awaitingPaymentPresentation = _OrderDetailPresentation(
  type: '扫码点单',
  title: 'KINGBAR V8 桌点单',
  table: 'V8 卡座',
  createdAt: '2026-08-27 20:18',
  statusLabel: '待支付',
  statusHint: '订单已创建，请在剩余 12:36 内完成支付',
  statusColor: Color(0xFFFFB400),
  items: _scanItems,
  originalAmount: 1216,
  discount: 60,
  paidAmount: 1156,
  refundAmount: 0,
  timeline: [('等待支付', '20:18'), ('订单已创建', '20:18'), ('扫码进入 V8 桌', '20:16')],
  canPay: true,
  canCancel: true,
);

const _confirmedPresentation = _OrderDetailPresentation(
  type: 'VIP组局',
  title: 'A6 卡座搭子局',
  table: 'A6 卡座 · 08月28日 20:30',
  createdAt: '2026-08-27 18:42',
  statusLabel: '已确认',
  statusHint: '席位已经确认，可在入场时出示凭证',
  statusColor: Color(0xFF72DDB2),
  items: [
    _FakeOrderLine(
      name: '星光香槟套餐',
      spec: 'VIP 卡座套餐 · 1个席位',
      unitPrice: 688,
      quantity: 1,
      asset: 'assets/legacy/ordering/product_champagne_v1.png',
    ),
  ],
  originalAmount: 688,
  discount: 0,
  paidAmount: 688,
  refundAmount: 0,
  timeline: [('席位已确认', '18:44'), ('支付已确认', '18:43'), ('订单已创建', '18:42')],
  canViewAdmission: true,
);

const _completedPresentation = _OrderDetailPresentation(
  type: '一起玩AA',
  title: '星光香槟套餐',
  table: 'V2 卡座 · 08月26日 20:30',
  createdAt: '2026-08-25 21:06',
  statusLabel: '已完成',
  statusHint: '本次卡座活动已经完成',
  statusColor: Color(0xFFAAA199),
  items: [
    _FakeOrderLine(
      name: '星光香槟套餐',
      spec: 'AA 席位 · 1人',
      unitPrice: 168,
      quantity: 1,
      asset: 'assets/legacy/ordering/product_champagne_v1.png',
    ),
  ],
  originalAmount: 168,
  discount: 0,
  paidAmount: 168,
  refundAmount: 0,
  timeline: [('活动已完成', '08月27日'), ('已核验入场', '08月26日'), ('订单已确认', '08月25日')],
);

const _refundingPresentation = _OrderDetailPresentation(
  type: '扫码点单',
  title: 'V2 桌鲜果盘加购',
  table: 'V2 卡座',
  createdAt: '2026-08-25 22:16',
  statusLabel: '退款中',
  statusHint: '¥88 正在按原支付路径处理，请留意后续状态',
  statusColor: Color(0xFFFFC761),
  items: [
    _FakeOrderLine(
      name: '缤纷鲜果盘',
      spec: '时令水果 · 大份',
      unitPrice: 88,
      quantity: 1,
      asset: 'assets/legacy/ordering/product_fruit_platter_v1.png',
    ),
  ],
  originalAmount: 88,
  discount: 0,
  paidAmount: 88,
  refundAmount: 88,
  timeline: [('退款处理中', '08月27日'), ('退款申请已受理', '08月26日'), ('支付已确认', '08月25日')],
);

const _refundedPresentation = _OrderDetailPresentation(
  type: '一起玩AA',
  title: '周末微醉套餐',
  table: 'B5 卡座 · 08月18日 20:30',
  createdAt: '2026-08-17 19:12',
  statusLabel: '已退款',
  statusHint: '¥198 已退回原支付路径',
  statusColor: Color(0xFFAAA199),
  items: [
    _FakeOrderLine(
      name: '周末微醉套餐',
      spec: 'AA 席位 · 1人',
      unitPrice: 198,
      quantity: 1,
      asset: 'assets/legacy/ordering/product_champagne_v1.png',
    ),
  ],
  originalAmount: 198,
  discount: 0,
  paidAmount: 198,
  refundAmount: 198,
  timeline: [('退款已完成', '08月20日'), ('退款处理中', '08月19日'), ('订单已确认', '08月17日')],
);

const _cancelledPresentation = _OrderDetailPresentation(
  type: 'VIP组局',
  title: 'C3 夏日音乐局',
  table: 'C3 卡座 · 08月23日 21:00',
  createdAt: '2026-08-22 17:30',
  statusLabel: '已取消',
  statusHint: '订单已经取消，不再保留席位',
  statusColor: Color(0xFFAAA199),
  items: [
    _FakeOrderLine(
      name: '夏日音乐局套餐',
      spec: 'VIP 卡座套餐 · 1个席位',
      unitPrice: 398,
      quantity: 1,
      asset: 'assets/legacy/ordering/product_whisky_v1.png',
    ),
  ],
  originalAmount: 398,
  discount: 0,
  paidAmount: 398,
  refundAmount: 0,
  timeline: [('订单已取消', '08月22日 17:42'), ('订单已创建', '08月22日 17:30')],
);

const _unknownPresentation = _OrderDetailPresentation(
  type: '扫码点单',
  title: 'KINGBAR 桌台消费',
  table: '桌位信息待更新',
  createdAt: '2026-08-27 19:52',
  statusLabel: '状态更新中',
  statusHint: '服务端返回了暂未识别的状态，当前详情只读',
  statusColor: Color(0xFFAAA199),
  items: [
    _FakeOrderLine(
      name: '缤纷鲜果盘',
      spec: '商品信息已缓存',
      unitPrice: 268,
      quantity: 1,
      asset: 'assets/legacy/ordering/product_fruit_platter_v1.png',
    ),
  ],
  originalAmount: 268,
  discount: 0,
  paidAmount: 268,
  refundAmount: 0,
  timeline: [('等待状态同步', '19:52')],
);

OrderDetailScenario _scenarioForRef(FakeOrderRef ref) {
  final id = ref.opaqueId;
  if (id.contains('vip-a6')) return OrderDetailScenario.confirmed;
  if (id.contains('aa-v2')) return OrderDetailScenario.completed;
  if (id.contains('fruit')) return OrderDetailScenario.refunding;
  if (id.contains('vip-c3')) return OrderDetailScenario.cancelled;
  if (id.contains('aa-b5')) return OrderDetailScenario.refunded;
  if (id.contains('unknown')) return OrderDetailScenario.unknownStatus;
  return OrderDetailScenario.awaitingPayment;
}

String _scenarioLabel(OrderDetailScenario scenario) => switch (scenario) {
  OrderDetailScenario.awaitingPayment => '待支付',
  OrderDetailScenario.confirmed => '已确认 / 查看凭证',
  OrderDetailScenario.completed => '已完成',
  OrderDetailScenario.refunding => '退款中',
  OrderDetailScenario.refunded => '已退款',
  OrderDetailScenario.cancelled => '已取消',
  OrderDetailScenario.offlineCached => '离线缓存',
  OrderDetailScenario.unknownStatus => '未知状态',
  OrderDetailScenario.invalidRef => '无效或越权引用',
  OrderDetailScenario.sessionInvalid => '会话失效',
  OrderDetailScenario.cancelConflict => '取消时状态冲突',
  OrderDetailScenario.cancelResultUnknown => '取消结果未知',
};
