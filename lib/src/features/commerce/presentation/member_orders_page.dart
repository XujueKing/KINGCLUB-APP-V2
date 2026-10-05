import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/member_orders_repository.dart';
import '../data/ordering_catalog_repository.dart';
import '../../../core/media/cached_media_image.dart';

typedef MemberOrdersLoad = Future<MemberOrdersSnapshot> Function({
  String? orderRef,
  String? beforeOrder,
});

class MemberOrdersPage extends StatefulWidget {
  const MemberOrdersPage({
    super.key,
    required this.onBack,
    this.onOpenOrder,
    this.orderRef,
    this.load,
    this.events,
    this.title,
    this.expandItems = false,
    this.tableBill = false,
    this.tableStoreName,
    this.tableName,
    this.products = const [],
    this.refreshInterval,
    this.retainDuringRefresh = false,
  });
  final String? title;
  final bool expandItems;
  final bool tableBill;
  final String? tableStoreName, tableName;
  final List<OrderingCatalogProduct> products;
  final Duration? refreshInterval;
  final bool retainDuringRefresh;
  final VoidCallback onBack;
  final ValueChanged<String>? onOpenOrder;
  final String? orderRef;
  final MemberOrdersLoad? load;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<MemberOrdersPage> createState() => _MemberOrdersPageState();
}

