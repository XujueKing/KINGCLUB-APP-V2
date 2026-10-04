import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/together_store.dart';
import 'legacy_club_components.dart';

class TogetherStorePickerPage extends StatefulWidget {
  const TogetherStorePickerPage({
    super.key,
    required this.repository,
    required this.cityCode,
    required this.cityName,
  });
  final TogetherStoreRepository repository;
  final String cityCode, cityName;

  static Future<TogetherStore?> open(
    BuildContext context, {
    required TogetherStoreRepository repository,
    required String cityCode,
    required String cityName,
  }) => Navigator.of(context).push<TogetherStore>(
    MaterialPageRoute(
      builder: (_) => TogetherStorePickerPage(
        repository: repository,
        cityCode: cityCode,
        cityName: cityName,
      ),
    ),
  );

  @override
  State<TogetherStorePickerPage> createState() =>
      _TogetherStorePickerPageState();
}

class _TogetherStorePickerPageState extends State<TogetherStorePickerPage> {
  List<TogetherStore>? _stores;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _stores = null;
    });
    try {
      final stores = await widget.repository.list(cityCode: widget.cityCode);
      if (!mounted) return;
      setState(
        () => _stores = stores
            .where(
              (store) =>
                  store.cityCode == widget.cityCode &&
                  store.personalPartyEnabled,
            )
            .toList(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is AuthFailure ? error.message : '暂时无法加载商家',
      );
    }
  }

  @override
  Widget build(BuildContext context) => LegacyClubScaffold(
    title: '选择商家',
    titleColor: Colors.white,
    titleFontSize: 17,
    titleFontWeight: FontWeight.w600,
    headerHeight: 56,
    showMockLabel: false,
    onBack: () => Navigator.of(context).pop(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Text(
            widget.cityName,
            style: const TextStyle(color: legacyGold, fontSize: 16),
          ),
        ),
        Expanded(child: _body()),
      ],
    ),
  );

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: legacyGold)),
            TextButton(onPressed: _load, child: const Text('重新加载')),
          ],
        ),
      );
    }
    final stores = _stores;
    if (stores == null) {
      return const Center(child: CircularProgressIndicator(color: legacyGold));
    }
    if (stores.isEmpty) {
      return const Center(
        child: Text('当前城市暂无可发起组局的商家', style: TextStyle(color: legacyGold)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: stores.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _StoreCard(
        store: stores[index],
        onTap: () => Navigator.of(context).pop(stores[index]),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store, required this.onTap});
  final TogetherStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF29251F),
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('together-store-${store.ref}'),
      onTap: onTap,
      child: Stack(
        children: [
          if (store.backgroundUrl != null)
            Positioned.fill(
              child: CachedMediaImage(store.backgroundUrl!, fit: BoxFit.cover),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: .82),
                    Colors.black.withValues(alpha: .40),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: store.logoUrl == null
                        ? const ColoredBox(
                            color: Color(0xFF39342B),
                            child: Icon(
                              Icons.storefront,
                              color: legacyGold,
                              size: 30,
                            ),
                          )
                        : CachedMediaImage(store.logoUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        store.rating == null
                            ? '暂无评分'
                            : '${store.rating!.toStringAsFixed(1)} 分',
                        style: const TextStyle(color: legacyGold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        store.address.isEmpty ? '地址待完善' : store.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFDDD3C7),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 18, left: 8),
                  child: Icon(Icons.chevron_right, color: legacyGold, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
