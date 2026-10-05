import 'package:kingclub/src/core/formatters/money.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fluwx/fluwx.dart' show FluwxCancelable;

import '../../commerce/data/ios_wechat_payment.dart';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/auth_repository.dart';
import '../data/secure_together_play_repository.dart';
import '../data/together_play.dart';
import 'legacy_club_components.dart';
import 'together_ticket_page.dart';

class TogetherBookingPage extends StatefulWidget {
  const TogetherBookingPage({
    super.key,
    required this.party,
    required this.repository,
  });
  final TogetherParty party;
  final SecureTogetherPlayRepository repository;
  @override
  State<TogetherBookingPage> createState() => _TogetherBookingPageState();
}

class _TogetherBookingPageState extends State<TogetherBookingPage>
    with WidgetsBindingObserver {
  static const _wechat = MethodChannel('kingclub/wechat-payment');
  Timer? _poll;
  FluwxCancelable? _wechatReturn;
  bool _foreground = true;
  bool get _wechatAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          (defaultTargetPlatform == TargetPlatform.iOS &&
              IosWechatPayment.enabled));
  final requestRef = const Uuid().v4();
  TogetherBooking? booking;
  bool busy = false;
  String? error;
  String method = 'store_balance';
  final coinsInput = TextEditingController(text: '0');
  bool uncertain = false;
  int? sentCoins;
  String? sentMethod;
  List<TogetherCoupon> coupons = [];
  TogetherCoupon? coupon, sentCoupon;

  @override
  void dispose() {
    _poll?.cancel();
    _wechatReturn?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    coinsInput.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final b = booking;
    if (busy || b == null || b.status != 'pending') return;
    final coins = uncertain ? sentCoins : int.tryParse(coinsInput.text);
    final selectedCoupon = uncertain ? sentCoupon : coupon;
    final afterCoupon = b.payableMinor - (selectedCoupon?.discountMinor ?? 0);
    if (coins == null || coins < 0 || coins * 10 > afterCoupon) {
      setState(() => error = '请填写有效金币数，10金币抵1元');
      return;
    }
    final selected = uncertain
        ? sentMethod!
        : (afterCoupon == coins * 10 ? 'free' : method);
    sentCoupon = selectedCoupon;
    sentCoins = coins;
    sentMethod = selected;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (selected == 'wechat') {
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            !uncertain &&
            !await IosWechatPayment.prepare()) {
          if (mounted) setState(() => error = '请先安装微信，再继续付款');
          return;
        }
        final result = await widget.repository.wechatBooking(
          b,
          action: 'prepare',
          storeRef: widget.party.storeRef,
          coins: coins,
          coupon: selectedCoupon,
        );
        if (!mounted) return;
        _applyWechat(result);
        if (result.payment != null) {
          final launched = defaultTargetPlatform == TargetPlatform.iOS
              ? await IosWechatPayment.pay(result.payment!)
              : await _wechat.invokeMethod<bool>('pay', result.payment);
          if (mounted) {
            setState(
              () => error = launched == true
                  ? '请在微信确认付款，返回后自动核对结果'
                  : '未能打开微信，请查询或取消原付款后重试',
            );
          }
        }
        return;
      }
      final paid = await widget.repository.payBooking(
        b,
        method: selected,
        coins: coins,
        coupon: selectedCoupon,
        storeRef: widget.party.storeRef,
      );
      if (mounted) {
        setState(() {
          booking = paid;
          uncertain = false;
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          uncertain =
              !(e is AuthFailure &&
                  const {
                    'TOGETHER_COUPON_UNAVAILABLE',
                    'TOGETHER_COINS_NOT_ALLOWED',
                    'TOGETHER_COINS_EXCESS',
                    'TOGETHER_BALANCE_INSUFFICIENT',
                    'MEMBER_ASSETS_INSUFFICIENT',
                    'MEMBER_ASSETS_CHANGED',
                    'MEMBER_ASSETS_UNAVAILABLE',
                    'MEMBER_ASSETS_RANGE',
                    'PLATFORM_CASH_STORE_NOT_AUTHORIZED',
                    'STORE_BALANCE_DEBIT_UNAVAILABLE',
                    'STORE_BALANCE_RULES_UNAVAILABLE',
                    'TOGETHER_NOT_ELIGIBLE',
                    'TOGETHER_PRICE_CHANGED',
                    'TOGETHER_FULL',
                    'TOGETHER_GENDER_FULL',
                    'TOGETHER_NOT_PAYABLE',
                    'TOGETHER_PAYMENT_METHOD',
                  }.contains(e.code));
          error = e is AuthFailure ? e.message : '未能确认付款结果';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        IosWechatPayment.enabled) {
      _wechatReturn = IosWechatPayment.onReturn(() => _checkWechat());
    }
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted &&
          _foreground &&
          booking?.status == 'paying' &&
          ModalRoute.of(context)?.isCurrent == true) {
        _checkWechat();
      }
    });
    _prepare();
  }

  Future<void> _prepare() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.prepareBooking(
        widget.party.ref,
        requestRef: requestRef,
      );
      final available = result.status == 'pending'
          ? await widget.repository.coupons(result, widget.party.storeRef)
          : <TogetherCoupon>[];
      if (mounted) {
        setState(() {
          booking = result;
          if (result.status == 'paying') {
            uncertain = true;
            sentMethod = 'wechat';
          }
          coupons = available;
          coupon = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is AuthFailure ? e.message : '暂时无法确认报名，请重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && booking?.status == 'paying') _checkWechat();
  }

  void _applyWechat(TogetherWechatResult result) {
    if (!mounted || booking == null) return;
    final b = booking!;
    setState(() {
      booking = TogetherBooking(
        ref: b.ref,
        partyRef: b.partyRef,
        status: result.status,
        basePriceMinor: b.basePriceMinor,
        ageSurchargeMinor: b.ageSurchargeMinor,
        payableMinor: b.payableMinor,
      );
      uncertain = result.status == 'paying';
      if (result.status == 'pending') {
        coupon = null;
        coinsInput.text = '0';
      }
      error = result.status == 'paying' ? '正在核对微信付款，请勿重复付款' : null;
    });
    if (result.status == 'paid') Navigator.pop(context);
  }

  Future<void> _checkWechat({bool cancel = false}) async {
    final b = booking;
    if (!mounted || busy || b == null || b.status != 'paying') return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.wechatBooking(
        b,
        action: cancel ? 'cancel' : 'query',
        storeRef: widget.party.storeRef,
      );
      _applyWechat(result);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AuthFailure ? e.message : '暂未确认微信付款结果，请继续查询原单',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted && booking?.status == 'pending') await _prepare();
  }

  String money(int amount) => '¥${moneyAmount((amount / 100))}';
  @override
  Widget build(BuildContext context) => LegacyClubScaffold(
    title: '确认报名',
    showMockLabel: false,
    onBack: () => Navigator.pop(context),
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.party.theme,
          style: const TextStyle(color: legacyGold, fontSize: 22),
        ),
        const SizedBox(height: 12),
        Text(widget.party.storeName, style: const TextStyle(color: legacyGold)),
        const SizedBox(height: 24),
        if (busy)
          const Center(child: CircularProgressIndicator(color: legacyGold)),
        if (error != null)
          TextButton(
            onPressed: busy
                ? null
                : (booking?.status == 'paying'
                      ? () => _checkWechat()
                      : (uncertain ? _pay : _prepare)),
            child: Text('$error · 重试'),
          ),
        if (booking case final b?) ...[
          Text(
            '入场费用 ${money(b.basePriceMinor)}',
            style: const TextStyle(color: legacyGold),
          ),
          if (b.ageSurchargeMinor > 0)
            Text(
              '年龄附加费 ${money(b.ageSurchargeMinor)}',
              style: const TextStyle(color: legacyGold),
            ),
          const SizedBox(height: 16),
          Text(
            '优惠前应付 ${money(b.payableMinor)}',
            style: const TextStyle(color: legacyGold, fontSize: 22),
          ),
          const SizedBox(height: 24),
          if (b.status == 'paid')
            FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => TogetherTicketPage(
                    party: widget.party,
                    removalRepository: widget.repository,
                    reload: () => widget.repository.admission(widget.party.ref),
                  ),
                ),
              ),
              child: const Text('查看入场券'),
            )
          else if (b.status == 'paying') ...[
            const Text(
              '正在核对微信付款，名额和选用权益暂时保留。',
              style: TextStyle(color: legacyGold),
            ),
            FilledButton(
              onPressed: busy ? null : () => _checkWechat(),
              child: const Text('查询付款结果'),
            ),
            TextButton(
              onPressed: busy ? null : () => _checkWechat(cancel: true),
              child: const Text('取消本次微信付款'),
            ),
          ] else if (b.status == 'pending') ...[
            Text(
              uncertain ? '付款结果待确认，请核对原单。' : '待付款，尚未扣款或占位。',
              style: const TextStyle(color: legacyGold),
            ),
            const SizedBox(height: 12),
            if (coupons.isNotEmpty)
              DropdownButton<String>(
                value: coupon?.ref ?? '',
                dropdownColor: Colors.black,
                style: const TextStyle(color: legacyGold),
                isExpanded: true,
                onChanged: busy || uncertain
                    ? null
                    : (v) => setState(
                        () => coupon = v == ''
                            ? null
                            : coupons.firstWhere((c) => c.ref == v),
                      ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('不使用商家券')),
                  for (final c in coupons)
                    DropdownMenuItem(
                      value: c.ref,
                      child: Text(
                        '${c.name} · 抵${money(c.discountMinor)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            DropdownButton<String>(
              value: method,
              dropdownColor: Colors.black,
              style: const TextStyle(color: legacyGold),
              onChanged: busy || uncertain
                  ? null
                  : (v) => setState(() => method = v!),
              items: [
                if (_wechatAvailable)
                  const DropdownMenuItem(value: 'wechat', child: Text('微信支付')),
                const DropdownMenuItem(
                  value: 'store_balance',
                  child: Text('本店储值（本金及可用赠送额）'),
                ),
                const DropdownMenuItem(
                  value: 'platform_cash',
                  child: Text('APP余额'),
                ),
              ],
            ),
            if (widget.party.allowCoins)
              TextField(
                controller: coinsInput,
                enabled: !busy && !uncertain,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: legacyGold),
                decoration: const InputDecoration(
                  labelText: '使用金币（活动允许时，10金币抵1元）',
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '抵扣后应付 ${money((b.payableMinor - (coupon?.discountMinor ?? 0) - ((int.tryParse(coinsInput.text) ?? 0) * 10)).clamp(0, b.payableMinor))}',
              style: const TextStyle(color: legacyGold, fontSize: 20),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : _pay,
              child: Text(
                uncertain
                    ? '核对原付款结果'
                    : b.payableMinor == 0
                    ? '确认免费报名'
                    : '确认付款',
              ),
            ),
            if (uncertain)
              const Text(
                '付款结果待确认，请核对原操作，勿更换支付方式重复付款。',
                style: TextStyle(color: legacyGold),
              ),
          ] else
            const Text('该报名已取消或退款。', style: TextStyle(color: legacyGold)),
        ],
      ],
    ),
  );
}
