import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;

import '../data/bottle_material_preview.dart';

import 'package:kingclub/src/core/design_system/king_notice.dart';

import 'dart:async';

import '../../../core/networking/kingclub_realtime.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system/king_theme.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../data/storage_repository.dart';
import 'storage_liquid_bottle.dart';
import 'real_storage_pickup_page.dart';

const _gold = Color(0xFFC9B69E);

class PrivateStoragePage extends StatefulWidget {
  const PrivateStoragePage({super.key, this.repository, this.active = true});
  final StorageRepository? repository;
  final bool active;
  @override
  State<PrivateStoragePage> createState() => _PrivateStoragePageState();
}

class _PrivateStoragePageState extends State<PrivateStoragePage>
    with SingleTickerProviderStateMixin {
  late final StorageRepository _repository =
      widget.repository ??
      (_materialPreviewEnabled
          ? BottleMaterialPreviewRepository()
          : kingclubApiBaseUrl.isEmpty
          ? PreviewStorageRepository()
          : RealStorageRepository());
  static final _materialPreviewEnabled =
      !kReleaseMode &&
      appFlavor == 'commerce' &&
      const bool.fromEnvironment('KINGCLUB_BOTTLE_MATERIAL_PREVIEW');
  bool get _materialPreview => _repository is BottleMaterialPreviewRepository;
  double _previewLevel = 50;
  final _pages = PageController();
  static const _categories = ['wine', 'coupon', 'item'];
  static const _labels = ['酒', '券', '物'];
  final _verticalPages = List.generate(3, (_) => PageController());
  final _verticalIndex = [0, 0, 0];
  late final _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
  );
  List<StorageItem> _items = [];
  String? _selected, _error;
  int _page = 0;
  bool _loading = false, _back = false;
  StreamSubscription<Map<String, dynamic>>? _realtime;
  StorageItem? get _item => _items.where((i) => i.ref == _selected).firstOrNull;
  List<List<StorageItem>> get _groups {
    final groups = <List<StorageItem>>[];
    for (final category in _categories) {
      final items = _items
          .where((i) => i.storageCategory == category && i.status != 'expired')
          .toList();
      if (items.isEmpty) groups.add([]);
      for (var i = 0; i < items.length; i += 9) {
        groups.add(items.sublist(i, math.min(i + 9, items.length)));
      }
    }
    return groups;
  }

  int _pageCount(int category) => math.max(
    1,
    (_items
                .where(
                  (i) =>
                      i.storageCategory == _categories[category] &&
                      i.status != 'expired',
                )
                .length /
            9)
        .ceil(),
  );
  int _startPage(int category) =>
      List.generate(category, _pageCount).fold(0, (a, b) => a + b);
  int _categoryForPage(int page) => page < _startPage(1)
      ? 0
      : page < _startPage(2)
      ? 1
      : 2;
  int get _categoryIndex => _categoryForPage(_page);
  String get _category => _categories[_categoryIndex];
  @override
  void initState() {
    super.initState();
    _load();
    if (_materialPreview) return;
    _realtime = KingclubRealtime.shared.events.listen((event) {
      if (event['eventType'] == 'connection.ready' ||
          event['eventType'] == 'storage.changed') {
        if (widget.active && !_loading) {
          _load();
        } else {
          _loaded = false;
        }
      }
    });
  }

  @override
  void didUpdateWidget(PrivateStoragePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !_loaded) _load();
  }

  @override
  void dispose() {
    _realtime?.cancel();
    _pages.dispose();
    for (final controller in _verticalPages) {
      controller.dispose();
    }
    _flip.dispose();
    super.dispose();
  }

  bool _loaded = false;

  Future<void> _load() async {
    _loaded = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.list();
      if (!mounted) return;
      setState(() {
        final category = _categoryIndex;
        _items = items;
        for (var i = 0; i < 3; i++) {
          _verticalIndex[i] = math.min(_verticalIndex[i], _pageCount(i) - 1);
        }
        _page = _startPage(category) + _verticalIndex[category];
        _selected = _groups[_page].firstOrNull?.ref;
        _loading = false;
        _back = false;
        _flip.value = 0;
      });
      if (_pages.hasClients) _pages.jumpToPage(_categoryIndex);
      for (var i = 0; i < 3; i++) {
        if (_verticalPages[i].hasClients) {
          _verticalPages[i].jumpToPage(_verticalIndex[i]);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '储物柜暂时无法加载，请重试';
        });
      }
    }
  }

  void _changePage(int value) {
    setState(() {
      _page = value;
      _selected = _groups[value].firstOrNull?.ref;
      _back = false;
      _flip.value = 0;
    });
  }

  void _showShopNotice() => KingNotice.of(context).show('商店暂未开放');

  void _select(StorageItem item) {
    setState(() {
      _selected = item.ref;
      _back = false;
      _flip.value = 0;
    });
  }

  void _turn() {
    if (_item == null) return;
    _back = !_back;
    if (MediaQuery.disableAnimationsOf(context)) {
      _flip.value = _back ? 1 : 0;
    } else {
      _flip.animateTo(_back ? 1 : 0, curve: Curves.easeInOutCubic);
    }
  }

  Future<void> _pickup() async {
    final item = _item;
    if (item == null) return;
    if (_materialPreview) {
      KingNotice.of(context).show('素材测试不签发取酒码');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        allowSnapshotting: false,
        builder: (_) =>
            RealStoragePickupPage(item: item, repository: _repository),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _adjustPreviewLevel() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF211C14),
      builder: (context) => StatefulBuilder(
        builder: (context, updateSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_item?.name ?? ''} · ${_previewLevel.round()}%',
                  style: const TextStyle(color: _gold),
                ),
                Slider(
                  value: _previewLevel,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (value) {
                    setState(() {
                      _previewLevel = value;
                      _back = true;
                      _flip.value = 1;
                    });
                    updateSheet(() {});
                  },
                ),
                const Text(
                  '仅调节展示比例，不改变实际存酒余量',
                  style: TextStyle(color: _gold, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showExpiredStorage() async {
    final expired = _items.where((item) => item.status == 'expired').toList();
    final selected = await showModalBottomSheet<StorageItem>(
      context: context,
      backgroundColor: const Color(0xFF1C1812),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: Column(
            children: [
              const Text('过期储物', style: KingTheme.headerTitleStyle),
              const SizedBox(height: 16),
              Expanded(
                child: expired.isEmpty
                    ? const Center(
                        child: Text('暂无过期储物', style: TextStyle(color: _gold)),
                      )
                    : ListView.builder(
                        itemCount: expired.length,
                        itemBuilder: (context, index) {
                          final item = expired[index];
                          return ListTile(
                            key: ValueKey('expired-item-${item.ref}'),
                            leading: Image.asset(
                              item.thumbnail,
                              width: 44,
                              height: 60,
                              fit: BoxFit.contain,
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '数量：${item.quantity}${item.category == 'wine' ? '   剩余：${item.remainingPercent.toStringAsFixed(0)}%' : ''}\n过期时间：${item.expiresLabel}',
                              style: const TextStyle(
                                color: Color(0x99C9B69E),
                                fontSize: 11,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: _gold,
                              size: 18,
                            ),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        allowSnapshotting: false,
        builder: (_) =>
            RealStoragePickupPage(item: selected, repository: _repository),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.5),
          radius: 0.85,
          colors: [Color(0xFF2A261E), Colors.black],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final u = c.maxWidth / 750;
            final width = math.min(
              c.maxWidth * .84,
              math.max(
                0.0,
                (c.maxHeight -
                        58 -
                        100 * u -
                        MediaQuery.paddingOf(context).bottom -
                        95 * u) *
                    .64,
              ),
            );
            final bottom = 100 * u + MediaQuery.paddingOf(context).bottom;
            final heroHeight = math.max(
              0.0,
              c.maxHeight - bottom - width - 58 - 95 * u,
            );
            return Column(
              children: [
                SizedBox(
                  height: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 18,
                        top: 10,
                        right: 82,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                _materialPreview ? '储物袋 · 素材测试' : '储物袋',
                                style: kingSectionTitleStyle,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Semantics(
                              button: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _showShopNotice,
                                child: const Padding(
                                  padding: EdgeInsets.only(bottom: 14),
                                  child: Text(
                                    '商店',
                                    style: TextStyle(
                                      color: Color(0x80C9B69E),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 18,
                        top: 0,
                        bottom: 0,
                        child: TextButton(
                          key: const ValueKey('storage-expired-items'),
                          onPressed: _loading || _error != null
                              ? null
                              : (_materialPreview
                                    ? _adjustPreviewLevel
                                    : _showExpiredStorage),
                          style:
                              TextButton.styleFrom(
                                foregroundColor: const Color(0xB3C9B69E),
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ).copyWith(
                                overlayColor: const WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                              ),
                          child: Text(_materialPreview ? '测试余量' : '过期储物'),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: heroHeight,
                  child: Padding(
                    padding: EdgeInsets.only(top: 48 * u),
                    child: _hero(u),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: width,
                  height: 48 * u,
                  child: Row(
                    children: [
                      for (final entry in [
                        ('wine', '酒', 0),
                        ('coupon', '券', 1),
                        ('item', '物', 2),
                      ])
                        Semantics(
                          key: ValueKey(
                            'storage-tab-${entry.$2}-${_category == entry.$1 ? 'selected' : 'idle'}',
                          ),
                          button: true,
                          selected: _category == entry.$1,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _pages.animateToPage(
                              entry.$3,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                            ),
                            child: Container(
                              margin: EdgeInsets.only(right: 20 * u),
                              padding: EdgeInsets.symmetric(horizontal: 3 * u),
                              decoration: BoxDecoration(
                                border: _category == entry.$1
                                    ? const Border(
                                        bottom: BorderSide(color: _gold),
                                      )
                                    : null,
                              ),
                              child: Text(
                                entry.$2,
                                style: TextStyle(
                                  fontSize: 30 * u,
                                  color: _category == entry.$1
                                      ? _gold
                                      : const Color(0x665E5548),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 12 * u),
                SizedBox(
                  height: width,
                  child: Stack(
                    children: [
                      Center(
                        child: SizedBox(
                          width: width,
                          child: PageView.builder(
                            key: const ValueKey('storage-category-pages'),
                            controller: _pages,
                            itemCount: 3,
                            onPageChanged: (category) => _changePage(
                              _startPage(category) + _verticalIndex[category],
                            ),
                            itemBuilder: (context, category) =>
                                PageView.builder(
                                  key: PageStorageKey(
                                    'storage-vertical-$category',
                                  ),
                                  controller: _verticalPages[category],
                                  scrollDirection: Axis.vertical,
                                  itemCount: _pageCount(category),
                                  onPageChanged: (index) {
                                    _verticalIndex[category] = index;
                                    _changePage(_startPage(category) + index);
                                  },
                                  itemBuilder: (context, index) =>
                                      _grid(_startPage(category) + index, u),
                                ),
                          ),
                        ),
                      ),
                      if (_pageCount(_categoryIndex) > 1)
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Column(
                              key: const ValueKey('storage-vertical-dots'),
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                _pageCount(_categoryIndex),
                                (i) => Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == _verticalIndex[_categoryIndex]
                                        ? _gold
                                        : const Color(0x30FFFFFF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 20 * u),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Container(
                      width: 15 * u,
                      height: 15 * u,
                      margin: EdgeInsets.symmetric(horizontal: 8 * u),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _categoryIndex
                            ? _gold
                            : const Color(0x30FFFFFF),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: math.max(0.0, bottom - 24)),
              ],
            );
          },
        ),
      ),
    ),
  );
  Widget _grid(int p, double u) => GridView.builder(
    key: ValueKey(
      'storage-grid-${_labels[_categoryForPage(p)]}-${p - _startPage(_categoryForPage(p)) + 1}',
    ),
    padding: EdgeInsets.zero,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 9,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 8 * u,
      mainAxisSpacing: 8 * u,
    ),
    itemBuilder: (context, index) {
      final item = index < _groups[p].length ? _groups[p][index] : null;
      final selected = item != null && item.ref == _selected;
      return GestureDetector(
        key: item == null ? null : ValueKey('storage-select-${item.ref}'),
        onTap: item == null ? null : () => _select(item),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xFFE9D8C3)
                  : const Color(0x55C9B69E),
              width: 1,
            ),
            gradient: RadialGradient(
              center: selected ? Alignment.center : Alignment.bottomCenter,
              radius: 1.1,
              colors: selected
                  ? [const Color(0xFF63533F), const Color(0xFF271F15)]
                  : [const Color(0xFF7A6750), const Color(0xFF443626)],
            ),
          ),
          child: item == null
              ? null
              : Stack(
                  children: [
                    Center(
                      child: Image.asset(
                        item.thumbnail,
                        width: 160 * u,
                        height: 160 * u,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (item.category == 'wine')
                      Positioned(
                        right: 12 * u,
                        bottom: 10 * u,
                        child: IgnorePointer(
                          child: Text(
                            '${item.remainingPercent.toStringAsFixed(0)}%',
                            key: ValueKey('storage-level-${item.ref}'),
                            style: TextStyle(
                              color: const Color(0xA6E9D8C3),
                              fontSize: 8,
                              fontWeight: FontWeight.w400,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 24 * u,
                      top: 16 * u,
                      child: Text(
                        '${item.quantity}',
                        style: TextStyle(color: _gold, fontSize: 28 * u),
                      ),
                    ),
                  ],
                ),
        ),
      );
    },
  );

  Widget _hero(double u) {
    if (_loading && _item == null) {
      return const SizedBox.shrink();
    }
    if (_error != null) {
      return Center(
        child: TextButton(onPressed: _load, child: Text(_error!)),
      );
    }
    final item = _item;
    if (item == null) {
      return Center(
        child: GestureDetector(
          key: const ValueKey('storage-empty-info'),
          behavior: HitTestBehavior.opaque,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('当前没有可展示的存酒或物品'),
              ),
            ),
          ),
          child: Image.asset(
            'assets/legacy/storage/fail.png',
            width: 58,
            height: 58,
          ),
        ),
      );
    }
    return Center(
      child: SizedBox(
        width: 610 * u,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              key: const ValueKey('storage-flip'),
              onTap: _turn,
              child: Image.asset(
                'assets/legacy/storage/wine_flip.png',
                width: 64 * u,
                height: 64 * u,
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _turn,
                child: AnimatedBuilder(
                  animation: _flip,
                  builder: (context, _) {
                    final back = _flip.value >= .5;
                    final angle = (_flip.value - (back ? 1 : 0)) * math.pi;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, .0015)
                        ..rotateY(angle),
                      child: SizedBox(
                        height: 460 * u,
                        child: item.category == 'wine'
                            ? (back ? _backFace(item, u) : _frontFace(item, u))
                            : LayoutBuilder(
                                builder: (context, constraints) => FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: back
                                        ? _backFace(item, u)
                                        : _frontFace(item, u),
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
            GestureDetector(
              key: const ValueKey('storage-pickup'),
              onTap: _pickup,
              behavior: HitTestBehavior.opaque,
              child: Opacity(
                opacity: 1,
                child: Image.asset(
                  'assets/legacy/storage/wine_barcode.png',
                  width: 64 * u,
                  height: 64 * u,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _frontFace(StorageItem item, double u) => item.category == 'wine'
      ? Image.asset(item.image, fit: BoxFit.contain)
      : Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              item.image,
              width: 311 * u,
              height: 220 * u,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 16 * u),
            Text(
              item.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28 * u,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 18 * u),
            Text(
              item.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23 * u,
                height: 1.4,
                color: const Color(0x88FFFFFF),
              ),
            ),
          ],
        );
  Widget _backFace(StorageItem item, double u) => item.category == 'wine'
      ? StorageLiquidBottle(
          key: ValueKey(item.ref),
          item: item is BottlePreviewItem ? item.atLevel(_previewLevel) : item,
          active: widget.active && _back,
        )
      : Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28 * u,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 24 * u),
            Text(
              item.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23 * u,
                height: 1.4,
                color: const Color(0x88FFFFFF),
              ),
            ),
            SizedBox(height: 24 * u),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 18 * u,
                vertical: 8 * u,
              ),
              decoration: BoxDecoration(
                color: const Color(0x55000000),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${item.quantity}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(height: 24 * u),
            Text(
              '有效期：${item.expiresAt.isEmpty ? '长期有效' : item.expiresLabel}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22 * u,
                color: const Color(0x88FFFFFF),
              ),
            ),
            if (item.maximumValue != null)
              Text(
                '最大抵用金额：${item.maximumValue!.toStringAsFixed(0)}元',
                style: TextStyle(
                  fontSize: 22 * u,
                  color: const Color(0x88FFFFFF),
                ),
              ),
          ],
        );
}
