import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';

class PartnerBankCardsPage extends StatefulWidget {
  const PartnerBankCardsPage({
    super.key,
    required this.call,
    required this.initial,
    this.onChanged,
  });
  final PartnerCall call;
  final Map<String, dynamic> initial;
  final ValueChanged<Map<String, dynamic>>? onChanged;
  @override
  State<PartnerBankCardsPage> createState() => _PartnerBankCardsPageState();
}

class _PartnerBankCardsPageState extends State<PartnerBankCardsPage> {
  late Map<String, dynamic> data = widget.initial;
  Map<String, dynamic>? pending;
  bool busy = true, failed = false, invalid = false;
  StreamSubscription<void>? session;
  String get key => 'partner-bank-cards-v1-${data['userAccount']}';
  String t(String k) => partnerText(context, k);
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) setState(() => invalid = true);
    });
    restore();
  }

  @override
  void dispose() {
    session?.cancel();
    super.dispose();
  }

  Future<void> restore() async {
    try {
      final saved = await const FlutterSecureStorage().read(key: key);
      if (mounted && !invalid) {
        setState(
          () => pending = saved == null
              ? null
              : Map<String, dynamic>.from(jsonDecode(saved) as Map),
        );
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> send(Map<String, dynamic> input) async {
    if (busy || invalid) return;
    pending ??= input;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      const storage = FlutterSecureStorage();
      await storage.write(key: key, value: jsonEncode(pending));
      if (!mounted || invalid) return;
      final r = await widget.call(pending!);
      if (r['receiptRef'] != pending!['requestId']) {
        throw StateError('Missing card receipt');
      }
      await storage.delete(key: key);
      if (mounted && !invalid) {
        widget.onChanged?.call(r);
        setState(() {
          data = r;
          pending = null;
        });
      }
    } catch (e) {
      if (e is AuthFailure &&
          [
            'PARTNER_CARD_INVALID',
            'PARTNER_CARD_MISSING',
            'PARTNER_CARD_LIMIT',
            'PARTNER_CARD_DUPLICATE',
            'PARTNER_ACTIVE_REQUIRED',
          ].contains(e.code)) {
        await const FlutterSecureStorage().delete(key: key);
        pending = null;
      }
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff202020),
      builder: (_) => const _CardForm(),
    );
    if (result != null && mounted && !invalid) {
      await send({
        'action': 'bank_card_add',
        'requestId': const Uuid().v4(),
        ...result,
      });
    }
  }

  Future<void> remove(Map card) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('removeBankCard')),
        content: Text('${card['bankName']}  ${card['accountMasked']}'),
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
    if (yes == true && mounted && !invalid) {
      await send({
        'action': 'bank_card_remove',
        'requestId': const Uuid().v4(),
        'cardRef': card['ref'],
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Map<String, dynamic>>(
    canPop: true,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) Navigator.pop(context, data);
    },
    child: Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: context,
        title: Text(t('manageBankCards')),
        leading: KingBackButton(onPressed: () => Navigator.pop(context, data)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final c in data['cards'] as List? ?? [])
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xff202020),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c['bankName']}',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${c['accountMasked']}',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${c['payeeName']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: busy || invalid || pending != null
                        ? null
                        : () => remove(c as Map),
                    child: Text(t('removeBankCard')),
                  ),
                ],
              ),
            ),
          if ((data['cards'] as List? ?? []).isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(t('noBankCards')),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: busy || invalid
                  ? null
                  : pending != null
                  ? () => send(pending!)
                  : add,
              child: Text(
                t(
                  busy
                      ? 'saving'
                      : pending != null
                      ? 'retryOriginal'
                      : 'addBankCard',
                ),
              ),
            ),
          ),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(t(pending == null ? 'failed' : 'transferUnknown')),
            ),
        ],
      ),
    ),
  );
}

class _CardForm extends StatefulWidget {
  const _CardForm();
  @override
  State<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<_CardForm> {
  final holder = TextEditingController(),
      bank = TextEditingController(),
      number = TextEditingController();
  bool invalid = false;
  @override
  void dispose() {
    holder.dispose();
    bank.dispose();
    number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () => FocusScope.of(context).unfocus(),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                partnerText(context, 'addBankCard'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: holder,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: partnerText(context, 'payeeName'),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bank,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: partnerText(context, 'bankName'),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: number,
                maxLength: 34,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
                decoration: InputDecoration(
                  labelText: partnerText(context, 'bankAccount'),
                  counterText: '',
                ),
              ),
              if (invalid)
                Text(
                  partnerText(context, 'bankCardInvalid'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (holder.text.trim().isEmpty ||
                        bank.text.trim().isEmpty ||
                        !RegExp(r'^[A-Z0-9]{8,34}$')
                            .hasMatch(number.text.toUpperCase())) {
                      setState(() => invalid = true);
                      return;
                    }
                    Navigator.pop(context, <String, dynamic>{
                      'payeeName': holder.text.trim(),
                      'bankName': bank.text.trim(),
                      'accountNumber': number.text.toUpperCase(),
                    });
                  },
                  child: Text(partnerText(context, 'saveBankCard')),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
