import 'package:kingclub/src/core/formatters/money.dart';

import '../data/together_rule_summary.dart';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/auth_repository.dart';
import '../data/secure_together_publication.dart';
import '../data/together_party_draft.dart';
import 'legacy_club_components.dart';
import 'reservation_components.dart';

/// Returns the server's party reference only after confirmed publication.
class TogetherPublishConfirmationPage extends StatefulWidget {
  const TogetherPublishConfirmationPage({
    super.key,
    required this.draft,
    required this.publication,
  });
  final TogetherPartyDraft draft;
  final SecureTogetherPublication publication;
  @override
  State<TogetherPublishConfirmationPage> createState() => _ConfirmationState();
}

class _ConfirmationState extends State<TogetherPublishConfirmationPage> {
  final _quoteRequest = const Uuid().v4();
  final _publishRequest = const Uuid().v4();
  TogetherPublicationQuote? _quote;
  bool _busy = true, _accepted = false, _attempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final quote = await widget.publication.quote(
        widget.draft,
        requestRef: _quoteRequest,
      );
      if (mounted) setState(() => _quote = quote);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法取得报价，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final quote = _quote;
    if (_busy || !_accepted || quote == null) return;
    // A previous result may be unknown: do not replace either request or quote.
    if (!_attempted && !quote.expiresAt.isAfter(DateTime.now())) {
      setState(() => _error = '报价已过期，请返回重新确认');
      return;
    }
    setState(() {
      _busy = true;
      _attempted = true;
      _error = null;
    });
    try {
      final ref = await widget.publication.publish(
        quote,
        requestRef: _publishRequest,
      );
      if (mounted) Navigator.of(context).pop(ref);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '发布结果尚未确认，请点击重试确认，避免重新发起');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _money(String cents) {
    final n = BigInt.parse(cents);
    return moneyCents(n);
  }

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    return PopScope(
      canPop: !_busy,
      child: LegacyClubScaffold(
        title: '确认发布',
        titleColor: Colors.white,
        titleFontSize: 17,
        titleFontWeight: FontWeight.w600,
        showMockLabel: false,
        onBack: () {
          if (!_busy) Navigator.of(context).pop();
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.draft.theme,
              style: const TextStyle(
                color: legacyGold,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.draft.store.name,
              style: const TextStyle(color: legacyGold),
            ),
            if (widget.draft.eligibilityRules.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  togetherRuleSummary(widget.draft.eligibilityRules),
                  style: const TextStyle(color: legacyGold, height: 1.6),
                ),
              ),
            const SizedBox(height: 24),
            if (q != null) ...[
              Text(
                widget.draft.backedPublication
                    ? widget.draft.contractRef == null
                          ? '商家官方活动 · 无需押金'
                          : '签约位置活动 · 无需另付押金'
                    : '冻结 APP 余额 ¥${_money(q.depositCents)}',
                style: const TextStyle(color: legacyPink, fontSize: 22),
              ),
              const SizedBox(height: 12),
              Text(
                q.malePriceCents != null && q.femalePriceCents != null
                    ? '男士 ¥${_money(q.malePriceCents!)} / 位 · 女士 ¥${_money(q.femalePriceCents!)} / 位'
                    : '票价 ¥${_money(q.priceCents)} / 位',
                style: const TextStyle(color: legacyGold, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Text(
                widget.draft.backedPublication
                    ? widget.draft.contractRef == null
                          ? '本店官方活动预留真实位置，购买前不公开编号。'
                          : '按本人合同编号发布，参加者购买前可查看位置和已加入人数。'
                    : '个人发起按商家基础消费冻结 APP 余额。参加者付款并入场核销后，按实收口径立即解冻，最多解冻原押金。',
                style: const TextStyle(color: legacyGold, height: 1.6),
              ),
              const SizedBox(height: 12),
              const Text(
                '活动至少提前48小时取消；发起人取消按整场总费用承担20%违约金。',
                style: TextStyle(color: legacyGold, height: 1.6),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: legacyGold,
                value: _accepted,
                onChanged: _busy || _attempted
                    ? null
                    : (v) => setState(() => _accepted = v ?? false),
                title: Text(
                  widget.draft.backedPublication
                      ? '确认活动价格、位置与发布规则'
                      : '确认活动价格与押金规则',
                  style: TextStyle(color: legacyGold),
                ),
              ),
            ],
            if (_error != null)
              Text(_error!, style: const TextStyle(color: legacyPink)),
            const SizedBox(height: 20),
            if (_busy)
              const Center(child: CircularProgressIndicator(color: legacyGold)),
            if (!_busy && q == null)
              TextButton(onPressed: _load, child: const Text('重新获取报价')),
            if (q != null)
              reservationButton(
                _attempted
                    ? '重试确认发布'
                    : widget.draft.backedPublication
                    ? '确认发布AA邀请'
                    : '确认冻结押金并发布',
                _busy || !_accepted ? null : _publish,
              ),
          ],
        ),
      ),
    );
  }
}
