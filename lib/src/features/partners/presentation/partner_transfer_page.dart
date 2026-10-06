import 'dart:convert';
import 'dart:async';

import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/formatters/money.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';

class PartnerTransferPage extends StatefulWidget {
  const PartnerTransferPage({super.key, required this.call});
  final PartnerCall call;
  @override
  State<PartnerTransferPage> createState() => _PartnerTransferPageState();
}

class _PartnerTransferPageState extends State<PartnerTransferPage> {
  final amount = TextEditingController();
  Map<String, dynamic>? data, pending;
  bool busy = false, failed = false, success = false, invalid = false;
  StreamSubscription<void>? session;
  bool get canTransfer =>
      data?['canTransfer'] == true || data?['canTransfer'] == 1;
  String? storageKey;
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
    amount.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final result = await widget.call({'action': 'finance'});
      final key = 'partner-transfer-v1-${result['userAccount']}';
      const prefs = FlutterSecureStorage();
      final saved = await prefs.read(key: key);
      final request = saved == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(saved) as Map);
      if (!mounted || invalid) return;
      setState(() {
        data = result;
        storageKey = key;
        pending = request;
        failed = false;
      });
      if (request != null) {
        amount.text = moneyCents(request['amountCents']).replaceAll(',', '');
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  int? get cents {
    final text = amount.text.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) return null;
    final parts = text.split('.');
    final n = int.tryParse(parts[0]);
    if (n == null) return null;
    return n * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  }

  Future<void> submit() async {
    if (busy || invalid || data == null) return;
    if (pending == null) {
      final value = cents;
      final available =
          BigInt.tryParse('${data!['availableCents']}') ?? BigInt.zero;
      if (value == null ||
          value < 1 ||
          value > 999999999 ||
          BigInt.from(value) > available) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('transferInvalid'))));
        return;
      }
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(t('transfer')),
          content: Text('${t('transferConfirm')}\n¥${moneyCents(value)}'),
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
        'action': 'transfer',
        'requestId': const Uuid().v4(),
        'amountCents': value,
      };
    }
    setState(() {
      busy = true;
      failed = false;
      success = false;
    });
    try {
      const prefs = FlutterSecureStorage();
      await prefs.write(key: storageKey!, value: jsonEncode(pending));
      if (!mounted || invalid) return;
      final result = await widget.call(pending!);
      final receipt = result['receipt'] as Map?;
      if (receipt?['ref'] != pending!['requestId']) {
        throw StateError('Missing receipt');
      }
      await prefs.delete(key: storageKey!);
      if (!mounted || invalid) return;
      setState(() {
        data = result;
        pending = null;
        success = true;
        amount.clear();
      });
    } catch (e) {
      if (e is AuthFailure &&
          [
            'PARTNER_FUNDS_INSUFFICIENT',
            'PARTNER_ACTIVE_REQUIRED',
            'PARTNER_ASSETS_UNAVAILABLE',
          ].contains(e.code)) {
        const prefs = FlutterSecureStorage();
        await prefs.delete(key: storageKey!);
        pending = null;
      }
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: context,
        title: Text(t('transfer'), style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xff111111),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (d == null && busy)
              const Center(child: CircularProgressIndicator()),
            if (d != null) ...[
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('transferAvailable'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '¥${moneyCents(d['availableCents'])}',
                      style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${t('pendingReward')}  ¥${moneyCents(d['pendingCents'])}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${t('platformCash')}  ¥${moneyCents(d['cashCents'])}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t('transferNote'),
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amount,
                enabled: !invalid && !busy && pending == null && canTransfer,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: t('transferAmount'),
                  prefixText: '¥ ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: busy || (pending == null && !canTransfer)
                      ? null
                      : submit,
                  child: Text(
                    busy
                        ? t('saving')
                        : pending != null
                        ? t('retryOriginal')
                        : t('transfer'),
                  ),
                ),
              ),
            ],
            if (success)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  t('transferSuccess'),
                  style: const TextStyle(color: Colors.greenAccent),
                ),
              ),
            if (failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  pending != null ? t('transferUnknown') : t('failed'),
                ),
              ),
            if (d == null && !busy)
              TextButton(onPressed: load, child: Text(t('retry'))),
            if (d != null) ...[
              const SizedBox(height: 28),
              Text(t('transferHistory'), style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 12),
              if ((d['items'] as List).isEmpty) Text(t('empty')),
              for (final item in d['items'] as List)
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¥${moneyCents(item['amountCents'])}',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${item['date']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      SelectableText(
                        '${item['ref']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _panel(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xff202020),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}
