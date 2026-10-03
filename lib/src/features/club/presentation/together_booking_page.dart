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

class _TogetherBookingPageState extends State<TogetherBookingPage> {
  final requestRef = const Uuid().v4();
  TogetherBooking? booking;
  bool busy = false;
  String? error;
  String method = 'store_balance';
  final coinsInput = TextEditingController(text: '0');
  bool uncertain = false;
  int? sentCoins;
  String? sentMethod;

  @override
  void dispose() {
    coinsInput.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final b = booking;
    if (busy || b == null || b.status != 'pending') return;
    final coins = uncertain ? sentCoins : int.tryParse(coinsInput.text);
    if (coins == null || coins < 0 || coins * 10 > b.payableMinor) {
      setState(() => error = '请填写有效金币数，10金币抵1元');
      return;
    }
    final selected = uncertain
        ? sentMethod!
        : (b.payableMinor == coins * 10 ? 'free' : method);
    sentCoins = coins;
    sentMethod = selected;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final paid = await widget.repository.payBooking(
        b,
        method: selected,
        coins: coins,
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
                    'TOGETHER_COINS_NOT_ALLOWED',
                    'TOGETHER_COINS_EXCESS',
                    'TOGETHER_BALANCE_INSUFFICIENT',
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
      if (mounted) setState(() => booking = result);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is AuthFailure ? e.message : '暂时无法确认报名，请重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String money(int amount) => '¥${(amount / 100).toStringAsFixed(2)}';
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
            onPressed: busy ? null : (uncertain ? _pay : _prepare),
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
                    reload: () => widget.repository.admission(widget.party.ref),
                  ),
                ),
              ),
              child: const Text('查看入场券'),
            )
          else if (b.status == 'pending') ...[
            const Text('待付款，尚未扣款或占位。', style: TextStyle(color: legacyGold)),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: method,
              dropdownColor: Colors.black,
              style: const TextStyle(color: legacyGold),
              onChanged: busy || uncertain
                  ? null
                  : (v) => setState(() => method = v!),
              items: const [
                DropdownMenuItem(
                  value: 'store_balance',
                  child: Text('本店储值（本金及可用赠送额）'),
                ),
                DropdownMenuItem(value: 'platform_cash', child: Text('APP余额')),
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
              '抵扣后应付 ${money((b.payableMinor - ((int.tryParse(coinsInput.text) ?? 0) * 10)).clamp(0, b.payableMinor))}',
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
