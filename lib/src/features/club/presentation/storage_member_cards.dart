import 'dart:async';

import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design_system/king_result_page.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../profile_settings/data/profile_repository.dart';
import '../../membership_wallet/data/store_debit_watch.dart';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/media/cached_media_image.dart';
import '../../membership_wallet/data/member_balance_snapshot.dart';
import '../data/storage_repository.dart';

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

class StoreCardItem extends StorageItem {
  StoreCardItem(this.balance)
    : super(
        ref: 'card-${balance.ref}',
        name: balance.name,
        assetKey: 'store-card',
        category: 'card',
        canPickup: false,
      );
  final MemberStoreBalance balance;
  @override
  String get storageCategory => 'card';
}

class StoreCardFace extends StatelessWidget {
  const StoreCardFace({super.key, required this.store});
  final MemberStoreBalance store;
  @override
  Widget build(BuildContext context) {
    final king = store.name.toUpperCase().startsWith('KINGCLUB');
    return AspectRatio(
      aspectRatio: 564 / 333,
      child: king
          ? Image.asset(
              'assets/legacy/storage/store_vip_card.webp',
              fit: BoxFit.contain,
            )
          : FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 340,
                height: 201,
                child: Container(
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
            ),
    );
  }
}

class StoreCardDetail extends StatefulWidget {
  const StoreCardDetail({
    super.key,
    required this.store,
    this.repository,
    this.events,
  });
  final MemberStoreBalance store;
  final ProfileRepository? repository;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<StoreCardDetail> createState() => _StoreCardDetailState();
}

