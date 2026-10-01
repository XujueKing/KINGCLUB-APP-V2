import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:fluwx/fluwx.dart' show FluwxCancelable;

import '../../../core/design_system/king_components.dart';
import '../../../core/media/cached_media_image.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/ordering_order_repository.dart';
import '../data/ios_wechat_payment.dart';
import '../data/alipay_app_payment.dart';
import 'scan_ordering_cart_page.dart';
import 'ordering_entry_status.dart';

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
  bool _receiptMatchesQuote = true;
  bool _paymentBridgeUnavailable = false;
  OrderingPaymentProvider _provider = OrderingPaymentProvider.wechat;
  bool _channelLocked = false;
  bool _restorationComplete = false;
  FluwxCancelable? _paymentReturn;
  String? _message;
  Timer? _timer;
  String _paymentText(List<String> values) =>
      OrderingEntryStatus.text(Localizations.localeOf(context), values);
  String get _checkingOriginalMessage => _paymentText([
    '正在核对原订单，请勿重复付款',
    'Checking the original order. Do not pay again.',
    '正在核對原訂單，請勿重複付款',
    'กำลังตรวจสอบคำสั่งซื้อเดิม โปรดอย่าชำระเงินซ้ำ',
  ]);
  String? get _creationBlockReason {
    if (widget.quote.orderingContext!.paymentTiming != 'prepay') {
      return '当前版本尚未开放后付费下单，请联系门店处理。';
    }
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            !(defaultTargetPlatform == TargetPlatform.iOS &&
                (_provider == OrderingPaymentProvider.alipay ||
                    IosWechatPayment.enabled))) ||
        _paymentBridgeUnavailable) {
      return _provider == OrderingPaymentProvider.wechat
          ? '当前设备尚未开放微信付款；已有订单可继续查询，请勿重复下单。'
          : _paymentText([
              '当前设备暂不支持支付宝付款，已有订单可继续查询。',
              'Alipay is unavailable on this device. Existing orders can still be checked.',
              '目前裝置暫不支援支付寶付款，已有訂單可繼續查詢。',
              'อุปกรณ์นี้ยังไม่รองรับ Alipay แต่ยังตรวจสอบคำสั่งซื้อเดิมได้',
            ]);
    }
    return null;
  }

  int get _total =>
      widget.quote.items.fold(0, (sum, item) => sum + item.subtotalCents);
  String _money(int cents) => (cents / 100).toStringAsFixed(2);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        IosWechatPayment.enabled) {
      _paymentReturn = IosWechatPayment.onReturn(() => _refresh());
    }
    _restore();
  }

  Future<void> _restore() async {
    try {
      final session = await widget.repository.readSession();
      if (!mounted) return;
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
      if (!mounted) return;
      if (saved != null) {
        final value = jsonDecode(saved);
        if (value is! Map || value['requestId'] is! String) {
          throw const FormatException('Invalid pending order');
        }
        _receiptMatchesQuote = value['scope'] == _scope;
        _requestId = value['requestId'];
        final savedProvider = value['paymentProvider'] ?? 'wechat';
        _provider = OrderingPaymentProvider.values.firstWhere(
          (provider) => provider.name == savedProvider,
        );
        _channelLocked = true;
        _receipt = value['orderRef'] is String
            ? await widget.repository.owned(
                context: widget.quote.orderingContext!,
                orderRef: value['orderRef'],
              )
            : await widget.repository.findByRequest(
                context: widget.quote.orderingContext!,
                requestId: value['requestId'],
              );
        if (!mounted) return;
        if (_receipt == null) {
          // A lost submission response must keep its idempotency key.
          // A different basket is allowed only after the server found no order.
          if (!_receiptMatchesQuote) {
            await _storage.delete(key: _storageKey!);
            _requestId = const Uuid().v4();
            _receiptMatchesQuote = true;
            _channelLocked = false;
            _provider = OrderingPaymentProvider.wechat;
          }
          if (mounted) {
            setState(() {
              _message = _creationBlockReason;
              _ready = _message == null;
              _restorationComplete = true;
            });
          }
          return;
        }
        if (_receipt!.status == 'paid' || _receipt!.status == 'expired') {
          // Keep the terminal receipt on screen. Never turn a paid order into
          // a fresh request just because its confirmation arrived while away.
          _applyReceipt(_receipt!);
          await _storage.delete(key: _storageKey!);
          return;
        } else if (!_receiptMatchesQuote) {
          _message = '此桌还有一笔待付款订单，请先确认该订单状态，再重新选购。';
          _ready = false;
          if (mounted) setState(() {});
          _startPolling();
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _message = _creationBlockReason;
        _ready = _message == null;
        _restorationComplete = true;
      });
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
        'paymentProvider': _provider.name,
      }),
    );
  }

  void _startPolling() {
    if (!mounted) return;
    _timer ??= Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  void _applyReceipt(OrderingOrderReceipt receipt) {
    if (!mounted) return;
    setState(() {
      _receipt = receipt;
      if (receipt.status == 'paid') {
        _message = _receiptMatchesQuote
            ? '支付成功，订单已提交门店'
            : '此前订单已支付，当前购物车未改动，请返回后重新确认选购。';
      } else if (receipt.status == 'expired') {
        _message = '订单已关闭，请返回重新选购；如已扣款请联系门店核对。';
      }
    });
    if (receipt.status == 'paid' && _receiptMatchesQuote && !_confirmed) {
      _confirmed = true;
      widget.quote.onPaymentConfirmed?.call();
    }
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
      _applyReceipt(next);
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

  Future<void> _cancelOrder() async {
    final order = _receipt;
    if (_busy ||
        order == null ||
        order.status == 'paid' ||
        order.status == 'expired') {
      return;
    }
    setState(() => _busy = true);
    try {
      final next = await widget.repository.cancel(
        context: widget.quote.orderingContext!,
        orderRef: order.orderRef,
      );
      if (!mounted) return;
      _applyReceipt(next);
      if (next.status != 'paid' && next.status != 'expired') {
        setState(
          () => _message = _paymentText([
            '正在关闭原支付单，请稍候。',
            'Closing the original payment. Please wait.',
            '正在關閉原支付單，請稍候。',
            'กำลังปิดการชำระเงินเดิม โปรดรอสักครู่',
          ]),
        );
      }
      _startPolling();
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _paymentText([
            '取消结果待确认，请查询原订单。',
            'Cancellation is unconfirmed. Check this order.',
            '取消結果待確認，請查詢原訂單。',
            'ยังไม่ยืนยันการยกเลิก โปรดตรวจสอบคำสั่งซื้อเดิม',
          ]),
        );
        _startPolling();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay({bool initiatePayment = true}) async {
    if (_busy ||
        !_ready ||
        !_receiptMatchesQuote ||
        _receipt?.cancellationRequested == true ||
        (initiatePayment && _creationBlockReason != null) ||
        _receipt?.status == 'paid' ||
        _receipt?.status == 'expired') {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (initiatePayment && _provider == OrderingPaymentProvider.alipay) {
        if (!await AlipayAppPayment.prepare()) {
          if (mounted) {
            setState(
              () => _message = _paymentText([
                '请先安装支付宝后重试',
                'Install Alipay and try again.',
                '請先安裝支付寶後重試',
                'โปรดติดตั้ง Alipay แล้วลองอีกครั้ง',
              ]),
            );
          }
          return;
        }
        if (!mounted) return;
      } else if (initiatePayment &&
          defaultTargetPlatform == TargetPlatform.iOS) {
        if (!await IosWechatPayment.prepare()) {
          if (mounted) setState(() => _message = '请先安装微信，并确认微信支付配置已启用');
          return;
        }
        if (!mounted) return;
      }
      await _save(); // Persist the idempotency key before the first network attempt.
      if (!mounted) return;
      setState(() => _channelLocked = true);
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
        paymentProvider: _provider,
        initiatePayment: initiatePayment,
      );
      if (!mounted) return;
      setState(() => _receipt = receipt);
      await _save();
      if (receipt.status == 'paid' || receipt.status == 'expired') {
        await _refresh();
        return;
      }
      _startPolling();
      if (!initiatePayment) {
        setState(
          () => _message = _paymentText([
            '订单已提交，付款时确认库存；请在到期前付款。',
            'Order submitted. Stock is checked when paying. Pay before expiry.',
            '訂單已提交，付款時確認庫存；請在到期前付款。',
            'ส่งคำสั่งซื้อแล้ว ตรวจสอบสต็อกเมื่อชำระเงิน โปรดชำระก่อนหมดอายุ',
          ]),
        );
        return;
      }
      if (receipt.payment == null) {
        setState(() => _message = '订单已创建，正在确认支付状态');
        return;
      }
      if (_provider == OrderingPaymentProvider.alipay) {
        await AlipayAppPayment.pay(receipt.payment!);
        if (mounted &&
            _receipt?.status != 'paid' &&
            _receipt?.status != 'expired') {
          setState(
            () => _message = _paymentText([
              '正在核对支付宝付款结果，请勿重复付款',
              'Checking Alipay payment. Do not pay again.',
              '正在核對支付寶付款結果，請勿重複付款',
              'กำลังตรวจสอบการชำระเงิน Alipay โปรดอย่าชำระซ้ำ',
            ]),
          );
        }
        await _refresh();
        return;
      }
      final launched = defaultTargetPlatform == TargetPlatform.iOS
          ? await IosWechatPayment.pay(receipt.payment!)
          : await _channel.invokeMethod<bool>('pay', receipt.payment);
      if (mounted) {
        setState(
          () => _message = launched == true
              ? '请在微信确认付款，返回后自动核对结果'
              : '未能打开微信，请确认已安装微信后重试',
        );
      }
    } on AuthFailure catch (error) {
      if (error.code == 'ORDERING_OUT_OF_STOCK') {
        // Never discard the saved request based on an error alone. The server
        // must prove that the original order is terminal before another basket.
        try {
          final closed = await widget.repository.findByRequest(
            context: widget.quote.orderingContext!,
            requestId: _requestId,
          );
          if (!mounted) return;
          if (closed?.status == 'expired') {
            _applyReceipt(closed!);
            await _storage.delete(key: _storageKey!);
          } else if (closed?.status == 'paid') {
            _applyReceipt(closed!);
            await _storage.delete(key: _storageKey!);
            return;
          } else {
            if (closed != null) _applyReceipt(closed);
            _startPolling();
            setState(() => _message = _checkingOriginalMessage);
            return;
          }
        } catch (_) {
          if (mounted) setState(() => _message = _checkingOriginalMessage);
          return;
        }
      }
      // Configuration can be disabled after a previous submission. Only a
      // successful lookup may unlock selection, and retain the idempotency key.
      if (error.code == 'ALIPAY_NOT_READY' && _receipt == null) {
        try {
          final existing = await widget.repository.findByRequest(
            context: widget.quote.orderingContext!,
            requestId: _requestId,
          );
          if (!mounted) return;
          if (existing == null) {
            _channelLocked = false;
          } else {
            _applyReceipt(existing);
            _startPolling();
          }
        } catch (_) {
          // Unknown result: preserve the saved attempt and channel lock.
        }
      }
      if (mounted) {
        setState(
          () => _message = error.code == 'ORDERING_OUT_OF_STOCK'
              ? _paymentText([
                  '商品已售罄，未发起扣款，请返回修改订单。',
                  'Item sold out. No charge was initiated. Go back to change the order.',
                  '商品已售罄，未發起扣款，請返回修改訂單。',
                  'สินค้าหมด ยังไม่ได้เรียกเก็บเงิน โปรดย้อนกลับไปแก้ไขคำสั่งซื้อ',
                ])
              : error.code == 'ORDERING_PAYMENT_IN_PROGRESS'
              ? _checkingOriginalMessage
              : error.message,
        );
      }
    } on MissingPluginException catch (_) {
      if (mounted) {
        setState(() {
          _paymentBridgeUnavailable = true;
          _ready = false;
          _message = _creationBlockReason;
        });
      }
    } on PlatformException catch (_) {
      if (mounted) setState(() => _message = '支付应用未能调起，请检查安装及支付配置');
    } catch (_) {
      if (mounted) setState(() => _message = '暂时无法确认结果，请重试；同一订单不会重复创建');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectProvider(OrderingPaymentProvider provider) {
    if (_channelLocked || _busy || !_restorationComplete) {
      return;
    }
    setState(() {
      _provider = provider;
      _paymentBridgeUnavailable = false;
      _message = _creationBlockReason;
      _ready = _message == null;
    });
  }

  @override
  void dispose() {
    _paymentReturn?.cancel();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _buildSuccess(BuildContext context) {
    final receipt = _receipt!;
    const gold = Color(0xFFC9B69E);
    return Scaffold(
      key: const ValueKey('live-payment-success'),
      backgroundColor: Colors.black,
      appBar: kingAppBar(
        context: context,
        title: const Text('订单信息', style: TextStyle(color: gold)),
        leading: KingBackButton(onPressed: widget.onBack),
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 50, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/legacy/payment/legacy_payment_success.png',
                        width: 92,
                        height: 92,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '支付成功',
                        style: TextStyle(
                          color: gold,
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '¥${_money(receipt.totalCents)}',
                        style: const TextStyle(color: gold, fontSize: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '订单号：${receipt.orderRef}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFAAA097),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.quote.orderingContext!.storeName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFAAA097)),
                      ),
                      if (!_receiptMatchesQuote) ...[
                        const SizedBox(height: 16),
                        const Text(
                          '此前订单已支付，当前购物车未改动，请返回后重新确认选购。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: gold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('live-payment-success-return'),
                      onPressed: widget.onBack,
                      style: FilledButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: const Color(0xFF181205),
                      ),
                      child: const Text('返回'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SHANGHAI · ZHUZHOU',
                    style: TextStyle(color: Color(0xFFAAA097), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (_receipt?.status == 'paid') return _buildSuccess(context);
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
                    if (!_receiptMatchesQuote)
                      card([const Text('当前显示此前订单的状态；当前购物车不是该订单明细。')]),
                    if (_receiptMatchesQuote)
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
                                  child:
                                      item.catalogProduct?.thumbnailUrl != null
                                      ? CachedMediaImage(
                                          item.catalogProduct!.thumbnailUrl!,
                                          contentKey: item
                                              .catalogProduct!
                                              .imageCacheKey,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                      InkWell(
                        key: const ValueKey('payment-provider-wechat'),
                        onTap: _channelLocked || _busy
                            ? null
                            : () => _selectProvider(
                                OrderingPaymentProvider.wechat,
                              ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/legacy/ordering/WEIPAY.png',
                              width: r(44),
                              height: r(44),
                            ),
                            SizedBox(width: r(15)),
                            const Expanded(child: Text('微信支付')),
                            Icon(
                              _provider == OrderingPaymentProvider.wechat
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: const Color(0xFF55493C),
                              size: r(36),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: r(24)),
                      InkWell(
                        key: const ValueKey('payment-provider-alipay'),
                        onTap: _channelLocked || _busy
                            ? null
                            : () => _selectProvider(
                                OrderingPaymentProvider.alipay,
                              ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: r(44),
                              color: const Color(0xFF1677FF),
                            ),
                            SizedBox(width: r(15)),
                            Expanded(
                              child: Text(
                                _paymentText([
                                  '支付宝',
                                  'Alipay',
                                  '支付寶',
                                  'Alipay',
                                ]),
                              ),
                            ),
                            Icon(
                              _provider == OrderingPaymentProvider.alipay
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: const Color(0xFF55493C),
                              size: r(36),
                            ),
                          ],
                        ),
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
                        key: const ValueKey('order-cancel'),
                        onPressed: _busy ? null : _cancelOrder,
                        child: Text(
                          _paymentText([
                            '取消订单',
                            'Cancel order',
                            '取消訂單',
                            'ยกเลิกคำสั่งซื้อ',
                          ]),
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
                    if (!terminal && _receipt == null)
                      TextButton(
                        key: const ValueKey('order-create-only'),
                        onPressed: _busy || !_ready
                            ? null
                            : () => _pay(initiatePayment: false),
                        child: Text(
                          _paymentText([
                            '提交订单',
                            'Place order',
                            '提交訂單',
                            'ส่งคำสั่งซื้อ',
                          ]),
                        ),
                      ),
                    SizedBox(width: r(20)),
                    SizedBox(
                      width: r(190),
                      height: r(80),
                      child: FilledButton(
                        onPressed: terminal
                            ? widget.onBack
                            : (_busy ||
                                      !_ready ||
                                      _receipt?.cancellationRequested == true
                                  ? null
                                  : _pay),
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
