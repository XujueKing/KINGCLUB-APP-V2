import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';

class PartnerPolicyPage extends StatefulWidget {
  const PartnerPolicyPage({
    super.key,
    required this.call,
    required this.storeRef,
  });
  final PartnerCall call;
  final String storeRef;
  @override
  State<PartnerPolicyPage> createState() => _PartnerPolicyState();
}

class _PartnerPolicyState extends State<PartnerPolicyPage> {
  bool busy = false,
      failed = false,
      loaded = false,
      invalid = false,
      saved = false;
  int? rate;
  String? revision;
  Map<String, dynamic>? pending;
  StreamSubscription<void>? session;
  String t(String key) => partnerText(context, key);
  List<int> get rates =>
      {for (int n = 20; n <= 40; n++) n * 100, ?rate}.toList()..sort();
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) {
        setState(() {
          invalid = true;
          rate = null;
        });
      }
    });
    request();
  }

  @override
  void dispose() {
    session?.cancel();
    super.dispose();
  }

  Future<void> request() async {
    if (busy || invalid) return;
    final write = pending != null;
    setState(() {
      busy = true;
      failed = false;
      saved = false;
    });
    try {
      final result = await widget.call(
        pending ?? {'action': 'commission_policy', 'storeRef': widget.storeRef},
      );
      if (!mounted || invalid) return;
      final policy = result['policy'] as Map?;
      setState(() {
        revision = policy?['ref'] as String?;
        rate = (policy?['platformBps'] as num?)?.toInt();
        loaded = true;
        pending = null;
        saved = write;
      });
    } catch (e) {
      if (!mounted || invalid) return;
      setState(() {
        failed = true;
        if (e is AuthFailure && e.code.startsWith('PARTNER_')) {
          pending = null;
          loaded = false;
        }
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void save() {
    if (rate == null || pending != null || busy || !loaded) return;
    pending = {
      'action': 'commission_policy_set',
      'storeRef': widget.storeRef,
      'requestId': const Uuid().v4(),
      'expectedRef': revision,
      'platformBps': rate,
    };
    request();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      centerTitle: true,
      title: Text(
        t('commissionPolicy'),
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: Colors.white),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (invalid)
            Text(t('sessionChanged'))
          else ...[
            Text(
              t('policyExplanation'),
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (loaded)
              DropdownButtonFormField<int>(
                initialValue: rate,
                decoration: InputDecoration(labelText: t('platformRate')),
                items: rates
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text('${v / 100}%'),
                      ),
                    )
                    .toList(),
                onChanged: busy || pending != null
                    ? null
                    : (v) => setState(() {
                        rate = v;
                        saved = false;
                      }),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (failed) ...[
              const SizedBox(height: 16),
              Text(t('taskError')),
              TextButton(
                onPressed: busy ? null : request,
                child: Text(t('retry')),
              ),
            ],
            if (saved)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(t('policySaved')),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: busy || pending != null || rate == null || !loaded
                    ? null
                    : save,
                child: Text(
                  t('savePolicy'),
                  style: TextStyle(
                    fontFamily: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.fontFamily,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
