import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/media/cached_media_image.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/ordering_order_repository.dart';
import 'scan_ordering_cart_page.dart';

/// SDK completion is only a reason to query; only the server can confirm payment.
class LiveOrderPaymentPage extends StatefulWidget {
  const LiveOrderPaymentPage({
    super.key,
    required this.quote,
    required this.repository,
    required this.onBack,
  });
  final FakeOrderingQuote quote;
  final OrderingOrderRepository repository;
  final VoidCallback onBack;
  @override
  State<LiveOrderPaymentPage> createState() => _LiveOrderPaymentPageState();
}

class _LiveOrderPaymentPageState extends State<LiveOrderPaymentPage>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('kingclub/wechat-payment');
  static const _storage = FlutterSecureStorage();
  String _requestId = const Uuid().v4();
  String? _storageKey;
  String? _scope;
  OrderingOrderReceipt? _receipt;
  bool _busy = false, _checking = false, _ready = false;
  bool _confirmed = false;
  String? _message;
  Timer? _timer;
  int get _total =>
      widget.quote.items.fold(0, (sum, item) => sum + item.subtotalCents);
  String _money(int cents) => (cents / 100).toStringAsFixed(2);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  Future<void> _restore() async {
    try {
      final session = await widget.repository.readSession();
      final account = session?['account'];
      if (account is! Map || account['userAccount'] is! String) {
        throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
      }
      _storageKey =
          'commerce.pending.${account['userAccount']}.${widget.quote.orderingContext!.tableSessionRef}';
      _scope = jsonEncode(
        widget.quote.items
            .map(
              (i) => [
                i.catalogProduct?.reference,
                i.catalogProduct?.revision,
                i.quantity,
                i.unitPriceCents,
              ],
            )
            .toList(),
      );
      final saved = await _storage.read(key: _storageKey!);
      if (saved != null) {
        final value = jsonDecode(saved);
        if (value is Map &&
            value['scope'] == _scope &&
            value['requestId'] is String) {
          _requestId = value['requestId'];
        }
        if (value is Map && value['requestId'] is String) {
          _receipt = value['orderRef'] is String
              ? await widget.repository.owned(
                  context: widget.quote.orderingContext!,
                  orderRef: value['orderRef'],
                )
              : await widget.repository.findByRequest(
                  context: widget.quote.orderingContext!,
                  requestId: value['requestId'],
                );
          if (_receipt == null) {
            await _storage.delete(key: _storageKey!);
            _requestId = const Uuid().v4();
            if (mounted) setState(() => _ready = true);
            return;
          }
          if (_receipt!.status == 'paid' || _receipt!.status == 'expired') {
            await _storage.delete(key: _storageKey!);
            _receipt = null;
            _requestId = const Uuid().v4();
          } else if (value['scope'] != _scope) {
            _message = '此桌还有一笔待付款订单，请先确认该订单状态，再重新选购。';
            _ready = false;
            if (mounted) setState(() {});
            _startPolling();
            return;
          }
        }
      }
      if (mounted) setState(() => _ready = true);
      if (_receipt != null) _startPolling();
    } catch (_) {
      if (mounted) setState(() => _message = '暂时无法恢复订单，请返回后重试');
    }
  }

  Future<void> _save() async {
    await _storage.write(
      key: _storageKey!,
      value: jsonEncode({
        'scope': _scope,
        'requestId': _requestId,
        'orderRef': _receipt?.orderRef,
      }),
    );
  }

  void _startPolling() {
    _timer ??= Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      if (_receipt != null) _startPolling();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _refresh() async {
    if (_checking || _receipt == null || !mounted) return;
    _checking = true;
    try {
      final next = await widget.repository.owned(
        context: widget.quote.orderingContext!,
        orderRef: _receipt!.orderRef,
      );
      if (!mounted) return;
      setState(() {
        _receipt = next;
        if (next.status == 'paid') {
          _message = '支付成功，订单已提交门店';
        } else if (next.status == 'expired') {
          _message = '订单已关闭，未扣款的库存已释放';
        }
      });
      if (next.status == 'paid' && !_confirmed) {
        _confirmed = true;
        widget.quote.onPaymentConfirmed?.call();
      }
      if (next.status == 'paid' || next.status == 'expired') {
        _timer?.cancel();
        _timer = null;
        await _storage.delete(key: _storageKey!);
      }
    } catch (_) {
      if (mounted) setState(() => _message = '支付结果确认中，请稍后刷新，不要重复下单');
    } finally {
      _checking = false;
    }
  }

  Future<void> _pay() async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _save(); // Persist the idempotency key before the first network attempt.
      final lines = widget.quote.items.map((item) {
        if (item.catalogProduct == null) {
          throw const AuthFailure('PRODUCT_INVALID', '请返回重新选择商品');
        }
        return OrderingOrderLine(
          product: item.catalogProduct!,
          quantity: item.quantity,
        );
      }).toList();
      final receipt = await widget.repository.submit(
        context: widget.quote.orderingContext!,
        requestId: _requestId,
        lines: lines,
      );
      if (!mounted) return;
      setState(() => _receipt = receipt);
      await _save();
      if (receipt.status == 'paid' || receipt.status == 'expired') {
        await _refresh();
        return;
      }
      _startPolling();
      if (receipt.payment == null) {
        setState(() => _message = '订单已创建，正在确认支付状态');
        return;
      }
      final launched = await _channel.invokeMethod<bool>(
        'pay',
        receipt.payment,
      );
      if (mounted) {
        setState(
          () => _message = launched == true
              ? '请在微信确认付款，返回后自动核对结果'
              : '未能打开微信，请确认已安装微信后重试',
        );
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on PlatformException catch (_) {
      if (mounted) setState(() => _message = '微信未能调起，请检查微信安装及应用支付配置');
    } catch (_) {
      if (mounted) setState(() => _message = '暂时无法确认结果，请重试；同一订单不会重复创建');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final unit = (MediaQuery.sizeOf(context).width / 750).clamp(.4, .6);
    double r(double value) => value * unit;
    final status = _receipt?.status;
    final terminal = status == 'paid' || status == 'expired';
    final amount = _receipt?.totalCents ?? _total;
    final allItems = widget.quote.items;
    final items = _expanded ? allItems : allItems.take(3);
    Widget line(String label, String value) => Padding(
      padding: EdgeInsets.symmetric(vertical: r(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          SizedBox(width: r(16)),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
    Widget card(List<Widget> children) => Container(
      margin: EdgeInsets.symmetric(vertical: r(10)),
      padding: EdgeInsets.symmetric(horizontal: r(30), vertical: r(20)),
      decoration: BoxDecoration(
        color: const Color(0xFFC9B69E),
        borderRadius: BorderRadius.circular(r(16)),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: r(30),
          color: const Color(0xFF181205),
          height: 1.35,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: kingAppBar(
          context: context,
          title: Text(
            '确认订单',
            style: TextStyle(color: const Color(0xFFC9B69E), fontSize: r(34)),
          ),
          leading: KingBackButton(onPressed: widget.onBack),
          backgroundColor: Colors.black,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.4),
              radius: 1,
              colors: [Color(0xEF252018), Colors.black],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(r(20), r(10), r(20), r(24)),
                  children: [
                    card([
                      line('门店', widget.quote.orderingContext!.storeName),
                      line('桌号', widget.quote.orderingContext!.tableName),
                      if (_receipt != null) line('订单号', _receipt!.orderRef),
                    ]),
                    card([
                      const Text('商品明细'),
                      for (final item in items)
                        Container(
                          padding: EdgeInsets.symmetric(vertical: r(20)),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0x16000000)),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: r(76),
                                height: r(120),
                                child: item.catalogProduct?.thumbnailUrl != null
                                    ? CachedMediaImage(
                                        item.catalogProduct!.thumbnailUrl!,
                                        contentKey:
                                            item.catalogProduct!.imageCacheKey,
                                        private: true,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.local_bar_outlined,
                                        ),
                                      )
                                    : item.asset.isNotEmpty
                                    ? Image.asset(
                                        item.asset,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(Icons.local_bar_outlined),
                              ),
                              SizedBox(width: r(28)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(fontSize: r(30)),
                                    ),
                                    Text(
                                      item.detail,
                                      style: TextStyle(fontSize: r(22)),
                                    ),
                                    Text(
                                      '单价 ¥${_money(item.unitPriceCents ?? item.unitPrice * 100)}',
                                      style: TextStyle(fontSize: r(22)),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: r(12)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '数量 × ${item.quantity}',
                                    style: TextStyle(fontSize: r(24)),
                                  ),
                                  Text(
                                    '¥${_money(item.subtotalCents)}',
                                    style: TextStyle(fontSize: r(32)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (allItems.length > 3)
                        TextButton(
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0x90000000),
                          ),
                          child: Text(
                            '${_expanded ? '收起' : '展开'}更多（共${widget.quote.itemCount}件商品）',
                          ),
                        ),
                      SizedBox(height: r(24)),
                      line('商品总价', '¥${_money(_total)}'),
                    ]),
                    card([
                      Row(
                        children: [
                          Image.asset(
                            'assets/legacy/ordering/WEIPAY.png',
                            width: r(44),
                            height: r(44),
                          ),
                          SizedBox(width: r(15)),
                          const Expanded(child: Text('微信支付')),
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFF55493C),
                            size: r(36),
                          ),
                        ],
                      ),
                    ]),
                    if (_message != null)
                      Padding(
                        padding: EdgeInsets.all(r(20)),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: const Color(0xFFC9B69E),
                            fontSize: r(28),
                          ),
                        ),
                      ),
                    if (_receipt != null && !terminal)
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('刷新支付结果'),
                      ),
                  ],
                ),
              ),
              Container(
                key: const ValueKey('payment-bottom-bar'),
                padding: EdgeInsets.fromLTRB(
                  r(50),
                  r(20),
                  r(25),
                  r(20) + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x40C9B69E))),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Colors.black],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: status == 'paid' ? '实付 ￥' : '应付 ￥',
                                style: TextStyle(
                                  fontSize: r(28),
                                  color: const Color(0x80DDCBB5),
                                ),
                              ),
                              TextSpan(
                                text: _money(amount),
                                style: TextStyle(
                                  fontSize: r(42),
                                  color: const Color(0xFFDDCBB5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: r(20)),
                    SizedBox(
                      width: r(190),
                      height: r(80),
                      child: FilledButton(
                        onPressed: terminal
                            ? widget.onBack
                            : (_busy || !_ready ? null : _pay),
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: const StadiumBorder(),
                          backgroundColor: const Color(0xFFC9B69E),
                          foregroundColor: const Color(0xFF1B1206),
                          textStyle: TextStyle(
                            fontSize: r(30),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(
                          _busy
                              ? '正在提交…'
                              : status == 'paid'
                              ? '支付成功 · 返回'
                              : status == 'expired'
                              ? '重新选购'
                              : '立即支付',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
