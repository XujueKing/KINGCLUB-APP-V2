import 'package:kingclub/src/core/formatters/money.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/auth_repository.dart';
import '../data/together_play.dart';
import 'legacy_club_components.dart';

class TogetherRemovalPage extends StatefulWidget {
  const TogetherRemovalPage({
    super.key,
    required this.partyRef,
    required this.repository,
  });
  final String partyRef;
  final TogetherRemovalRepository repository;
  @override
  State<TogetherRemovalPage> createState() => _TogetherRemovalPageState();
}

class _TogetherRemovalPageState extends State<TogetherRemovalPage> {
  final items = <TogetherRemovalMember>[];
  bool busy = false, canManage = false, uncertain = false;
  String? next, error, requestRef;
  String method = 'platform_cash';
  TogetherRemovalMember? selected;
  TogetherRemovalQuote? quote;
  String money(int n) => '¥${moneyAmount((n / 100))}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await widget.repository.removalMembers(
        widget.partyRef,
        after: more ? next : null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        canManage = r.canManage;
        next = r.next;
        if (!more) {
          items.clear();
        }
        items.addAll(r.items);
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = '参加者暂时无法加载，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _choose(TogetherRemovalMember member) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final q = await widget.repository.removalQuote(
        widget.partyRef,
        member.bookingRef,
      );
      if (mounted) {
        setState(() {
          selected = member;
          quote = q;
          requestRef = const Uuid().v4();
          method = q.methods.first;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = '无法获取移除费用，请刷新参加者');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _pay() async {
    if (busy || quote == null) {
      return;
    }
    setState(() {
      busy = true;
      uncertain = true;
      error = null;
    });
    try {
      await widget.repository.payRemoval(
        widget.partyRef,
        quote!,
        requestRef: requestRef!,
        method: method,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        quote = null;
        selected = null;
        uncertain = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('付费完成，已移除参加者并作废入场券')));
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          final known =
              e is AuthFailure &&
              {
                'MEMBER_ASSETS_INSUFFICIENT',
                'MEMBER_ASSETS_UNAVAILABLE',
                'MEMBER_ASSETS_RANGE',
                'MEMBER_ASSETS_CHANGED',
                'TOGETHER_REMOVAL_PRICE_CHANGED',
                'TOGETHER_REMOVAL_UNAVAILABLE',
                'TOGETHER_REMOVAL_FORBIDDEN',
                'TOGETHER_WECHAT_NOT_READY',
              }.contains(e.code);
          uncertain = !known;
          error = e is AuthFailure ? e.message : '正在核对原付款，请勿重复发起或更换参加者';
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => LegacyClubScaffold(
    title: quote == null ? '本场参加者' : '付费移除',
    onBack: () => Navigator.pop(context),
    showMockLabel: false,
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error!, style: const TextStyle(color: legacyPink)),
        if (quote == null) ...[
          if (!busy && !canManage)
            const Text(
              '发起者或本场已报名参加者可提出移除',
              style: TextStyle(color: legacyGold),
            ),
          if (!busy && canManage && items.isEmpty)
            const Text('暂无其他参加者', style: TextStyle(color: legacyGold)),
          for (final member in items)
            ListTile(
              title: Text(
                member.name,
                style: const TextStyle(color: legacyGold),
              ),
              subtitle: Text(
                member.admitted ? '已入场' : '未入场',
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: TextButton(
                onPressed: busy ? null : () => _choose(member),
                child: const Text('移除'),
              ),
            ),
          if (next != null)
            TextButton(
              onPressed: busy ? null : () => _load(more: true),
              child: const Text('加载更多'),
            ),
          TextButton(
            onPressed: busy ? null : () => _load(),
            child: const Text('刷新'),
          ),
        ] else ...[
          Text(
            '移除 ${selected!.name}',
            style: const TextStyle(color: legacyGold, fontSize: 22),
          ),
          const SizedBox(height: 20),
          Text(
            '原路退还参加者：${money(quote!.refundMinor)}\n额外赔偿参加者：${money(quote!.participantCompensationMinor)}\n补偿商家：${money(quote!.merchantCompensationMinor)}',
            style: const TextStyle(color: legacyGold, height: 2),
          ),
          const SizedBox(height: 16),
          Text(
            '本次需支付 ${money(quote!.totalMinor)}',
            style: const TextStyle(color: legacyGold, fontSize: 24),
          ),
          const Text(
            '由你承担上述费用，付款成功后才移除参加者。',
            style: TextStyle(color: Colors.white70),
          ),
          DropdownButton<String>(
            value: method,
            dropdownColor: Colors.black,
            style: const TextStyle(color: legacyGold),
            onChanged: busy || uncertain
                ? null
                : (v) => setState(() => method = v!),
            items: [
              for (final m in quote!.methods)
                DropdownMenuItem(
                  value: m,
                  child: Text(m == 'platform_cash' ? 'APP现金余额' : '微信支付'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : _pay,
            child: Text(uncertain ? '核对原付款结果' : '确认付费并移除'),
          ),
          TextButton(
            onPressed: busy || uncertain
                ? null
                : () => setState(() {
                    quote = null;
                    selected = null;
                    error = null;
                  }),
            child: const Text('返回参加者'),
          ),
        ],
      ],
    ),
  );
}