class _StoreCardDetailState extends State<StoreCardDetail>
    with WidgetsBindingObserver {
  late MemberStoreBalance store = widget.store;
  late final repo = widget.repository ?? ProfileRepository();
  StoreDebitWatch? watch;
  Timer? timer;
  StreamSubscription<void>? sessionChanges;
  bool sessionExpired = false;
  String? code, error;
  final age = Stopwatch();
  int ttl = 0, epoch = 0;
  bool busy = false, foreground = true;
  StoreDebitNotice? paid;
  String t(String value) => _text(context, value);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    watch = StoreDebitWatch(
      events: widget.events,
      active: () =>
          mounted &&
          foreground &&
          paid == null &&
          (ModalRoute.of(context)?.isCurrent ?? true),
      load: () => repo.call('K260930000508', {}),
      onSnapshot: (snapshot) {
        if (!mounted || sessionExpired) return;
        final latest = snapshot.stores
            .where((s) => s.ref == store.ref)
            .firstOrNull;
        if (latest != null) setState(() => store = latest);
      },
      onPaid: (n) {
        if (!mounted || paid != null) return;
        setState(() {
          paid = n;
          code = null;
        });
      },
    );
    sessionChanges = SecureSessionStore.changes.stream.listen((_) {
      epoch++;
      busy = false;
      watch?.dispose();
      if (mounted) {
        setState(() {
          sessionExpired = true;
          code = null;
          paid = null;
        });
      }
    });
    refresh();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !foreground || paid != null) return;
      if (code != null && age.elapsed.inSeconds >= ttl - 60) refresh();
      if (code != null && age.elapsed.inSeconds >= ttl) {
        setState(() => code = null);
      }
    });
  }

  Future<void> refresh() async {
    if (busy || !foreground || paid != null || sessionExpired) return;
    busy = true;
    final request = ++epoch, generation = MemberQrMemory.generation;
    try {
      final qr = await repo.memberQr(forceRefresh: true);
      if (!mounted ||
          request != epoch ||
          generation != MemberQrMemory.generation) {
        return;
      }
      setState(() {
        code = qr['code'] as String;
        ttl = (qr['ttlSeconds'] as num).toInt();
        age.reset();
        age.start();
        error = null;
      });
    } catch (_) {
      if (mounted && request == epoch) {
        setState(
          () => error = t(
            '暂时无法刷新，请重试|Unable to refresh. Try again.|暫時無法重新整理，請重試|รีเฟรชไม่ได้ กรุณาลองอีกครั้ง',
          ),
        );
      }
    } finally {
      if (request == epoch) busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      epoch++;
      busy = false;
      setState(() => code = null);
    } else {
      refresh();
      watch?.check();
    }
  }

  @override
  void dispose() {
    epoch++;
    timer?.cancel();
    sessionChanges?.cancel();
    watch?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (paid != null) {
      void returnToCard() {
        setState(() {
          store = paid!.store;
          paid = null;
        });
        refresh();
      }

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) returnToCard();
        },
        child: KingResultPage(
          title: t('扣款成功|Payment successful|扣款成功|ชำระเงินสำเร็จ'),
          description: '${paid!.store.name}\n${balanceMoney(paid!.amount)}',
          buttonText: t('查看余额|View balance|查看餘額|ดูยอดคงเหลือ'),
          onReturn: returnToCard,
        ),
      );
    }
    if (sessionExpired) {
      return Scaffold(
        backgroundColor: const Color(0xFF111111),
        appBar: kingAppBar(context: context),
        body: Center(
          child: Text(
            t(
              '请重新打开会员卡|Please reopen your membership card|請重新開啟會員卡|โปรดเปิดบัตรสมาชิกอีกครั้ง',
            ),
          ),
        ),
      );
    }
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: kingAppBar(
        context: context,
        backgroundColor: Colors.transparent,
        title: Text(
          store.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, bounds) {
          final cardHeight = (bounds.maxHeight * .23).clamp(70.0, 160.0);
          final qrSize = (bounds.maxHeight - cardHeight - 235).clamp(
            140.0,
            230.0,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            children: [
              SizedBox(
                height: cardHeight,
                child: Center(child: StoreCardFace(store: store)),
              ),
              const SizedBox(height: 16),
              row(
                t('充值金额|Total recharged|充值金額|ยอดเติมเงินสะสม'),
                store.originalPrincipal == null
                    ? '—'
                    : balanceMoney(store.originalPrincipal!),
              ),
              row(
                t('赠送|Bonus credited|贈送|โบนัสที่ได้รับ'),
                store.originalGift == null
                    ? '—'
                    : balanceMoney(store.originalGift!),
              ),
              row(
                t('剩余余额|Remaining balance|剩餘餘額|ยอดคงเหลือ'),
                balanceMoney(store.principal + store.gift),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: qrSize,
                  height: qrSize,
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: code == null
                      ? Center(
                          child: TextButton(
                            onPressed: refresh,
                            child: Text(
                              t(
                                '刷新会员码|Refresh member code|重新整理會員碼|รีเฟรชรหัสสมาชิก',
                              ),
                            ),
                          ),
                        )
                      : QrImageView(
                          data: code!,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                t(
                  '请向店员出示会员码|Show your member code to staff|請向店員出示會員碼|แสดงรหัสสมาชิกแก่พนักงาน',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (error != null)
                TextButton(onPressed: refresh, child: Text(error!)),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                t('使用说明|How to use|使用說明|วิธีใช้'),
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
              const SizedBox(height: 10),
              Text(
                t(
                  '仅限本店使用。本金与赠送金额按充值规则抵扣，剩余余额不含已过期赠送金额。|Valid at this store only. Principal and bonus follow the recharge terms. Expired bonus is excluded from the remaining balance.|僅限本店使用。本金與贈送金額按充值規則抵扣，剩餘餘額不含已過期贈送金額。|ใช้ได้เฉพาะร้านนี้ เงินต้นและโบนัสใช้ตามเงื่อนไขการเติมเงิน ยอดคงเหลือไม่รวมโบนัสที่หมดอายุ',
                ),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              for (final rule
                  in store.lots
                      .map((l) => l.rules)
                      .where((r) => r.isNotEmpty)
                      .toSet())
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    rule,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              if (store.accountStatus != 'active' || store.status != 'active')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    t(
                      '卡片当前不可支付|Card unavailable for payment|卡片目前不可支付|บัตรยังใช้ชำระเงินไม่ได้',
                    ),
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                t(
                  '使用规则以本店充值时公示的条款为准；如有疑问，请联系门店。|The terms shown by this store at recharge apply. Contact the store with questions.|使用規則以本店充值時公示的條款為準；如有疑問，請聯絡門店。|เป็นไปตามเงื่อนไขของร้านที่แจ้งเมื่อเติมเงิน หากมีคำถามโปรดติดต่อร้าน',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
