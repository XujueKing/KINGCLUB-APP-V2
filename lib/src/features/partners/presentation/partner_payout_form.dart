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
import 'partner_amount_field.dart';
import 'partner_bank_cards_page.dart';
import 'partner_strings.dart';

class PartnerPayoutForm extends StatefulWidget {
  const PartnerPayoutForm({
    super.key,
    required this.call,
    required this.withdrawal,
  });
  final PartnerCall call;
  final bool withdrawal;
  @override
  State<PartnerPayoutForm> createState() => _PartnerPayoutFormState();
}

class _PartnerPayoutFormState extends State<PartnerPayoutForm> {
  final amount = TextEditingController(text: '0.00');
  Map<String, dynamic>? data, pending;
  String? storageKey, selected;
  bool busy = false, failed = false, invalid = false, success = false;
  bool amountInitialized = false;
  StreamSubscription<void>? session;
  String t(String key) => partnerText(context, key);
  List<Map<String, dynamic>> get cards => [
    for (final card in (data?['cards'] as List? ?? []))
      Map<String, dynamic>.from(card as Map),
  ];
  int get limit => partnerAmountLimit(data?['availableCents']);
  bool get active =>
      data?[widget.withdrawal ? 'canWithdraw' : 'canTransfer'] == true ||
      data?[widget.withdrawal ? 'canWithdraw' : 'canTransfer'] == 1;
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
    amount.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (busy || invalid) return;
    setState(() => busy = true);
    try {
      final r = await widget.call({
        'action': widget.withdrawal ? 'withdrawal_form' : 'finance',
      });
      final key = widget.withdrawal
          ? 'partner-withdrawal-card-v1-${r['userAccount']}'
          : 'partner-transfer-v1-${r['userAccount']}';
      final saved = await const FlutterSecureStorage().read(key: key);
      if (!mounted || invalid) return;
      setState(() {
        data = r;
        storageKey = key;
        failed = false;
        pending = saved == null
            ? null
            : Map<String, dynamic>.from(jsonDecode(saved) as Map);
        selected =
            pending?['cardRef'] as String? ??
            (cards.isEmpty ? null : cards.first['ref'] as String);
      });
      if (pending != null) {
        amount.text = moneyCents(pending!['amountCents']);
      } else if (!amountInitialized ||
          (partnerAmountCents(amount.text) ?? 0) > limit) {
        amount.text = moneyCents(limit);
      }
      amountInitialized = true;
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> manageCards() async {
    FocusScope.of(context).unfocus();
    final r = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerBankCardsPage(
          call: widget.call,
          initial: data!,
          onChanged: acceptCards,
        ),
      ),
    );
    if (r != null) acceptCards(r);
  }

  void acceptCards(Map<String, dynamic> r) {
    if (!mounted || invalid) return;
    setState(() {
      data = r;
      if (!cards.any((c) => c['ref'] == selected)) {
        selected = cards.isEmpty ? null : cards.first['ref'] as String;
      }
    });
    if ((partnerAmountCents(amount.text) ?? 0) > limit) {
      amount.text = moneyCents(limit);
    }
  }

  Future<void> submit() async {
    if (busy || invalid || data == null) return;
    FocusScope.of(context).unfocus();
    if (pending == null) {
      final n = partnerAmountCents(amount.text);
      if (!active ||
          n == null ||
          n < 1 ||
          n > limit ||
          (widget.withdrawal && !cards.any((c) => c['ref'] == selected))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(widget.withdrawal ? 'withdrawInvalid' : 'transferInvalid'),
            ),
          ),
        );
        return;
      }
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(t(widget.withdrawal ? 'withdrawApply' : 'transfer')),
          content: Text(
            '${t(widget.withdrawal ? 'withdrawConfirm' : 'transferConfirm')}\n¥${moneyCents(n)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(t('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(t('confirm')),
            ),
          ],
        ),
      );
      if (yes != true || !mounted || invalid) return;
      pending = {
        'action': widget.withdrawal ? 'withdrawal_apply' : 'transfer',
        'requestId': const Uuid().v4(),
        'amountCents': n,
        if (widget.withdrawal) 'cardRef': selected,
      };
    }
    setState(() {
      busy = true;
      failed = false;
      success = false;
    });
    try {
      const storage = FlutterSecureStorage();
      await storage.write(key: storageKey!, value: jsonEncode(pending));
      if (!mounted || invalid) return;
      final r = await widget.call(pending!);
      final ref = widget.withdrawal
          ? r['receiptRef']
          : (r['receipt'] as Map?)?['ref'];
      if (ref != pending!['requestId']) {
        throw StateError('Missing payout receipt');
      }
      await storage.delete(key: storageKey!);
      if (!mounted || invalid) return;
      setState(() {
        data = {...data!, ...r};
        pending = null;
        success = true;
        amount.text = moneyCents(limit);
      });
    } catch (e) {
      if (e is AuthFailure &&
          [
            'PARTNER_FUNDS_INSUFFICIENT',
            'PARTNER_ACTIVE_REQUIRED',
            'PARTNER_CARD_MISSING',
            'PARTNER_ASSETS_UNAVAILABLE',
          ].contains(e.code)) {
        await const FlutterSecureStorage().delete(key: storageKey!);
        pending = null;
      }
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: Text(t(widget.withdrawal ? 'withdraw' : 'transfer')),
    ),
    body: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (data == null && busy)
              const Center(child: CircularProgressIndicator()),
            if (data != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xff202020),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(
                        widget.withdrawal
                            ? 'withdrawAvailable'
                            : 'transferAvailable',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '¥${moneyCents(data!['availableCents'])}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (!widget.withdrawal) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${t('platformCash')}  ¥${moneyCents(data!['cashCents'])}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (widget.withdrawal) ...[
                if (cards.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: cards.any((c) => c['ref'] == selected)
                        ? selected
                        : null,
                    key: ValueKey(selected),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t('selectBankCard'),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: true,
                      fillColor: const Color(0xff202020),
                      contentPadding: const EdgeInsets.all(18),
                    ),
                    items: [
                      for (final c in cards)
                        DropdownMenuItem(
                          value: c['ref'] as String,
                          child: Text(
                            '${c['bankName']}  ${c['accountMasked']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: busy || invalid || pending != null
                        ? null
                        : (v) => setState(() => selected = v),
                  ),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: busy || invalid || pending != null
                        ? null
                        : manageCards,
                    child: Text(
                      t(cards.isEmpty ? 'addBankCard' : 'manageBankCards'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              PartnerAmountField(
                controller: amount,
                limit: limit,
                label: t(
                  widget.withdrawal ? 'withdrawAmount' : 'transferAmount',
                ),
                enabled: !busy && !invalid && pending == null && active,
              ),
              const SizedBox(height: 20),
              Text(
                t(widget.withdrawal ? 'withdrawNote' : 'transferNote'),
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed:
                      busy ||
                          invalid ||
                          (pending == null &&
                              (!active ||
                                  limit == 0 ||
                                  (widget.withdrawal && selected == null)))
                      ? null
                      : submit,
                  child: Text(
                    t(
                      busy
                          ? 'saving'
                          : pending != null
                          ? 'retryOriginal'
                          : widget.withdrawal
                          ? 'withdrawApply'
                          : 'transfer',
                    ),
                  ),
                ),
              ),
            ],
            if (success)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  t(widget.withdrawal ? 'withdrawSuccess' : 'transferSuccess'),
                  style: const TextStyle(color: Colors.greenAccent),
                ),
              ),
            if (failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(t(pending != null ? 'transferUnknown' : 'failed')),
              ),
            if ((data == null || failed && pending == null) && !busy)
              TextButton(onPressed: load, child: Text(t('retry'))),
          ],
        ),
      ),
    ),
  );
}
