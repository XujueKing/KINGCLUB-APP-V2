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
          TextButton(onPressed: _prepare, child: Text('$error · 重试')),
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
          else
            Text(
              b.status == 'pending' ? '待付款。支付通道暂未接通，尚未扣款或占位。' : '该报名已取消或退款。',
              style: const TextStyle(color: legacyGold),
            ),
        ],
      ],
    ),
  );
}
