import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/media/cached_media_image.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../../profile_settings/data/profile_repository.dart';
import '../../membership_wallet/data/member_balance_snapshot.dart';

String _text(BuildContext context, String values) {
  final l = Localizations.localeOf(context);
  return values.split('|')[l.languageCode == 'en'
      ? 1
      : l.languageCode == 'th'
      ? 3
      : l.scriptCode == 'Hant' || ['TW', 'HK', 'MO'].contains(l.countryCode)
      ? 2
      : 0];
}

class StorageMemberCards extends StatefulWidget {
  const StorageMemberCards({super.key, required this.active, this.load});
  final bool active;
  final Future<Map<String, dynamic>> Function()? load;
  @override
  State<StorageMemberCards> createState() => _StorageMemberCardsState();
}

class _StorageMemberCardsState extends State<StorageMemberCards>
    with WidgetsBindingObserver {
  MemberBalanceSnapshot? snapshot;
  bool loading = false, failed = false;
  int epoch = 0;
  StreamSubscription<void>? session;
  StreamSubscription<Map<String, dynamic>>? events;
  Timer? expiry;
  bool queued = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = SecureSessionStore.changes.stream.listen((_) {
      epoch++;
      expiry?.cancel();
      setState(() {
        snapshot = null;
        loading = false;
        failed = false;
      });
      if (widget.active) reload();
    });
    events = KingclubRealtime.shared.events.listen((e) {
      if (widget.active &&
          ['balance.changed', 'connection.ready'].contains(e['eventType'])) {
        reload();
      }
    });
    if (widget.active) reload();
  }

  @override
  void didUpdateWidget(StorageMemberCards old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) reload();
  }

  Future<void> reload() async {
    if (loading) {
      queued = true;
      return;
    }
    final e = ++epoch;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final raw =
          await (widget.load?.call() ??
              ProfileRepository().call('K260930000508', {}));
      final value = MemberBalanceSnapshot.parse(raw);
      if (!mounted || e != epoch) return;
      expiry?.cancel();
      setState(() {
        snapshot = value;
        loading = false;
      });
      final next = value.nextGiftExpiry;
      if (next != null) {
        expiry = Timer(next.difference(value.at), () {
          if (mounted) {
            setState(() => snapshot = null);
            if (widget.active) reload();
          }
        });
      }
    } catch (_) {
      if (!mounted || e != epoch) return;
      setState(() {
        loading = false;
        failed = true;
      });
    }
    if (queued && mounted && widget.active) {
      queued = false;
      reload();
    }
  }

  @override
  void dispose() {
    epoch++;
    session?.cancel();
    events?.cancel();
    expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String v) => _text(context, v);
    if (snapshot == null) {
      return Center(
        child: loading
            ? const CircularProgressIndicator()
            : TextButton(
                onPressed: reload,
                child: Text(
                  t(
                    '卡片暂时无法读取，点击重试|Unable to load cards. Retry|卡片暫時無法讀取，點擊重試|โหลดบัตรไม่ได้ แตะเพื่อลองใหม่',
                  ),
                ),
              ),
      );
    }
    if (snapshot!.stores.isEmpty) {
      return Center(
        child: Text(
          t(
            '暂无门店会员卡或储值卡|No store membership or stored-value cards yet|暫無門店會員卡或儲值卡|ยังไม่มีบัตรสมาชิกหรือบัตรเติมเงินของร้าน',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          if (failed)
            TextButton(
              onPressed: reload,
              child: Text(
                t(
                  '余额更新失败，点击重试|Balance refresh failed. Retry|餘額更新失敗，點擊重試|อัปเดตยอดไม่สำเร็จ แตะเพื่อลองใหม่',
                ),
              ),
            ),
          for (final store in snapshot!.stores)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: InkWell(
                key: ValueKey('storage-card-${store.ref}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _CardDetail(store: store),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CardFace(store: store),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              store.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                      child: Text(
                        '${t('本店储值卡|Store credit|本店儲值卡|บัตรเติมเงินร้าน')}  ·  ${balanceMoney(store.principal + store.gift)}',
                        style: const TextStyle(
                          color: Color(0xFFC9B69E),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.store});
  final MemberStoreBalance store;
  @override
  Widget build(BuildContext context) {
    final king = store.name.toUpperCase().startsWith('KINGCLUB');
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 680 / 337,
        child: king
            ? Image.asset(
                'assets/legacy/storage/store_vip_card.webp',
                fit: BoxFit.cover,
              )
            : Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF38342D), Color(0xFF101010)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (store.logoUrl != null)
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CachedMediaImage(
                          store.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.storefront,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        store.name,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _text(context, '会员卡|Membership card|會員卡|บัตรสมาชิก'),
                      style: const TextStyle(
                        color: Color(0xFFC9B69E),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.store});
  final MemberStoreBalance store;
  @override
  Widget build(BuildContext context) {
    String t(String v) => _text(context, v);
    Widget row(String title, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 17),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: kingAppBar(
        context: context,
        title: Text(t('门店会员卡|Store membership card|門店會員卡|บัตรสมาชิกร้าน')),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CardFace(store: store),
          const SizedBox(height: 20),
          Text(
            store.name,
            style: const TextStyle(color: Colors.white, fontSize: 21),
          ),
          row(
            t('本金余额|Principal balance|本金餘額|ยอดเงินต้น'),
            balanceMoney(store.principal),
          ),
          row(t('赠送余额|Bonus balance|贈送餘額|ยอดโบนัส'), balanceMoney(store.gift)),
          row(
            t('合计余额|Total balance|合計餘額|ยอดรวม'),
            balanceMoney(store.principal + store.gift),
          ),
          if (store.accountStatus != 'active' || store.status != 'active')
            Text(
              t(
                '卡片当前不可支付|Card currently unavailable for payment|卡片目前不可支付|บัตรยังใช้ชำระเงินไม่ได้',
              ),
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          const Divider(color: Colors.white24),
          Text(
            t(
              '仅限本店使用，支付时以订单可抵扣金额为准|For this store only. Eligible amounts are calculated at checkout.|僅限本店使用，支付時以訂單可抵扣金額為準|ใช้ได้เฉพาะร้านนี้ ยอดที่ใช้ได้คำนวณเมื่อชำระเงิน',
            ),
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          for (final rules
              in store.lots
                  .map((l) => l.rules)
                  .where((s) => s.isNotEmpty)
                  .toSet())
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                rules,
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
