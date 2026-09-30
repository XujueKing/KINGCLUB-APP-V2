import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/member_balance_snapshot.dart';
import '../data/member_recharge_catalog.dart';
import '../data/member_recharge_flow.dart';
import '../data/member_recharge_journal.dart';
import 'member_balance_strings.dart';

/// Handoff QR contains only the original UUID, never a debit authorization.
class MemberRechargePage extends StatefulWidget {
  const MemberRechargePage({super.key, required this.storeRef, this.flow});
  final String storeRef;
  final MemberRechargeFlow? flow;
  @override
  State<MemberRechargePage> createState() => _MemberRechargePageState();
}

class _MemberRechargePageState extends State<MemberRechargePage>
    with WidgetsBindingObserver {
  late final defaultFlow = MemberRechargeFlow();
  MemberRechargeFlow get flow => widget.flow ?? defaultFlow;
  StreamSubscription<void>? sessions;
  Timer? expiry;
  MemberRechargeCatalog? catalog;
  MemberRechargeOffer? selected;
  MemberRechargeRequest? pending;
  String? account, handoff, status;
  String channel = 'wechat';
  bool busy = false, failed = false, consent = false, foreground = true;
  int epoch = 0;
  String t(String key) => memberBalanceText(context, key);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    sessions = SecureSessionStore.changes.stream.listen((_) {
      invalidate();
    });
    if (foreground) unawaited(load());
  }

  void invalidate() {
    epoch++;
    expiry?.cancel();
    if (mounted) {
      setState(() {
        catalog = null;
        selected = null;
        pending = null;
        account = null;
        handoff = null;
        status = null;
        consent = false;
        failed = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant MemberRechargePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storeRef != widget.storeRef ||
        oldWidget.flow != widget.flow) {
      invalidate();
      if (foreground && !busy) unawaited(load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    invalidate();
  }

  @override
  void dispose() {
    epoch++;
    expiry?.cancel();
    sessions?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> load() async {
    if (busy || !foreground) return;
    invalidate();
    final ticket = epoch, generation = MemberQrMemory.generation;
    setState(() => busy = true);
    bool current() =>
        mounted &&
        foreground &&
        ticket == epoch &&
        generation == MemberQrMemory.generation;
    try {
      final user = await flow.currentAccount();
      if (user is! String) throw StateError('SESSION_REQUIRED');
      if (!current()) return;
      final rows = await flow.journal.load(
        baseUrl: flow.baseUrl,
        userAccount: user,
      );
      if (!current()) return;
      final matches = rows.where((r) => r.storeRef == widget.storeRef).toList();
      if (matches.isNotEmpty) {
        setState(() {
          account = user;
          pending = matches.single;
        });
        return;
      }
      final started = DateTime.now();
      final value = await flow.repository.catalog(widget.storeRef);
      if (!current()) return;
      var remaining =
          const Duration(seconds: 30) - (DateTime.now().difference(started));
      for (final offer in value.offers) {
        final lifetime = offer.availableUntil.difference(
          DateTime.now().toUtc(),
        );
        if (lifetime < remaining) remaining = lifetime;
      }
      if (remaining <= Duration.zero) throw StateError('STALE_CATALOG');
      setState(() {
        account = user;
        catalog = value;
      });
      expiry = Timer(remaining, () {
        if (current()) {
          setState(() {
            catalog = null;
            selected = null;
            consent = false;
          });
        }
      });
    } catch (_) {
      if (current()) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> create() async {
    final offer = selected, user = account;
    if (busy ||
        !foreground ||
        !consent ||
        offer == null ||
        !offer.availableUntil.isAfter(DateTime.now().toUtc()) ||
        user == null ||
        catalog == null ||
        pending != null) {
      return;
    }
    final ticket = epoch, generation = MemberQrMemory.generation;
    final request = MemberRechargeRequest(
      baseUrl: flow.baseUrl,
      userAccount: user,
      storeRef: widget.storeRef,
      requestId: const Uuid().v4(),
      campaignRef: offer.ref,
      campaignRevision: offer.revision,
      channel: channel,
    );
    bool current() =>
        mounted &&
        foreground &&
        epoch == ticket &&
        generation == MemberQrMemory.generation;
    expiry?.cancel();
    setState(() {
      busy = true;
      pending = request;
      consent = false;
      failed = false;
    });
    try {
      final original = await flow.create(request, stillCurrent: current);
      if (!current()) return;
      if (original.principalCents != offer.principalCents ||
          original.giftCents != offer.giftCents) {
        throw StateError('OFFER_CHANGED');
      }
      setState(() => handoff = original.rechargeRef);
    } catch (_) {
      if (current()) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> recover() async {
    final request = pending;
    if (busy || !foreground || request == null) return;
    final ticket = epoch, generation = MemberQrMemory.generation;
    bool current() =>
        mounted &&
        foreground &&
        epoch == ticket &&
        generation == MemberQrMemory.generation;
    setState(() {
      busy = true;
      failed = false;
      handoff = null;
    });
    try {
      final result = await flow.recover(request, stillCurrent: current);
      if (!current()) return;
      setState(() {
        status = result.state;
        if (result.state == 'not_sent') handoff = result.rechargeRef;
        if (result.credited) pending = null;
      });
    } catch (_) {
      if (current()) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String money(int value) => 'CNY ${balanceMoney(BigInt.from(value))}';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: kingAppBar(context: context, title: Text(t('rechargeTitle'))),
    body: !foreground
        ? const SizedBox.shrink()
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (busy) const LinearProgressIndicator(),
              Text(t('rechargeNotice')),
              if (failed) Text(t('rechargeFailed')),
              TextButton(
                onPressed: busy ? null : load,
                child: Text(t('retry')),
              ),
              if (catalog != null &&
                  pending == null &&
                  status != 'credited') ...[
                Text(catalog!.storeName),
                if (catalog!.offers.isEmpty) Text(t('rechargeEmpty')),
                for (final offer in catalog!.offers)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t('principal')}: ${money(offer.principalCents)}',
                          ),
                          Text('${t('gift')}: ${money(offer.giftCents)}'),
                          Text(offer.description),
                          Text(t('recharge_${offer.deductionOrder}')),
                          Text(
                            '${t('rechargeGiftCap')}: ${offer.maxGiftBasisPoints ~/ 100}.${(offer.maxGiftBasisPoints % 100).toString().padLeft(2, '0')}%',
                          ),
                          Text(
                            '${t('rechargeProducts')}: ${offer.eligibleProductRefs == null
                                ? t('rechargeAllProducts')
                                : offer.eligibleProductRefs!.isEmpty
                                ? t('rechargeNoProducts')
                                : offer.eligibleProductRefs!.join(', ')}',
                          ),
                          Text(
                            '${t('rechargeOfferUntil')}: ${offer.availableUntil.toLocal().toIso8601String()}',
                          ),
                          Text('${offer.ref} / ${offer.revision}'),
                          Text(
                            '${t('expiry')}: ${offer.giftExpiresAt?.toLocal().toIso8601String() ?? t('rechargeNoExpiry')}',
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    selected = offer;
                                    consent = false;
                                  }),
                            child: Text(
                              t(
                                identical(selected, offer)
                                    ? 'rechargeSelected'
                                    : 'rechargeSelect',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                DropdownButton<String>(
                  value: channel,
                  items: [
                    DropdownMenuItem(
                      value: 'wechat',
                      child: Text(t('rechargeWechat')),
                    ),
                    DropdownMenuItem(
                      value: 'alipay',
                      child: Text(t('rechargeAlipay')),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          channel = value!;
                          consent = false;
                        }),
                ),
                CheckboxListTile(
                  value: consent,
                  onChanged: busy || selected == null
                      ? null
                      : (v) => setState(() => consent = v == true),
                  title: Text(t('rechargeConsent')),
                ),
                FilledButton(
                  onPressed: busy || !consent || selected == null
                      ? null
                      : create,
                  child: Text(t('rechargeCreate')),
                ),
              ],
              if (pending != null)
                TextButton(
                  onPressed: busy ? null : recover,
                  child: Text(t('rechargeRecover')),
                ),
              if (status != null) Text(t('recharge_$status')),
              if (handoff != null) ...[
                Text(t('rechargeHandoff')),
                Center(
                  child: ColoredBox(
                    color: Colors.white,
                    child: QrImageView(data: handoff!, size: 220),
                  ),
                ),
                SelectableText(handoff!),
              ],
            ],
          ),
  );
}
