import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/member_payment_code_repository.dart';
import '../data/member_balance_snapshot.dart';
import 'member_balance_strings.dart';

/// A short-lived payment authorization, never a member identity QR.
/// Hiding a code does not revoke a grant already issued on the server.
class MemberPaymentCodePage extends StatefulWidget {
  const MemberPaymentCodePage({
    super.key,
    required this.storeRef,
    required this.storeName,
    required this.accountType,
    this.issue,
  });
  final String storeRef, storeName, accountType;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? issue;
  @override
  State<MemberPaymentCodePage> createState() => _MemberPaymentCodePageState();
}

class _MemberPaymentCodePageState extends State<MemberPaymentCodePage>
    with WidgetsBindingObserver {
  final amount = TextEditingController();
  final age = Stopwatch();
  StreamSubscription<void>? sessionChanges;
  Timer? timer;
  String? code;
  DateTime? expires;
  int epoch = 0;
  bool consent = false, busy = false, failed = false, foreground = true;
  String t(String key) => memberBalanceText(context, key);
  bool get validScope =>
      RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(widget.storeRef) &&
      ['platform_cash', 'store_balance'].contains(widget.accountType);
  int? get cents {
    final value = amount.text.trim();
    if (!RegExp(r'^(0|[1-9][0-9]{0,6})(\.[0-9]{1,2})?$').hasMatch(value)) {
      return null;
    }
    final parts = value.split('.');
    final n =
        int.parse(parts[0]) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
    return n > 0 && n <= 100000000 ? n : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    sessionChanges = SecureSessionStore.changes.stream.listen((_) {
      invalidate();
    });
  }

  void invalidate() {
    epoch++;
    timer?.cancel();
    timer = null;
    age.stop();
    if (mounted) {
      setState(() {
        code = null;
        expires = null;
        consent = false;
        busy = false;
        failed = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    invalidate();
  }

  @override
  void didUpdateWidget(covariant MemberPaymentCodePage old) {
    super.didUpdateWidget(old);
    if (old.storeRef != widget.storeRef ||
        old.accountType != widget.accountType) {
      invalidate();
    }
  }

  @override
  void dispose() {
    epoch++;
    timer?.cancel();
    age.stop();
    sessionChanges?.cancel();
    amount.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool stillValid() =>
      code != null &&
      expires != null &&
      expires!.isAfter(DateTime.now().toUtc()) &&
      age.elapsed < const Duration(seconds: 60);
  Future<void> issue() async {
    final total = cents;
    if (!foreground || busy || !consent || !validScope || total == null) return;
    FocusScope.of(context).unfocus();
    final request = ++epoch, generation = MemberQrMemory.generation;
    bool current() =>
        mounted &&
        foreground &&
        epoch == request &&
        MemberQrMemory.generation == generation;
    timer?.cancel();
    age
      ..reset()
      ..start();
    setState(() {
      busy = true;
      failed = false;
      code = null;
      expires = null;
    });
    try {
      final params = <String, dynamic>{
        'storeRef': widget.storeRef,
        'accountType': widget.accountType,
        'maxTotalCents': total,
        'paymentConsent': true,
      };
      final result =
          await (widget.issue?.call(params) ??
              MemberPaymentCodeRepository().issue(
                params,
                stillCurrent: current,
              ));
      if (!current()) return;
      final token = result['paymentCode'],
          expiry = result['expiresAt'],
          grant = result['grantRef'];
      if (result['storeRef'] != widget.storeRef ||
          result['accountType'] != widget.accountType ||
          result['currency'] != 'CNY' ||
          result['maxTotalCents'] != total ||
          grant is! String ||
          !RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
          ).hasMatch(grant) ||
          token is! String ||
          !RegExp(r'^KCPAY1:[A-Za-z0-9_-]{43}$').hasMatch(token) ||
          expiry is! String ||
          !expiry.endsWith('Z')) {
        throw const FormatException('Invalid payment authorization');
      }
      final encoded = token.substring(7);
      if (base64Url
              .encode(base64Url.decode(base64Url.normalize(encoded)))
              .replaceAll('=', '') !=
          encoded) {
        throw const FormatException('Invalid payment authorization');
      }
      final until = DateTime.parse(expiry);
      if (!until.isAfter(DateTime.now().toUtc()) ||
          age.elapsed >= const Duration(seconds: 60)) {
        throw const FormatException('Expired payment authorization');
      }
      setState(() {
        code = token;
        expires = until;
        consent = false;
      });
      timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!current() || !stillValid()) {
          invalidate();
        }
      });
    } catch (_) {
      if (current()) {
        setState(() {
          failed = true;
          consent = false;
        });
      }
    } finally {
      if (current()) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = foreground && stillValid();
    return Scaffold(
      appBar: kingAppBar(context: context, title: Text(t('paymentTitle'))),
      body: !foreground
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  widget.storeName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  t(
                    widget.accountType == 'platform_cash'
                        ? 'platform'
                        : 'storeAccount',
                  ),
                ),
                const SizedBox(height: 16),
                Text(t('paymentNotice')),
                TextField(
                  controller: amount,
                  enabled: !busy && !visible,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  maxLength: 10,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: t('paymentLimit'),
                    suffixText: 'CNY',
                  ),
                  onChanged: (_) {
                    invalidate();
                  },
                ),
                if (visible) ...[
                  Text(
                    '${t('paymentLimit')}: CNY ${balanceMoney(BigInt.from(cents!))}',
                  ),
                  Center(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: QrImageView(
                        data: code!,
                        size: 240,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  Text(t('paymentExpiry')),
                  TextButton(onPressed: invalidate, child: Text(t('hideCode'))),
                ] else ...[
                  CheckboxListTile(
                    value: consent,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => consent = v == true),
                    title: Text(t('paymentConsent')),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (failed) Text(t('paymentFailed')),
                  FilledButton(
                    onPressed: !busy && consent && cents != null && validScope
                        ? issue
                        : null,
                    child: Text(t(busy ? 'issuing' : 'issueCode')),
                  ),
                ],
              ],
            ),
    );
  }
}
