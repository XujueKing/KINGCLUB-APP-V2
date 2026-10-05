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
import '../data/store_payment_availability_repository.dart';
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
  Map<String, dynamic>? _benefits;
  Map<String, dynamic>? _selection;
  final _coinInput = TextEditingController(text: '0');
  final _storeInput = TextEditingController(text: '0.00');
  Future<void>? _inputCommit;
  Timer? _inputDebounce;
  int get _storeAvailableCents =>
      int.tryParse(_benefits?['storeAvailableCents']?.toString() ?? '') ?? 0;
  void _capEnteredAmounts() {
    if (_benefits == null || _channelLocked) return;
    final afterCoupon = (_total - _component('couponDiscountCents')).clamp(
      0,
      _total,
    );
    final availableCoins =
        int.tryParse(_benefits?['coins']?.toString() ?? '') ?? 0;
    final maxCoins = (afterCoupon ~/ 10).clamp(0, availableCoins);
    var coins = int.tryParse(_coinInput.text) ?? 0;
    if (coins > maxCoins) {
      coins = maxCoins;
      final text = coins.toString();
      _coinInput.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    final remaining = (afterCoupon - coins * 10).clamp(0, _storeAvailableCents);
    final store = _inputStoreCents;
    if (store != null && store > remaining) {
      final text = _money(remaining);
      _storeInput.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _amountChanged(String _) {
    _capEnteredAmounts();
    setState(() {});
    _inputDebounce?.cancel();
    _inputDebounce = Timer(const Duration(milliseconds: 300), _commitInputs);
  }

  void _syncInputs() {
    _coinInput.text = _selection?['coins']?.toString() ?? '0';
    final cents =
        int.tryParse(_selection?['storeBalanceCents']?.toString() ?? '') ??
        (_component('storePrincipalCents') + _component('storeGiftCents'));
    _storeInput.text = _money(cents);
  }

  int? get _inputStoreCents {
    final raw = _storeInput.text.isEmpty ? '0' : _storeInput.text;
    if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(raw)) return null;
    final parts = raw.split('.');
    return int.parse(parts[0]) * 100 +
        int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  }

  bool get _inputsChanged =>
      (int.tryParse(_coinInput.text.isEmpty ? '0' : _coinInput.text)
              ?.toString() !=
          (_selection?['coins'] ?? '0')) ||
      (_inputStoreCents?.toString() !=
          (_selection?['storeBalanceCents'] ?? '0'));

  Future<void> _commitInputs() async {
    _inputDebounce?.cancel();
    _capEnteredAmounts();
    if (_inputCommit != null) await _inputCommit;
    if (!mounted ||
        _channelLocked ||
        _benefits == null ||
        _quoting ||
        !_inputsChanged) {
      return;
    }
    final coins = int.tryParse(_coinInput.text.isEmpty ? '0' : _coinInput.text);
    final cents = _inputStoreCents;
    if (coins == null || cents == null) return;
    _inputCommit = _loadBenefits({
      'coins': coins.toString(),
      'useStoreBalance': cents > 0,
      'storeBalanceCents': cents.toString(),
    });
    try {
      await _inputCommit;
    } finally {
      _inputCommit = null;
    }
  }

  bool _quoting = false;
  String? _quoteError;
  List<OrderingOrderLine> get _quoteLines => widget.quote.items
      .map(
        (i) =>
            OrderingOrderLine(product: i.catalogProduct!, quantity: i.quantity),
      )
      .toList();
  Map<String, dynamic> get _choice => {
    ...?_selection,
    'couponRef': _selection?['couponRef'],
    'coins': _selection?['coins'] ?? '0',
    'useStoreBalance': _selection?['useStoreBalance'] ?? false,
    'method': _provider.wireName,
  }..remove('quoteHash');
  Map<String, dynamic>? get _composition =>
      _receipt?.paymentComposition ??
      (_benefits?['composition'] is Map
          ? Map<String, dynamic>.from(_benefits!['composition'])
          : null);
  int _component(String key) =>
      int.tryParse(_composition?[key]?.toString() ?? '') ?? 0;
  bool get _needsExternal =>
      _provider != OrderingPaymentProvider.platformCash &&
      (_composition == null || _component('externalCents') > 0);

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
  bool get _postpay => widget.quote.orderingContext!.paymentTiming == 'postpay';
  String get _postpayMessage => _paymentText([
    '订单已提交门店，消费结束后结账；已出酒商品如需变更请联系店员。',
    'Order sent to the store. Pay after your visit; ask staff to change delivered items.',
    '訂單已提交門店，消費結束後結帳；已出酒商品如需變更請聯繫店員。',
    'ส่งคำสั่งซื้อให้ร้านแล้ว ชำระเมื่อใช้บริการเสร็จ หากต้องการยกเลิกโปรดติดต่อพนักงาน',
  ]);
  String? get _creationBlockReason {
    if (_postpay || !_needsExternal) return null;
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
    _restore().then((_) {
      if (mounted && !_postpay && !_channelLocked && _restorationComplete) {
        _loadBenefits();
      }
    });
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
        if (value['selection'] is Map) {
          _selection = Map<String, dynamic>.from(value['selection']);
          _syncInputs();
        }
        final savedProvider = value['paymentProvider'] ?? 'wechat';
        _provider = OrderingPaymentProvider.values.firstWhere(
          (provider) => provider.wireName == savedProvider,
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
        if (_postpay && _receipt!.status == 'pending') {
          _applyReceipt(_receipt!);
          await _storage.delete(key: _storageKey!);
          if (mounted) {
            setState(() {
              _ready = true;
              _restorationComplete = true;
            });
          }
          _startPolling();
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
        'paymentProvider': _provider.wireName,
        if (_selection != null) 'selection': _selection,
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
    if (_postpay && receipt.status == 'pending') {
      setState(() => _message = _postpayMessage);
      if (_receiptMatchesQuote && !_confirmed) {
        _confirmed = true;
        widget.quote.onOrderSubmitted?.call();
      }
    }
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
    if (!_postpay && !_channelLocked) {
      FocusManager.instance.primaryFocus?.unfocus();
      await _commitInputs();
      if (!mounted || _inputsChanged) return;
    }
    if (_postpay) initiatePayment = false;
    if (_busy ||
        _quoting ||
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
      if (initiatePayment &&
          _needsExternal &&
          _provider == OrderingPaymentProvider.alipay) {
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
          _needsExternal &&
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
        selection: _postpay ? null : _selection,
      );
      if (!mounted) return;
      _applyReceipt(receipt);
      await _save();
      if (_postpay && receipt.status == 'pending') {
        await _storage.delete(key: _storageKey!);
        _startPolling();
        return;
      }
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
      if (_receipt == null && _channelLocked) {
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

  Future<void> _loadBenefits([Map<String, dynamic>? changes]) async {
    if (_quoting || _channelLocked || _postpay) return;
    setState(() => _quoting = true);
    final choice = {..._choice, ...?changes};
    final inputSnapshot = (_coinInput.text, _storeInput.text);
    try {
      final result = await widget.repository.paymentQuote(
        context: widget.quote.orderingContext!,
        lines: _quoteLines,
        selection: choice,
      );
      if (!mounted) return;
      setState(() {
        _provider = OrderingPaymentProvider.values.firstWhere(
          (p) => p.wireName == choice['method'],
        );
        _benefits = result;
        _selection = {...choice, 'quoteHash': result['quoteHash']};
        if (changes?['coins'] == null &&
            changes?['storeBalanceCents'] == null &&
            !_inputsChanged) {
          _syncInputs();
        }
        _quoteError = null;
        _message = _creationBlockReason;
        _ready = _message == null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _quoteError = e is AuthFailure
              ? e.message
              : _paymentText([
                  '抵扣信息未更新，点击重试',
                  'Could not update discounts. Tap to retry.',
                  '抵扣資訊未更新，點擊重試',
                  'อัปเดตส่วนลดไม่สำเร็จ แตะเพื่อลองอีกครั้ง',
                ]),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _quoting = false);
        if (inputSnapshot != (_coinInput.text, _storeInput.text) &&
            _inputsChanged) {
          _inputDebounce?.cancel();
          _inputDebounce = Timer(
            const Duration(milliseconds: 300),
            _commitInputs,
          );
        }
      }
    }
  }

  String get _couponName {
    for (final c in (_benefits?['coupons'] as List? ?? [])) {
      if (c['itemRef'] == _selection?['couponRef']) return c['name'].toString();
    }
    return _paymentText(['无', 'None', '無', 'ไม่มี']);
  }

  Widget _benefitRow(
    String title,
    String value,
    VoidCallback action, {
    required String key,
  }) => InkWell(
    key: ValueKey(key),
    onTap: _benefits != null && !_channelLocked && !_busy && !_quoting
        ? action
        : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .40,
            ),
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black54),
        ],
      ),
    ),
  );
  Future<T?> _checkoutPicker<T>({
    required String key,
    required T initial,
    required Widget Function(T, ValueChanged<T>) content,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    var chosen = initial;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SizedBox(
          key: ValueKey(key),
          height: MediaQuery.sizeOf(context).height * .40,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: content(chosen, (v) => update(() => chosen = v)),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final confirm in [false, true]) ...[
                        if (confirm) const SizedBox(width: 16),
                        SizedBox(
                          width: 118,
                          height: 44,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: confirm
                                  ? const Color(0xFF07C160)
                                  : const Color(0xFFF2F2F2),
                              foregroundColor: confirm
                                  ? Colors.white
                                  : const Color(0xFF07C160),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            onPressed: () =>
                                Navigator.pop(ctx, confirm ? chosen : null),
                            child: Text(
                              confirm
                                  ? _paymentText([
                                      '确定',
                                      'Confirm',
                                      '確定',
                                      'ยืนยัน',
                                    ])
                                  : _paymentText([
                                      '取消',
                                      'Cancel',
                                      '取消',
                                      'ยกเลิก',
                                    ]),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseCoupon() async {
    final coupons = _benefits?['coupons'] as List? ?? [];
    final selected = await _checkoutPicker<String>(
      key: 'checkout-coupon-sheet',
      initial: _selection?['couponRef']?.toString() ?? '',
      content: (chosen, choose) => coupons.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF0F0F0)),
                  bottom: BorderSide(color: Color(0xFFF0F0F0)),
                ),
              ),
              child: Text(
                _paymentText([
                  '没有优惠券',
                  'No coupons available',
                  '沒有優惠券',
                  'ไม่มีคูปอง',
                ]),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF333333), fontSize: 22),
              ),
            )
          : ListView(
              children: [
                for (final c in [
                  <String, dynamic>{
                    'itemRef': '',
                    'name': _paymentText([
                      '不使用优惠券',
                      'No coupon',
                      '不使用優惠券',
                      'ไม่ใช้คูปอง',
                    ]),
                  },
                  ...coupons,
                ])
                  ListTile(
                    title: Text(
                      c['name'].toString(),
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    trailing: chosen == c['itemRef']
                        ? const Icon(Icons.check, color: Color(0xFF07C160))
                        : null,
                    onTap: () => choose(c['itemRef'].toString()),
                  ),
              ],
            ),
    );
    if (selected != null && mounted) {
      await _loadBenefits({'couponRef': selected.isEmpty ? null : selected});
    }
  }

  Widget _amountInputRow({
    required String title,
    required String balance,
    String? helper,
    required TextEditingController controller,
    required bool money,
    required String key,
  }) {
    final enabled =
        _benefits != null &&
        !_channelLocked &&
        !_busy &&
        (!money || _storeAvailableCents > 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          InkWell(
            onTap: enabled
                ? () async {
                    controller.text = '0';
                    await _commitInputs();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                (int.tryParse(controller.text.replaceAll('.', '')) ?? 0) > 0
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 22,
                color: const Color(0xFF94836D),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$title（$balance）', style: const TextStyle(fontSize: 15)),
                if (helper != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    helper,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF625648),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            height: 40,
            child: TextField(
              key: ValueKey(key),
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.numberWithOptions(decimal: money),
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontSize: 18,
                color: enabled ? Colors.white : const Color(0xFF8C8378),
              ),
              cursorColor: const Color(0xFF07C160),
              inputFormatters: money
                  ? [
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) =>
                            RegExp(r'^(?:\d{1,7}(\.\d{0,2})?)?$')
                                .hasMatch(newValue.text)
                            ? newValue
                            : oldValue,
                      ),
                    ]
                  : [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
              onChanged: _amountChanged,
              onSubmitted: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
                _commitInputs();
              },
              onTapOutside: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
                _commitInputs();
              },
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: enabled
                    ? const Color(0xFFAA9A83)
                    : const Color(0xFFB9AC99),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 9,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF8F7E69)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF8F7E69)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF8F7E69)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentMethods() async {
    final availability =
        StorePaymentAvailabilityRepository(
              readSession: widget.repository.readSession,
              request: widget.repository.request,
            )
            .alipayAvailable(widget.quote.orderingContext!.storeRef)
            .catchError((_) => false);
    final selected = await _checkoutPicker<OrderingPaymentProvider>(
      key: 'checkout-payment-sheet',
      initial: _provider,
      content: (chosen, choose) => ListView(
        children: [
          ListTile(
            key: const ValueKey('payment-method-wechat'),
            leading: Image.asset(
              'assets/legacy/ordering/WEIPAY.png',
              width: 28,
              height: 28,
            ),
            title: Text(
              _paymentText(['微信支付', 'WeChat Pay', '微信支付', 'WeChat Pay']),
              style: const TextStyle(color: Colors.black87),
            ),
            trailing: chosen == OrderingPaymentProvider.wechat
                ? const Icon(Icons.check, color: Color(0xFF07C160))
                : null,
            onTap: () => choose(OrderingPaymentProvider.wechat),
          ),
          FutureBuilder<bool>(
            future: availability,
            builder: (context, snapshot) {
              final enabled = snapshot.data == true;
              return ListTile(
                key: const ValueKey('payment-provider-alipay'),
                enabled: enabled,
                leading: Image.asset(
                  'assets/legacy/payment/legacy_alipay.png',
                  width: 28,
                  height: 28,
                ),
                title: Text(
                  _paymentText(['支付宝支付', 'Alipay', '支付寶支付', 'Alipay']),
                  style: TextStyle(
                    color: enabled ? Colors.black87 : Colors.grey,
                  ),
                ),
                trailing: enabled
                    ? (chosen == OrderingPaymentProvider.alipay
                          ? const Icon(Icons.check, color: Color(0xFF07C160))
                          : null)
                    : Text(
                        _paymentText([
                          '暂未开通',
                          'Unavailable',
                          '暫未開通',
                          'ยังไม่เปิดให้บริการ',
                        ]),
                        style: const TextStyle(color: Colors.grey),
                      ),
                onTap: enabled
                    ? () => choose(OrderingPaymentProvider.alipay)
                    : null,
              );
            },
          ),
          ListTile(
            key: const ValueKey('payment-method-platform'),
            leading: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.black87,
            ),
            title: Text(
              _paymentText([
                '平台余额',
                'Platform balance',
                '平台餘額',
                'ยอดเงินแพลตฟอร์ม',
              ]),
              style: const TextStyle(color: Colors.black87),
            ),
            subtitle: Text(
              '¥${_money(int.tryParse(_benefits?['platformCashCents']?.toString() ?? '0') ?? 0)}',
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: chosen == OrderingPaymentProvider.platformCash
                ? const Icon(Icons.check, color: Color(0xFF07C160))
                : null,
            enabled: _benefits?['platformEnabled'] == true,
            onTap: _benefits?['platformEnabled'] == true
                ? () => choose(OrderingPaymentProvider.platformCash)
                : null,
          ),
        ],
      ),
    );
    if (selected != null && mounted) _selectProvider(selected);
  }

  void _selectProvider(OrderingPaymentProvider provider) {
    if (_channelLocked || _busy || _quoting || !_restorationComplete) {
      return;
    }
    if (_benefits != null) {
      _loadBenefits({'method': provider.wireName});
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
    _inputDebounce?.cancel();
    _coinInput.dispose();
    _storeInput.dispose();
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
                        'assets/legacy/storage/success2.png',
                        width: 92,
                        height: 92,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '支付成功',
                        style: TextStyle(
                          color: gold,
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '¥${_money(receipt.totalCents - _component('couponDiscountCents'))}',
                        style: const TextStyle(color: gold, fontSize: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '订单号：${receipt.orderRef}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFAAA097),
                          fontSize: 17,
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
                    width: KingBackButton.contentWidth(context),
                    height: 45,
                    child: FilledButton(
                      key: const ValueKey('live-payment-success-return'),
                      onPressed: widget.onBack,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(45),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
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
  final DateTime _orderOpenedAt = DateTime.now();

  @override
  Widget build(BuildContext context) {
    if (_receipt?.status == 'paid') return _buildSuccess(context);
    final unit = (MediaQuery.sizeOf(context).width / 750).clamp(.4, .6);
    double r(double value) => value * unit;
    final status = _receipt?.status;
    final terminal = status == 'paid' || status == 'expired';
    final amount = _composition != null
        ? (_component('externalCents') + _component('platformCashCents'))
        : (_receipt?.totalCents ?? _total);
    final allItems = widget.quote.items;
    final items = _expanded ? allItems : allItems.take(1);
    Widget line(String label, String value) => Padding(
      padding: EdgeInsets.symmetric(vertical: r(3)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          SizedBox(width: r(16)),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
    Widget card(List<Widget> children, {bool roomy = false}) => Container(
      margin: EdgeInsets.symmetric(vertical: r(10)),
      padding: EdgeInsets.symmetric(
        horizontal: r(24),
        vertical: r(roomy ? 28 : 12),
      ),
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
        resizeToAvoidBottomInset: false,
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    r(20),
                    r(10),
                    r(20),
                    r(24) + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      card([
                        line('门店', widget.quote.orderingContext!.storeName),
                        const SizedBox(height: 6),
                        line('桌号', widget.quote.orderingContext!.tableName),
                        const SizedBox(height: 6),
                        line(
                          _paymentText([
                            '订单时间',
                            'Order time',
                            '訂單時間',
                            'เวลาสั่งซื้อ',
                          ]),
                          (_receipt?.createdAt ?? _orderOpenedAt)
                              .toLocal()
                              .toString()
                              .split('.')
                              .first,
                        ),
                        if (_receipt != null) line('订单号', _receipt!.orderRef),
                      ], roomy: true),
                      if (!_receiptMatchesQuote)
                        card([const Text('当前显示此前订单的状态；当前购物车不是该订单明细。')]),
                      if (_receiptMatchesQuote)
                        card([
                          const Text('商品明细'),
                          for (final item in items)
                            Container(
                              padding: EdgeInsets.symmetric(vertical: r(12)),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Color(0x16000000)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: r(76),
                                    height: r(100),
                                    child:
                                        item.catalogProduct?.thumbnailUrl !=
                                            null
                                        ? CachedMediaImage(
                                            item.catalogProduct!.thumbnailUrl!,
                                            contentKey: item
                                                .catalogProduct!
                                                .imageCacheKey,
                                            private: true,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
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
                          if (allItems.length > 1)
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
                          SizedBox(height: r(12)),
                          line('商品总价', '¥${_money(_total)}'),
                        ]),
                      if (!_postpay)
                        card([
                          _benefitRow(
                            _paymentText([
                              '选择优惠券',
                              'Choose coupon',
                              '選擇優惠券',
                              'เลือกคูปอง',
                            ]),
                            _couponName,
                            _chooseCoupon,
                            key: 'checkout-coupon',
                          ),
                          const Divider(color: Color(0x22000000)),
                          _amountInputRow(
                            title: _paymentText([
                              '金币兑换',
                              'Coins',
                              '金幣兌換',
                              'เหรียญ',
                            ]),
                            balance: '${_benefits?['coins'] ?? '—'}',
                            helper: _paymentText([
                              '价值 ¥${_money((int.tryParse(_benefits?['coins']?.toString() ?? '') ?? 0) * 10)} · 10金币抵1元',
                              'Worth ¥${_money((int.tryParse(_benefits?['coins']?.toString() ?? '') ?? 0) * 10)} · 10 coins = ¥1',
                              '價值 ¥${_money((int.tryParse(_benefits?['coins']?.toString() ?? '') ?? 0) * 10)} · 10金幣抵1元',
                              'มูลค่า ¥${_money((int.tryParse(_benefits?['coins']?.toString() ?? '') ?? 0) * 10)} · 10 เหรียญ = ¥1',
                            ]),
                            controller: _coinInput,
                            money: false,
                            key: 'checkout-coins',
                          ),
                          _amountInputRow(
                            title: _paymentText([
                              '本店储值卡',
                              'Store credit card',
                              '本店儲值卡',
                              'เงินร้าน',
                            ]),
                            balance: _benefits == null
                                ? '—'
                                : '¥${_money(int.tryParse(_benefits!['storeAvailableCents'].toString()) ?? 0)}',
                            controller: _storeInput,
                            money: true,
                            key: 'checkout-store-amount',
                          ),
                          if (_component('couponDiscountCents') > 0)
                            line(
                              _paymentText([
                                '优惠券减免',
                                'Coupon discount',
                                '優惠券減免',
                                'ส่วนลดคูปอง',
                              ]),
                              '-¥${_money(_component('couponDiscountCents'))}',
                            ),
                          if (_component('coinSubsidyCents') > 0)
                            line(
                              _paymentText([
                                '金币抵扣',
                                'Coins applied',
                                '金幣抵扣',
                                'หักด้วยเหรียญ',
                              ]),
                              '-¥${_money(_component('coinSubsidyCents'))}',
                            ),
                          if (_component('storePrincipalCents') +
                                  _component('storeGiftCents') >
                              0)
                            line(
                              _paymentText([
                                '本店储值抵扣',
                                'Store balance applied',
                                '本店儲值抵扣',
                                'หักยอดเงินร้าน',
                              ]),
                              '-¥${_money(_component('storePrincipalCents') + _component('storeGiftCents'))}',
                            ),
                          if (_quoteError != null)
                            TextButton(
                              onPressed: _quoting
                                  ? null
                                  : () => _loadBenefits(),
                              child: Text(
                                _quoteError!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                        ]),
                      if (!_postpay && amount > 0)
                        card([
                          InkWell(
                            key: const ValueKey('payment-provider-wechat'),
                            onTap:
                                _channelLocked || _busy || _quoting || !_ready
                                ? null
                                : _showPaymentMethods,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: r(24)),
                              child: Row(
                                children: [
                                  if (_provider ==
                                      OrderingPaymentProvider.platformCash)
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: r(44),
                                      color: Colors.black,
                                    )
                                  else
                                    Image.asset(
                                      _provider ==
                                              OrderingPaymentProvider.wechat
                                          ? 'assets/legacy/ordering/WEIPAY.png'
                                          : 'assets/legacy/payment/legacy_alipay.png',
                                      width: r(44),
                                      height: r(44),
                                    ),
                                  SizedBox(width: r(15)),
                                  Expanded(
                                    child: Text(
                                      _provider ==
                                              OrderingPaymentProvider
                                                  .platformCash
                                          ? _paymentText([
                                              '平台余额',
                                              'Platform balance',
                                              '平台餘額',
                                              'ยอดเงินแพลตฟอร์ม',
                                            ])
                                          : _provider ==
                                                OrderingPaymentProvider.wechat
                                          ? _paymentText([
                                              '微信支付',
                                              'WeChat Pay',
                                              '微信支付',
                                              'WeChat Pay',
                                            ])
                                          : _paymentText([
                                              '支付宝支付',
                                              'Alipay',
                                              '支付寶支付',
                                              'Alipay',
                                            ]),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: r(36),
                                    color: const Color(0xFF55493C),
                                  ),
                                ],
                              ),
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
                      if ((!_postpay || _receipt?.canCancel == true) &&
                          _receipt != null &&
                          !terminal)
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
                          child: Text(
                            _postpay
                                ? _paymentText([
                                    '刷新订单',
                                    'Refresh order',
                                    '重新整理訂單',
                                    'รีเฟรชคำสั่งซื้อ',
                                  ])
                                : '刷新支付结果',
                          ),
                        ),
                    ],
                  ),
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
                        onPressed: terminal || (_postpay && _receipt != null)
                            ? widget.onBack
                            : (_busy ||
                                      _quoting ||
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
                              : _postpay
                              ? (_receipt == null
                                    ? _paymentText([
                                        '提交订单',
                                        'Place order',
                                        '提交訂單',
                                        'ส่งคำสั่งซื้อ',
                                      ])
                                    : _paymentText([
                                        '继续点单',
                                        'Continue ordering',
                                        '繼續點單',
                                        'สั่งเพิ่ม',
                                      ]))
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
