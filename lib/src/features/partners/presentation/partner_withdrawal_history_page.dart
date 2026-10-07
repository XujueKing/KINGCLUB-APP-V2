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

class PartnerWithdrawalHistoryPage extends StatefulWidget {
  const PartnerWithdrawalHistoryPage({super.key, required this.call});
  final PartnerCall call;
  @override
  State<PartnerWithdrawalHistoryPage> createState() =>
      _PartnerWithdrawalHistoryPageState();
}

class _PartnerWithdrawalHistoryPageState
    extends State<PartnerWithdrawalHistoryPage> {
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic>? pending;
  String? key;
  bool busy = false, failed = false, invalid = false, more = false;
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

  Future<void> load({bool next = false}) async {
    if (busy || invalid) return;
    setState(() => busy = true);
    try {
      final n = next ? page + 1 : 0;
      final r = await widget.call({'action': 'withdrawal_history', 'page': n});
      final storageKey = 'partner-withdrawal-history-v1-${r['userAccount']}';
      final saved = await const FlutterSecureStorage().read(key: storageKey);
      if (!mounted || invalid) return;
      final items = [
        for (final x in r['items'] as List) Map<String, dynamic>.from(x as Map),
      ];
      setState(() {
        rows = [if (next) ...rows, ...items];
        page = n;
        more = items.length == 30;
        key = storageKey;
        failed = false;
        pending = saved == null
            ? null
            : Map<String, dynamic>.from(jsonDecode(saved) as Map);
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel(Map item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('withdrawCancel')),
        content: Text(t('withdrawCancelNote')),
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
    await send({
      'action': 'withdrawal_cancel',
      'requestId': const Uuid().v4(),
      'withdrawalRef': item['ref'],
    });
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
        throw StateError('Missing cancellation receipt');
      }
      await storage.delete(key: key!);
      if (!mounted || invalid) return;
      setState(() {
        final id = pending!['withdrawalRef'];
        rows = [
          for (final x in rows)
            x['ref'] == id ? {...x, 'status': 'cancelled'} : x,
        ];
        pending = null;
      });
    } catch (e) {
      if (e is AuthFailure &&
          [
            'PARTNER_WITHDRAWAL_STATE',
            'PARTNER_WITHDRAWAL_MISSING',
          ].contains(e.code)) {
        await const FlutterSecureStorage().delete(key: key!);
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
    appBar: kingAppBar(context: context, title: Text(t('withdrawalHistory'))),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final x in rows)
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t(x['kind'] == 'transfer' ? 'transfer' : 'withdraw'),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        '¥${moneyCents(x['amountCents'])}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t(
                      x['kind'] == 'transfer'
                          ? 'transferSuccess'
                          : 'withdraw_${x['status']}',
                    ),
                  ),
                  if (x['bankName'] != null) ...[
                    const SizedBox(height: 8),
                    Text('${x['bankName']}  ${x['accountMasked']}'),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${x['date']}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  if (x['reason'] != null && '${x['reason']}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${x['reason']}'),
                    ),
                  if (x['proofRef'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SelectableText(
                        '${t('payoutProof')}: ${x['proofRef']}',
                      ),
                    ),
                  if (x['kind'] == 'withdrawal' && x['status'] == 'submitted')
                    TextButton(
                      onPressed: busy || invalid || pending != null
                          ? null
                          : () => cancel(x),
                      child: Text(t('withdrawCancel')),
                    ),
                ],
              ),
            ),
          if (rows.isEmpty && !busy && !failed) Text(t('empty')),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (failed) Text(t(pending == null ? 'failed' : 'transferUnknown')),
          if (pending != null)
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: busy || invalid ? null : () => send(pending!),
                child: Text(t('retryOriginal')),
              ),
            ),
          if (failed && pending == null)
            TextButton(onPressed: load, child: Text(t('retry'))),
          if (more)
            TextButton(
              onPressed: busy || invalid ? null : () => load(next: true),
              child: Text(t('more')),
            ),
        ],
      ),
    ),
  );
}
