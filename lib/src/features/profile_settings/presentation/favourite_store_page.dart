import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../../../core/formatters/money.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../club/data/together_store.dart';
import '../../club/data/secure_together_store_repository.dart';
import '../../club/data/secure_together_publication.dart';
import '../../club/presentation/together_party_create_page.dart';
import '../../club/presentation/together_artwork_upload_page.dart';
import '../../club/presentation/legacy_club_components.dart';
import '../../home/presentation/home_content_cards.dart';
import '../data/profile_repository.dart';

String storeText(BuildContext context, String values) {
  final parts = values.split('|');
  return parts[{'zh-CN': 0, 'en': 1, 'zh-TW': 2, 'th': 3}[homeLocale(
        context,
      )] ??
      0];
}

class FavouriteStoreCard extends StatelessWidget {
  const FavouriteStoreCard({super.key, required this.store, this.onTap});
  final Map store;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: const Color(0xFF22201D),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 184,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (store['backgroundUrl'] is String &&
                  (store['backgroundUrl'] as String).isNotEmpty)
                CachedMediaImage(
                  store['backgroundUrl'],
                  fit: BoxFit.cover,
                  private: false,
                ),
              if ((store['backgroundUrl'] == null ||
                      store['backgroundUrl'] == '') &&
                  store['logoUrl'] is String)
                Positioned(
                  top: 4,
                  right: 12,
                  width: 150,
                  height: 110,
                  child: Opacity(
                    opacity: .28,
                    child: CachedMediaImage(
                      store['logoUrl'],
                      fit: BoxFit.contain,
                      private: false,
                    ),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x18000000), Color(0xEE000000)],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: store['logoUrl'] is String
                            ? CachedMediaImage(
                                store['logoUrl'],
                                fit: BoxFit.cover,
                                private: false,
                              )
                            : const ColoredBox(
                                color: Colors.black,
                                child: Icon(
                                  Icons.storefront,
                                  color: Colors.white70,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${store['storeName']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${store['storeAddress'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                        size: 22,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FavouriteStorePage extends StatefulWidget {
  const FavouriteStorePage({
    super.key,
    required this.store,
    required this.repository,
  });
  final Map store;
  final ProfileRepository repository;
  @override
  State<FavouriteStorePage> createState() => _FavouriteStorePageState();
}

class _FavouriteStorePageState extends State<FavouriteStorePage> {
  late Future<Map<String, dynamic>> _future = widget.repository.store(
    widget.store['storeRef'],
  );
  String? _table;
  String t(String s) => storeText(context, s);
  String localized(Map m) => '${m[homeLocale(context)] ?? m['zh-CN'] ?? ''}';
  void _reserve(Map store, List tables) {
    final selected = tables.where((e) => e['tableRef'] == _table).firstOrNull;
    final publication = SecureTogetherPublication.secure(kingclubApiBaseUrl);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (pageContext) => TogetherPartyCreatePage(
          personal: true,
          cityCode: store['cityId'],
          cityName: store['cityName'] ?? store['cityId'],
          initialStore: TogetherStore(
            ref: store['storeRef'],
            name: store['storeName'],
            cityCode: store['cityId'],
            address: store['storeAddress'] ?? '',
            personalPartyEnabled: true,
          ),
          initialTable: selected == null
              ? null
              : TogetherTable(
                  ref: selected['tableRef'],
                  storeRef: store['storeRef'],
                  name: selected['tableName'],
                  maximumSeats: (selected['maximumSeats'] as num).toInt(),
                ),
          stores: SecureTogetherStoreRepository.secure(kingclubApiBaseUrl),
          publication: publication,
          onBack: () => Navigator.of(pageContext).pop(),
          uploadArtwork: () async {
            await Navigator.of(pageContext).push(
              MaterialPageRoute(
                builder: (_) =>
                    TogetherArtworkUploadPage(repository: publication),
              ),
            );
            return null;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LegacyClubScaffold(
    title: t('店铺|Store|店舖|ร้านค้า'),
    titleColor: Colors.white,
    showMockLabel: false,
    onBack: () => Navigator.pop(context),
    child: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () =>
                    _future = widget.repository.store(widget.store['storeRef']),
              ),
              child: Text(
                t(
                  '加载失败，点击重试|Could not load. Retry|載入失敗，點擊重試|โหลดไม่สำเร็จ ลองอีกครั้ง',
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!,
            store = data['store'] as Map,
            packages = data['packages'] as List,
            tables = data['tables'] as List;
        final enabled =
            store['personalPartyEnabled'] == 1 ||
            store['personalPartyEnabled'] == true;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            FavouriteStoreCard(store: store),
            const SizedBox(height: 8),
            Text(
              t('门店套餐|Store packages|門店套餐|แพ็กเกจของร้าน'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (packages.isEmpty)
              Text(
                t('暂无可选套餐|No packages available|暫無可選套餐|ยังไม่มีแพ็กเกจ'),
                style: const TextStyle(color: Colors.white54),
              ),
            for (final p in packages)
              Card(
                color: const Color(0xFF202020),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localized(p['namesJson'] as Map),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localized(p['specificationsJson'] as Map),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${store['currency']} ${moneyCents(p['priceCents'])}',
                        style: const TextStyle(
                          color: legacyGold,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              t('选择座位|Choose a table|選擇座位|เลือกโต๊ะ'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(
                '选择日期后确认可订时段|Availability is checked after choosing a date|選擇日期後確認可訂時段|ตรวจสอบเวลาว่างหลังเลือกวันที่',
              ),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final table in tables)
                  ChoiceChip(
                    label: Text(
                      '${table['tableName']} · ${table['maximumSeats']} ${t('人|guests|人|คน')}',
                    ),
                    selected: _table == table['tableRef'],
                    onSelected: enabled
                        ? (_) => setState(() => _table = table['tableRef'])
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: enabled ? () => _reserve(store, tables) : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  t(
                    '选择日期与组局方案|Choose date and party plan|選擇日期與組局方案|เลือกวันที่และแผนปาร์ตี้',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
