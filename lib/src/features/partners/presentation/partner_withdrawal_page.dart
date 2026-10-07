import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/formatters/money.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';
import 'partner_payout_form.dart';

class PartnerWithdrawalPage extends StatelessWidget {
  const PartnerWithdrawalPage({
    super.key,
    required this.call,
    this.review = false,
  });
  final PartnerCall call;
  final bool review;
  @override
  Widget build(BuildContext context) => review
      ? _PartnerWithdrawalReviewPage(call: call, review: true)
      : PartnerPayoutForm(call: call, withdrawal: true);
}

class _PartnerWithdrawalReviewPage extends StatefulWidget {
  const _PartnerWithdrawalReviewPage({required this.call, this.review = true});
  final PartnerCall call;
  final bool review;
  @override
  State<_PartnerWithdrawalReviewPage> createState() =>
      _PartnerWithdrawalReviewPageState();
}

class _PartnerWithdrawalReviewPageState
    extends State<_PartnerWithdrawalReviewPage> {
  Map<String, dynamic>? data, pending;
  String? key;
  bool busy = false, failed = false, invalid = false;
  int page = 0;
  StreamSubscription<void>? session;
  String t(String k) => partnerText(context, k);
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) setState(() => invalid = true);
    });
    load();
  }

  @override
  void dispose() {
    session?.cancel();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (busy || invalid) return;
    setState(() => busy = true);
    try {
      final next = more ? page + 1 : 0;
      final r = await widget.call({
        'action': 'withdrawal_list',
        'page': next,
        'review': widget.review ? 1 : 0,
      });
      final storageKey =
          'partner-withdrawal-v1-${r['userAccount']}-${widget.review}';
      final saved = await const FlutterSecureStorage().read(key: storageKey);
      if (!mounted || invalid) return;
      if (more) r['items'] = [...data!['items'] as List, ...r['items'] as List];
      setState(() {
        data = r;
        key = storageKey;
        page = next;
        pending = saved == null
            ? null
            : Map<String, dynamic>.from(jsonDecode(saved) as Map);
        failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> send(Map<String, dynamic> p) async {
    if (busy || invalid) return;
    pending ??= p;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      const storage = FlutterSecureStorage();
      await storage.write(key: key!, value: jsonEncode(pending));
      if (!mounted || invalid) return;
      final r = await widget.call(pending!);
      if (r['receiptRef'] != pending!['requestId']) {
        throw StateError('Missing action receipt');
      }
      await storage.delete(key: key!);
      if (!mounted || invalid) return;
      setState(() {
        data = r;
        pending = null;
        page = 0;
      });
    } catch (e) {
      if (e is AuthFailure &&
          [
            'PARTNER_FUNDS_INSUFFICIENT',
            'PARTNER_ACTIVE_REQUIRED',
            'PARTNER_SELF_REVIEW',
            'PARTNER_WITHDRAWAL_STATE',
            'PARTNER_PROOF_INVALID',
            'PARTNER_PROOF_DUPLICATE',
          ].contains(e.code)) {
        await const FlutterSecureStorage().delete(key: key!);
        pending = null;
      }
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> form(String action, [Map? item]) async {
    if (busy || pending != null || invalid) return;
    final value = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff202020),
      builder: (_) => _WithdrawalForm(action: action, item: item),
    );
    if (value == null || !mounted || invalid) return;
    await send({
      'action': action,
      'requestId': const Uuid().v4(),
      if (item != null) 'withdrawalRef': item['ref'],
      if (widget.review) 'review': 1,
      ...value,
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && !invalid && pending == null;
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: context,
        title: Text(
          t(widget.review ? 'withdrawReview' : 'withdraw'),
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xff111111),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (data == null && busy)
              const Center(child: CircularProgressIndicator()),
            if (pending != null) ...[
              Text(t('actionFailed')),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: busy || invalid ? null : () => send(pending!),
                  child: Text(t('retryOriginal')),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (failed && pending == null) Text(t('withdrawFailed')),
            if (!busy && pending == null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: invalid ? null : () => load(),
                  child: Text(t('refresh')),
                ),
              ),
            if (data != null && (data!['items'] as List).isEmpty)
              Text(t('empty')),
            if (data != null)
              for (final item in data!['items'] as List)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xff202020),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '¥${moneyCents(item['amountCents'])}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(t('withdraw_${item['status']}')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${t(item['channel'] == 'bank' ? 'bank' : 'wechat')} · ${item['payeeName']}',
                      ),
                      const SizedBox(height: 8),
                      SelectableText('${item['payeeAccount']}'),
                      const SizedBox(height: 8),
                      Text(
                        '${item['date']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (widget.review)
                        Text(
                          '${item['partnerAccount']}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      if (item['reason'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('${item['reason']}'),
                        ),
                      if (item['proofRef'] != null) ...[
                        const Divider(),
                        Text(t('payoutProof')),
                        SelectableText('${item['proofRef']}'),
                        Text('${item['paidAt']}'),
                      ],
                      const SizedBox(height: 8),
                      SelectableText(
                        '${item['ref']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      if (widget.review &&
                          [
                            'submitted',
                            'approved',
                          ].contains(item['status'])) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: enabled
                                ? () => form('withdrawal_review', item as Map)
                                : null,
                            child: Text(t('withdrawReview')),
                          ),
                        ),
                        if (item['status'] == 'approved') ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: enabled
                                  ? () => form('withdrawal_paid', item as Map)
                                  : null,
                              child: Text(t('recordPayout')),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
            if (data != null &&
                (data!['items'] as List).length == (page + 1) * 30)
              TextButton(
                onPressed: enabled ? () => load(more: true) : null,
                child: Text(t('more')),
              ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawalForm extends StatefulWidget {
  const _WithdrawalForm({required this.action, this.item});
  final String action;
  final Map? item;
  @override
  State<_WithdrawalForm> createState() => _WithdrawalFormState();
}

class _WithdrawalFormState extends State<_WithdrawalForm> {
  final reason = TextEditingController(), proof = TextEditingController();
  String decision = 'approved';
  DateTime paidAt = DateTime.now();
  String? error;
  String t(String k) => partnerText(context, k);
  @override
  void initState() {
    super.initState();
    if (widget.item?['status'] == 'approved') decision = 'rejected';
  }

  @override
  void dispose() {
    for (final c in [reason, proof]) {
      c.dispose();
    }
    super.dispose();
  }

  void submit() {
    Map<String, dynamic> result;
    if (widget.action == 'withdrawal_review') {
      if (reason.text.trim().isEmpty) {
        setState(() => error = t('reviewReason'));
        return;
      }
      result = {'decision': decision, 'reason': reason.text.trim()};
    } else {
      if (proof.text.trim().length < 3) {
        setState(() => error = t('payoutProof'));
        return;
      }
      result = {
        'proofRef': proof.text.trim(),
        'paidAt': DateTime.fromMillisecondsSinceEpoch(
          paidAt.millisecondsSinceEpoch,
          isUtc: true,
        ).toIso8601String(),
      };
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(
                widget.action == 'withdrawal_review'
                    ? 'withdrawReview'
                    : 'recordPayout',
              ),
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
            const SizedBox(height: 20),
            if (widget.action == 'withdrawal_review') ...[
              DropdownButtonFormField<String>(
                initialValue: decision,
                items: [
                  if (widget.item?['status'] == 'submitted')
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text(t('approve')),
                    ),
                  DropdownMenuItem(value: 'rejected', child: Text(t('reject'))),
                ],
                onChanged: (v) => setState(() => decision = v!),
              ),
              TextField(
                controller: reason,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(labelText: t('reviewReason')),
              ),
            ] else ...[
              Text(
                t('payoutProofNote'),
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                '¥${moneyCents(widget.item!['amountCents'])}',
                style: const TextStyle(fontSize: 24),
              ),
              TextField(
                controller: proof,
                maxLength: 128,
                decoration: InputDecoration(labelText: t('payoutProof')),
              ),
              TextButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: paidAt,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now(),
                  );
                  if (d == null || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(paidAt),
                  );
                  if (time != null && mounted) {
                    setState(
                      () => paidAt = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  }
                },
                child: Text(
                  '${t('payoutTime')} ${paidAt.toLocal().toString().substring(0, 16)}',
                ),
              ),
            ],
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(onPressed: submit, child: Text(t('confirm'))),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('cancel')),
            ),
          ],
        ),
      ),
    ),
  );
}