class _MemberOrdersPageState extends State<MemberOrdersPage>
    with WidgetsBindingObserver {
  List<MemberOrder> orders = [];
  String? next;
  bool loading = false, failed = false, foreground = true, queued = false;
  int epoch = 0;
  String? failureCode;
  Timer? debounce;
  Timer? refreshTimer;
  StreamSubscription<void>? sessionChanges;
  StreamSubscription<Map<String, dynamic>>? changes;
  late final repository = MemberOrdersRepository.secure(kingclubApiBaseUrl);
  int get language {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'en'
        ? 1
        : locale.languageCode == 'th'
        ? 3
        : locale.scriptCode == 'Hant' ||
              ['TW', 'HK', 'MO'].contains(locale.countryCode)
        ? 2
        : 0;
  }

  String t(String key) => _copy[key]!.split('|')[language];
  String get localeKey => ['zh-CN', 'en', 'zh-TW', 'th'][language];
  String money(int value) =>
      '¥${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    sessionChanges = SecureSessionStore.changes.stream.listen((_) {
      invalidate();
      if (foreground) unawaited(reload());
    });
    subscribe();
    startRefreshTimer();
    if (foreground) unawaited(reload());
  }

  void subscribe() {
    changes?.cancel();
    changes = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      if (!foreground ||
          !mounted ||
          ![
            'connection.ready',
            'commerce.changed',
          ].contains(event['eventType'])) {
        return;
      }
      // Notifications invalidate the view; amounts and ownership always come
      // from the authenticated super-interface, never from event payloads.
      queued = true;
      schedule();
    });
  }

  void startRefreshTimer() {
    refreshTimer?.cancel();
    refreshTimer = null;
    final interval = widget.refreshInterval;
    if (!foreground || interval == null || interval <= Duration.zero) return;
    refreshTimer = Timer.periodic(interval, (_) {
      if (!mounted || !foreground) return;
      queued = true;
      schedule();
    });
  }

  @override
  void didUpdateWidget(covariant MemberOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) subscribe();
    if (oldWidget.refreshInterval != widget.refreshInterval) {
      startRefreshTimer();
    }
    if (oldWidget.orderRef != widget.orderRef ||
        oldWidget.load != widget.load) {
      invalidate();
      if (foreground) unawaited(reload());
    }
  }

  void invalidate({bool retain = false}) {
    epoch++;
    debounce?.cancel();
    debounce = null;
    queued = false;
    if (mounted) {
      setState(() {
        if (!retain) {
          orders = [];
          next = null;
        }
        loading = false;
        failed = false;
      });
    }
  }

  void schedule() {
    if (!mounted || !foreground || loading || !queued || debounce != null) {
      return;
    }
    debounce = Timer(const Duration(milliseconds: 350), () {
      debounce = null;
      if (mounted && foreground && queued && !loading) {
        queued = false;
        unawaited(reload());
      }
    });
  }

  Future<void> reload({bool more = false}) async {
    if (!mounted || !foreground || loading || (more && next == null)) return;
    final ticket = ++epoch, generation = MemberQrMemory.generation;
    final cursor = more ? next : null;
    final previous = more ? orders : <MemberOrder>[];
    setState(() {
      loading = true;
      failed = false;
      if (!more && !widget.retainDuringRefresh) {
        orders = [];
        next = null;
      }
    });
    bool current() =>
        mounted &&
        foreground &&
        ticket == epoch &&
        generation == MemberQrMemory.generation;
    try {
      var data = await (widget.load ?? repository.read)(
        orderRef: widget.orderRef,
        beforeOrder: cursor,
      );
      if (!current()) return;
      final merged = [...previous, ...data.orders];
      final seen = <String>{};
      for (final order in merged) {
        if (!seen.add(order.orderRef)) {
          throw const FormatException('Overlapping order page');
        }
      }
      // Never present a partial page as a complete table total.
      while (widget.tableBill && data.nextBeforeOrder != null) {
        data = await (widget.load ?? repository.read)(
          beforeOrder: data.nextBeforeOrder,
        );
        if (!current()) return;
        for (final order in data.orders) {
          if (!seen.add(order.orderRef)) {
            throw const FormatException('Overlapping order page');
          }
          merged.add(order);
        }
      }
      setState(() {
        orders = merged;
        next = data.nextBeforeOrder;
        loading = false;
      });
    } catch (error) {
      if (!current()) return;
      setState(() {
        orders = [];
        next = null;
        failed = true;
        failureCode = error is AuthFailure ? error.code : null;
        loading = false;
      });
    } finally {
      if (current()) schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    startRefreshTimer();
    invalidate(retain: widget.retainDuringRefresh);
    if (foreground) unawaited(reload());
  }

  @override
  void dispose() {
    epoch++;
    refreshTimer?.cancel();
    debounce?.cancel();
    sessionChanges?.cancel();
    changes?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String status(MemberOrder order) => order.refundedCents > 0
      ? t(order.fullyRefunded ? 'refunded' : 'partialRefund')
      : order.status == 'waived'
      ? t('waived')
      : order.status == 'paid'
      ? t('paid')
      : order.status == 'expired'
      ? t('expired')
      : order.paymentTiming == 'postpay'
      ? t('postpayPending')
      : t('prepayPending');
  String deliveryText(MemberOrder order, MemberOrderItem item) {
    if (order.fullyRefunded) return '${t('returned')} ${item.quantity}';
    if ((item.refundedQuantity ?? 0) == 0) {
      return '${t('served')} ${item.servedQuantity}/${item.quantity}';
    }
    return '${t('served')} ${item.servedQuantity}/${item.activeQuantity} · '
        '${t('unserved')} ${item.remainingQuantity} · ${t('returned')} ${item.refundedQuantity}';
  }

  Widget orderCard(MemberOrder order) {
    final detail = widget.orderRef != null;
    if (detail) return orderReceipt(order);
    final color = order.refundedCents > 0 || order.status == 'expired'
        ? Colors.grey
        : order.status == 'paid'
        ? const Color(0xFF75D5A2)
        : const Color(0xFFFFC35C);
    return Card(
      key: ValueKey('member-order-${order.orderRef}'),
      color: const Color(0x0FFFFFFF),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: detail || widget.onOpenOrder == null
            ? null
            : () => widget.onOpenOrder!(order.orderRef),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      order.storeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      status(order),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.tableName} · ${t(order.source)} · ${t(order.paymentTiming)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              if (detail || widget.expandItems)
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.names[localeKey]!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '×${item.quantity}  ${money(item.quantity * item.priceCents)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        Text(
                          item.specifications[localeKey]!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          deliveryText(order, item),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  order.items
                      .map(
                        (item) => '${item.names[localeKey]} ×${item.quantity}',
                      )
                      .join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              const Divider(color: Colors.white12, height: 24),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 6,
                children: [
                  Text(
                    order.createdAt.toLocal().toString().substring(0, 16),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    '${t('total')} ${money(order.status == 'paid' ? order.netPaidCents : order.totalCents)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (order.refundedCents > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${t('refunded')} ${money(order.refundedCents)} · ${t('netPaid')} ${money(order.netPaidCents)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              if (detail || widget.expandItems)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SelectableText(
                    '${t('orderNumber')} ${order.orderRef}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              if (detail &&
                  order.status == 'pending' &&
                  order.source == 'cashier')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    t('cashierPayment'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget tableReceipt() {
    const ink = Color(0xFFDDDDDD);
    final payments = orders
        .where((o) => o.status == 'paid' && o.paidAt != null)
        .toList();
    final lines =
        <
          String,
          ({
            MemberOrderItem item,
            int quantity,
            int served,
            int cents,
            Set<int> prices,
          })
        >{};
    for (final order in orders) {
      if (order.status != 'paid' || order.fullyRefunded) continue;
      for (final item in order.items) {
        if (item.activeQuantity == 0) continue;
        final old = lines[item.productRef];
        lines[item.productRef] = (
          item: old?.item ?? item,
          quantity: (old?.quantity ?? 0) + item.activeQuantity,
          served: (old?.served ?? 0) + item.servedQuantity,
          cents: (old?.cents ?? 0) + item.activeQuantity * item.priceCents,
          prices: {...?old?.prices, item.priceCents},
        );
      }
    }
    Widget field(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(width: 16),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
    Widget card(String key, List<Widget> children) => Container(
      key: ValueKey(key),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: ink,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
    return Column(
      children: [
        card('table-bill-store', [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(t('store')),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Image.asset(
                        'assets/legacy/messaging/notification_kingclub.png',
                        key: const ValueKey('table-store-logo'),
                        width: 28,
                        height: 28,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.tableStoreName ?? '',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          field(t('table'), widget.tableName ?? ''),
        ]),
        card('table-bill-products', [
          Text(t('products')),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(t('tableEmpty')),
            ),
          for (final line in lines.values)
            Builder(
              builder: (context) {
                final item = line.item;
                final product = widget.products
                    .where((p) => p.reference == item.productRef)
                    .firstOrNull;
                final english = item.names['en'];
                final detail = language == 0 || language == 2
                    ? [
                        if (english != null && english != item.names[localeKey])
                          english,
                        item.specifications[localeKey]!,
                      ].join(' · ')
                    : item.specifications[localeKey]!;
                return Container(
                  key: ValueKey('table-bill-product-${item.productRef}'),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF303030)),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 38,
                        height: 60,
                        child: product?.thumbnailUrl == null
                            ? const Icon(Icons.local_bar_outlined, color: ink)
                            : CachedMediaImage(
                                product!.thumbnailUrl!,
                                contentKey: product.imageCacheKey,
                                private: true,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.local_bar_outlined,
                                  color: ink,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.names[localeKey]!),
                            Text(
                              detail,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFAAAAAA),
                              ),
                            ),
                            Text(
                              '${t('unitPrice')} ${(line.prices.toList()..sort()).map(money).join(' / ')}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFAAAAAA),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 125),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (line.served == line.quantity &&
                                    line.quantity > 0) ...[
                                  SvgPicture.string(
                                    '<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg"><circle cx="512" cy="512" r="500" fill="#FFFFFF"/><path d="M512 1024A512 512 0 1 1 512 0a512 512 0 0 1 0 1024zM448 605.12L277.312 442.176 192 523.648 448 768l384-366.528L746.688 320 448 605.12z" fill="#24A65A"/></svg>',
                                    key: ValueKey(
                                      'table-bill-served-${item.productRef}',
                                    ),
                                    width: 14,
                                    height: 14,
                                    excludeFromSemantics: true,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  '${t('quantity')} × ${line.quantity}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFAAAAAA),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              money(line.cents),
                              style: const TextStyle(fontSize: 17),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text(t('productTotal'))),
              const SizedBox(width: 12),
              Text(
                money(
                  lines.values.fold<int>(0, (sum, line) => sum + line.cents),
                ),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ]),
        if (orders.any((o) => o.status == 'paid' && o.paidAt != null))
          card('table-bill-payments', [
            Text(t('payments')),
            for (final order in payments)
              GestureDetector(
                key: ValueKey('table-payment-${order.orderRef}'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.onOpenOrder == null
                    ? null
                    : () => widget.onOpenOrder!(order.orderRef),
                child: Container(
                  decoration: BoxDecoration(
                    border: order == payments.last
                        ? null
                        : const Border(
                            bottom: BorderSide(color: Color(0xFF383838)),
                          ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (order.paymentChannel == 'wechat') ...[
                            Image.asset(
                              'assets/legacy/ordering/WEIPAY.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              t(
                                order.combinedPayment
                                    ? 'pay_mixed'
                                    : 'pay_${order.paymentChannel}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            money(order.paidCents!),
                            style: const TextStyle(fontSize: 17),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        order.paymentChannel == 'wechat'
                            ? '${t('wechatTransaction')} ${order.transactionId ?? '—'}'
                            : '${t('orderNumber')} ${order.orderRef}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFAAAAAA),
                        ),
                      ),
                      Text(
                        order.paidAt!.toLocal().toString().split('.').first,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFAAAAAA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ]),
      ],
    );
  }

  Widget orderReceipt(MemberOrder order) {
    String date(DateTime value) {
      final d = value.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}/${two(d.month)}/${two(d.day)} '
          '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
    }

    Widget field(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
    Widget panel(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
    return Column(
      key: ValueKey('member-order-${order.orderRef}'),
      children: [
        panel(
          Column(
            children: [
              const SizedBox(height: 12),
              ClipOval(
                child: Image.asset(
                  'assets/legacy/messaging/notification_kingclub.png',
                  width: 64,
                  height: 64,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                order.storeName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 18),
              ),
              const SizedBox(height: 24),
              Text(
                '${order.status == 'paid' ? '−' : ''}${money(order.status == 'paid' ? order.netPaidCents : order.totalCents)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              const Divider(color: Color(0x14FFFFFF), height: 24),
              field(t('currentStatus'), status(order)),
              field(t('createdAt'), date(order.createdAt)),
              field(t('store'), order.storeName),
              field(t('table'), order.tableName),
              field(t('source'), t(order.source)),
              field(t('paymentTiming'), t(order.paymentTiming)),
              field(t('orderNumber'), order.orderRef),
              if (order.paymentChannel == 'wechat')
                field(t('wechatTransaction'), order.transactionId ?? '—'),
              if (order.paymentComposition != null) ...[
                if (order.component('couponDiscountCents') > 0)
                  field(
                    t('couponDiscount'),
                    money(order.component('couponDiscountCents')),
                  ),
                if (order.component('coinSubsidyCents') > 0)
                  field(
                    t('coinPayment'),
                    money(order.component('coinSubsidyCents')),
                  ),
                if (order.component('storePrincipalCents') +
                        order.component('storeGiftCents') >
                    0)
                  field(
                    t('storePayment'),
                    money(
                      order.component('storePrincipalCents') +
                          order.component('storeGiftCents'),
                    ),
                  ),
                if (order.component('platformCashCents') > 0)
                  field(
                    t('platformPayment'),
                    money(order.component('platformCashCents')),
                  ),
                if (order.component('externalCents') > 0)
                  field(
                    t('pay_${order.paymentChannel}'),
                    money(order.component('externalCents')),
                  ),
              ],
              if (order.refundedCents > 0) ...[
                field(t('refunded'), money(order.refundedCents)),
                field(t('netPaid'), money(order.netPaidCents)),
                if (order.refundedAt != null)
                  field(t('refundedAt'), date(order.refundedAt!)),
              ],
              if (order.status == 'pending' && order.source == 'cashier')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    t('cashierPayment'),
                    style: const TextStyle(color: Color(0x80FFFFFF)),
                  ),
                ),
            ],
          ),
        ),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('products'),
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 16),
              ),
              const SizedBox(height: 12),
              for (final item in order.items) ...[
                const Divider(color: Color(0x14FFFFFF), height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.names[localeKey]!,
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '×${item.quantity}',
                      style: const TextStyle(color: Color(0xCCFFFFFF)),
                    ),
                  ],
                ),
                if (item.specifications[localeKey]!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      item.specifications[localeKey]!,
                      style: const TextStyle(
                        color: Color(0x80FFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          deliveryText(order, item),
                          style: const TextStyle(
                            color: Color(0x80FFFFFF),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        money(item.quantity * item.priceCents),
                        style: const TextStyle(color: Color(0xCCFFFFFF)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101010),
    appBar: kingAppBar(
      context: context,
      title: Text(
        widget.title ?? t(widget.orderRef == null ? 'title' : 'detail'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: const Color(0xFF101010),
      foregroundColor: Colors.white,
      leading: KingBackButton(onPressed: widget.onBack),
      actions: [
        if (widget.orderRef == null && !widget.tableBill)
          IconButton(
            key: const ValueKey('member-orders-refresh'),
            tooltip: t('refresh'),
            onPressed: loading || !foreground
                ? null
                : () => unawaited(reload()),
            icon: const Icon(Icons.refresh),
          ),
      ],
    ),
    body: !foreground && !widget.retainDuringRefresh
        ? const SizedBox.shrink()
        : loading && orders.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : failed
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t(switch (failureCode) {
                      'MEMBER_TABLE_BILL_UNAVAILABLE' => 'tableUnavailable',
                      'MEMBER_ORDER_NOT_FOUND' when widget.tableBill =>
                        'tableAccess',
                      'SESSION_EXPIRED' ||
                      'SESSION_CHANGED' => 'sessionExpired',
                      _ => 'failed',
                    }),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => unawaited(reload()),
                    child: Text(t('refresh')),
                  ),
                ],
              ),
            ),
          )
        : widget.tableBill
        ? RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(10),
              children: [tableReceipt()],
            ),
          )
        : orders.isEmpty
        ? Center(
            child: Text(
              t('empty'),
              style: const TextStyle(color: Colors.white70),
            ),
          )
        : RefreshIndicator(
            onRefresh: reload,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(widget.tableBill ? 10 : 16),
              itemCount: orders.length + (next == null ? 0 : 1),
              itemBuilder: (context, index) => index < orders.length
                  ? orderCard(orders[index])
                  : Center(
                      child: TextButton(
                        onPressed: loading
                            ? null
                            : () => unawaited(reload(more: true)),
                        child: loading
                            ? const CircularProgressIndicator()
                            : Text(t('more')),
                      ),
                    ),
            ),
          ),
  );
}

const _copy = {
  'tableUnavailable': '当前桌台场次已结束或不可用，请返回重新扫码|This table session is no longer available. Go back and scan again.|目前桌台場次已結束或無法使用，請返回重新掃碼|รอบการใช้โต๊ะนี้สิ้นสุดแล้วหรือไม่พร้อมใช้งาน โปรดย้อนกลับแล้วสแกนใหม่',
  'tableAccess': '暂时无法查看本桌账单，请返回重新扫码|This table bill is unavailable. Go back and scan again.|暫時無法查看本桌帳單，請返回重新掃碼|ไม่สามารถดูบิลโต๊ะนี้ได้ โปรดย้อนกลับแล้วสแกนใหม่',
  'sessionExpired': '登录已失效，请重新登录后查看|Your session has expired. Please log in again.|登入已失效，請重新登入後查看|เซสชันหมดอายุ โปรดเข้าสู่ระบบอีกครั้ง',
  'title': '我的订单|My orders|我的訂單|คำสั่งซื้อของฉัน',
  'detail': '订单详情|Order details|訂單詳情|รายละเอียดคำสั่งซื้อ',
  'refresh': '刷新|Refresh|重新整理|รีเฟรช',
  'more': '加载更多|Load more|載入更多|โหลดเพิ่มเติม',
  'failed': '订单暂时无法读取，请刷新重试|Orders are unavailable. Please refresh.|訂單暫時無法讀取，請重新整理|ยังโหลดคำสั่งซื้อไม่ได้ โปรดรีเฟรช',
  'empty': '暂无订单|No orders yet|暫無訂單|ยังไม่มีคำสั่งซื้อ',
  'cashier': '收银代点|Ordered at cashier|收銀代點|สั่งผ่านแคชเชียร์',
  'app': 'APP 点单|Ordered in app|APP 點單|สั่งผ่านแอป',
  'prepay': '先付款|Pay first|先付款|ชำระก่อน',
  'postpay': '后结账|Pay later|後結帳|ชำระภายหลัง',
  'prepayPending': '待付款|Awaiting payment|待付款|รอชำระเงิน',
  'postpayPending': '待结账|Awaiting checkout|待結帳|รอคิดเงิน',
  'paid': '已支付|Paid|已支付|ชำระแล้ว',
  'waived': '免单|Complimentary|免單|ฟรี',
  'expired': '已失效|Expired|已失效|หมดอายุ',
  'refunded': '已退款|Refunded|已退款|คืนเงินแล้ว',
  'partialRefund': '部分退款|Partially refunded|部分退款|คืนเงินบางส่วน',
  'returned': '已退|Returned|已退|คืนแล้ว',
  'unserved': '未上|Unserved|未上|ยังไม่เสิร์ฟ',
  'netPaid': '剩余实收|Net paid|剩餘實收|ยอดรับสุทธิ',
  'served': '已上|Served|已上|เสิร์ฟแล้ว',
  'total': '合计|Total|合計|รวม',
  'wechatTransaction':
      '微信支付流水号|WeChat Pay transaction ID|微信支付流水號|หมายเลขธุรกรรม WeChat Pay',
  'orderNumber': '订单号|Order number|訂單號|เลขคำสั่งซื้อ',
  'currentStatus': '当前状态|Status|目前狀態|สถานะ',
  'createdAt': '订单时间|Order time|訂單時間|เวลาสั่งซื้อ',
  'store': '门店|Store|門店|ร้าน',
  'table': '卡座|Table|卡座|โต๊ะ',
  'source': '订单来源|Source|訂單來源|ช่องทาง',
  'paymentTiming': '付款模式|Payment timing|付款模式|รูปแบบชำระเงิน',
  'refundedAt': '退款时间|Refund time|退款時間|เวลาคืนเงิน',
  'quantity': '数量|Qty|數量|จำนวน',
  'payments': '支付记录|Payments|支付記錄|ประวัติการชำระเงิน',
  'pay_wechat': '微信支付|WeChat Pay|微信支付|WeChat Pay',
  'pay_alipay': '支付宝|Alipay|支付寶|Alipay',
  'pay_cash': '现金|Cash|現金|เงินสด',
  'pay_balance': '余额支付|Balance|餘額支付|ชำระด้วยยอดคงเหลือ',
  'pay_pos': 'POS刷卡|Card (POS)|POS刷卡|บัตร (POS)',
  'pay_mixed': '组合支付|Combined payment|組合支付|การชำระเงินแบบผสม',
  'couponDiscount': '优惠券减免|Coupon discount|優惠券減免|ส่วนลดคูปอง',
  'coinPayment': '金币抵扣|Coins applied|金幣抵扣|หักด้วยเหรียญ',
  'storePayment': '本店储值|Store balance|本店儲值|ยอดเงินของร้าน',
  'platformPayment': '平台余额|Platform balance|平台餘額|ยอดเงินแพลตฟอร์ม',
  'pay_other': '其他支付|Other payment|其他支付|การชำระเงินอื่น',
  'productTotal': '商品总价|Items total|商品總價|ยอดรวมสินค้า',
  'tableEmpty': '本桌暂无已付款商品|No paid items for this table|本桌暫無已付款商品|ยังไม่มีสินค้าที่ชำระเงินแล้วสำหรับโต๊ะนี้',
  'unitPrice': '单价|Unit price|單價|ราคาต่อหน่วย',
  'products': '商品明细|Items|商品明細|รายการสินค้า',
  'cashierPayment': '请在收银台核对并结账|Please check and settle at the cashier.|請在收銀台核對並結帳|กรุณาตรวจสอบและชำระที่แคชเชียร์',
};
