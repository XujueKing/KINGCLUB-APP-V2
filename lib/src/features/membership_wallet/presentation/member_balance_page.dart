import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../profile_settings/data/profile_repository.dart';
import '../data/member_balance_snapshot.dart';
import 'member_balance_strings.dart';
import 'member_payment_code_page.dart';
import 'member_recharge_page.dart';

class MemberBalancePage extends StatefulWidget {
  const MemberBalancePage({super.key, this.load, this.onBack, this.events});
  final VoidCallback? onBack;
  final Future<Map<String, dynamic>> Function()? load;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<MemberBalancePage> createState() => _MemberBalancePageState();
}

class _MemberBalancePageState extends State<MemberBalancePage>
    with WidgetsBindingObserver {
  MemberBalanceSnapshot? snapshot;
  bool loading = false, failed = false, foreground = true;
  int epoch = 0;
  StreamSubscription<void>? sessionChanges;
  StreamSubscription<Map<String, dynamic>>? balanceChanges;
  Timer? refreshDebounce;
  Timer? giftExpiry;
  bool refreshQueued = false;
  String t(String key) => memberBalanceText(context, key);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    sessionChanges = SecureSessionStore.changes.stream.listen((_) {
      invalidate();
      if (foreground) unawaited(reload());
    });
    balanceChanges = (widget.events ?? KingclubRealtime.shared.events).listen((
      event,
    ) {
      if (event['eventType'] != 'connection.ready' &&
          event['eventType'] != 'balance.changed') {
        return;
      }
      // Event payload is never an authoritative amount or a payment receipt.
      if (!foreground || !mounted) return;
      refreshQueued = true;
      scheduleRefresh();
    });
    if (foreground) unawaited(reload());
  }

  void invalidate() {
    epoch++;
    giftExpiry?.cancel();
    giftExpiry = null;
    refreshDebounce?.cancel();
    refreshDebounce = null;
    refreshQueued = false;
    if (mounted) {
      setState(() {
        snapshot = null;
        loading = false;
        failed = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    invalidate();
    if (foreground) unawaited(reload());
  }

  @override
  void dispose() {
    epoch++;
    sessionChanges?.cancel();
    balanceChanges?.cancel();
    giftExpiry?.cancel();
    refreshDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void scheduleRefresh() {
    if (!mounted ||
        !foreground ||
        loading ||
        !refreshQueued ||
        refreshDebounce != null) {
      return;
    }
    refreshDebounce = Timer(const Duration(milliseconds: 400), () {
      refreshDebounce = null;
      if (!mounted || !foreground || !refreshQueued) return;
      if (loading) return;
      refreshQueued = false;
      unawaited(reload());
    });
  }

  Future<void> reload() async {
    if (!mounted || !foreground) return;
    final e = ++epoch, generation = MemberQrMemory.generation;
    giftExpiry?.cancel();
    giftExpiry = null;
    final age = Stopwatch()..start();
    setState(() {
      loading = true;
      failed = false;
      snapshot = null;
    });
    bool current() =>
        mounted &&
        foreground &&
        e == epoch &&
        generation == MemberQrMemory.generation;
    try {
      final raw =
          await (widget.load?.call() ??
              ProfileRepository().call('K260930000508', {}));
      final value = MemberBalanceSnapshot.parse(raw);
      if (!current()) return;
      final expiry = value.nextGiftExpiry;
      final remaining = expiry == null
          ? null
          : expiry.difference(value.at) - age.elapsed;
      // Do not briefly present a gift that expired while this read was in
      // flight. A failed/stale response requires manual retry, not a poll loop.
      if (remaining != null && remaining <= Duration.zero) {
        throw const FormatException('Expired balance snapshot');
      }
      setState(() => snapshot = value);
      if (remaining != null) {
        giftExpiry = Timer(remaining, () {
          if (!current()) return;
          invalidate();
          unawaited(reload());
        });
      }
    } catch (_) {
      if (current()) setState(() => failed = true);
    } finally {
      age.stop();
      if (current()) {
        setState(() => loading = false);
        scheduleRefresh();
      }
    }
  }

  Widget amount(String label, BigInt cents) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [Text(label), Text('CNY ${balanceMoney(cents)}')],
    ),
  );
  Future<void> openPayment(MemberStoreBalance store, String accountType) async {
    if (!foreground || store.status != 'active') return;
    final generation = MemberQrMemory.generation;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        allowSnapshotting: false,
        builder: (_) => MemberPaymentCodePage(
          storeRef: store.ref,
          storeName: store.name,
          accountType: accountType,
        ),
      ),
    );
    if (mounted && foreground && generation == MemberQrMemory.generation) {
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    return Scaffold(
      appBar: kingAppBar(
        context: context,
        title: Text(t('title')),
        leading: widget.onBack == null
            ? null
            : KingBackButton(onPressed: widget.onBack!),
        actions: [
          IconButton(
            onPressed: loading || !foreground
                ? null
                : () => unawaited(reload()),
            tooltip: t('retry'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !foreground
          ? const SizedBox.shrink()
          : loading
          ? const Center(child: CircularProgressIndicator())
          : failed || data == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t('failed')),
                    TextButton(
                      onPressed: () => unawaited(reload()),
                      child: Text(t('retry')),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  amount(t('total'), data.total),
                  Text(t('notice')),
                  const Divider(),
                  amount(t('platform'), data.platformCash),
                  if (data.stores.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(t('empty')),
                    ),
                  for (final store in data.stores)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              store.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (store.status != 'active' ||
                                store.accountStatus != 'active')
                              Text(t('restricted')),
                            amount(t('principal'), store.principal),
                            amount(t('gift'), store.gift),
                            if (store.status == 'active' &&
                                store.accountStatus == 'active' &&
                                const bool.fromEnvironment(
                                  'KINGCLUB_STORE_RECHARGE',
                                ))
                              TextButton(
                                onPressed: () async {
                                  final generation = MemberQrMemory.generation;
                                  await Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      allowSnapshotting: false,
                                      builder: (_) => MemberRechargePage(
                                        storeRef: store.ref,
                                      ),
                                    ),
                                  );
                                  if (mounted &&
                                      foreground &&
                                      generation == MemberQrMemory.generation) {
                                    await reload();
                                  }
                                },
                                child: Text(t('rechargeTitle')),
                              ),
                            if (store.status == 'active' &&
                                const bool.fromEnvironment(
                                  'KINGCLUB_MEMBER_PAYMENT',
                                )) ...[
                              TextButton(
                                onPressed: () =>
                                    openPayment(store, 'platform_cash'),
                                child: Text(t('payPlatform')),
                              ),
                              if (store.accountStatus == 'active')
                                TextButton(
                                  onPressed: () =>
                                      openPayment(store, 'store_balance'),
                                  child: Text(t('payStore')),
                                ),
                            ],
                            if (store.expiredGift > BigInt.zero)
                              amount(t('expired'), store.expiredGift),
                            for (final lot in store.lots)
                              ExpansionTile(
                                title: Text(
                                  lot.rules.isEmpty
                                      ? t('rulesMissing')
                                      : lot.rules,
                                ),
                                children: [
                                  amount(t('principal'), lot.principal),
                                  amount(
                                    t(lot.expired ? 'expired' : 'gift'),
                                    lot.gift,
                                  ),
                                  if (lot.expires != null)
                                    Text(
                                      '${t('expiry')}: ${MaterialLocalizations.of(context).formatMediumDate(lot.expires!.toLocal())}',
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
