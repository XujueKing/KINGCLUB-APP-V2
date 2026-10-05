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

class StoreCardDetail extends StatelessWidget {
  const StoreCardDetail({super.key, required this.store});
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
          StoreCardFace(store: store),
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
