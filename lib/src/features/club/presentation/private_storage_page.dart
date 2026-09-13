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
      (kingclubApiBaseUrl.isEmpty
          ? PreviewStorageRepository()
          : RealStorageRepository());
  final _pages = PageController();
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
    for (final category in ['wine', 'item']) {
      final items = _items
          .where((i) => i.category == category && i.status != 'expired')
          .toList();
      if (items.isEmpty) groups.add([]);
      for (var i = 0; i < items.length; i += 9) {
        groups.add(items.sublist(i, math.min(i + 9, items.length)));
      }
    }
    return groups;
  }

  int get _itemPage => math.max(
    1,
    (_items.where((i) => i.category == 'wine' && i.status != 'expired').length /
            9)
        .ceil(),
  );
  String get _category => _page < _itemPage ? 'wine' : 'item';
  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
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
        _items = items;
        _page = math.min(_page, _groups.length - 1);
        _selected = _groups[_page].firstOrNull?.ref;
        _loading = false;
        _back = false;
        _flip.value = 0;
      });
      if (_pages.hasClients) _pages.jumpToPage(_page);
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        allowSnapshotting: false,
        builder: (_) =>
            RealStoragePickupPage(item: item, repository: _repository),
      ),
    );
    if (mounted) _load();
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
            final width = c.maxWidth * .84;
            final bottom = 100 * u + MediaQuery.paddingOf(context).bottom;
            final heroHeight = math.max(
              210.0,
              c.maxHeight - bottom - width - 155 * u - (58 - 60 * u),
            );
            return RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
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
                                const Flexible(
                                  child: Text(
                                    '私人储物柜',
                                    style: kingSectionTitleStyle,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Semantics(
                                  button: true,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                          const SnackBar(
                                            content: Text('商店暂未开放'),
                                          ),
                                        ),
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
                                  : _showExpiredStorage,
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
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ).copyWith(
                                    overlayColor: const WidgetStatePropertyAll(
                                      Colors.transparent,
                                    ),
                                  ),
                              child: const Text('过期储物'),
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
                    SizedBox(
                      width: width,
                      height: 48 * u,
                      child: Row(
                        children: [
                          for (final entry in [
                            ('wine', '酒', 0),
                            ('item', '物', _itemPage),
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
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 3 * u,
                                  ),
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
                      width: width,
                      height: width,
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: _groups.length,
                        onPageChanged: _changePage,
                        itemBuilder: (context, p) => GridView.builder(
                          key: ValueKey(
                            'storage-grid-${p < _itemPage ? '酒' : '物'}-${p < _itemPage ? p + 1 : p - _itemPage + 1}',
                          ),
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 9,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8 * u,
                                mainAxisSpacing: 8 * u,
                              ),
                          itemBuilder: (context, index) {
                            final item = index < _groups[p].length
                                ? _groups[p][index]
                                : null;
                            final selected =
                                item != null && item.ref == _selected;
                            return GestureDetector(
                              key: item == null
                                  ? null
                                  : ValueKey('storage-select-${item.ref}'),
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
                                    center: selected
                                        ? Alignment.center
                                        : Alignment.bottomCenter,
                                    radius: 1.1,
                                    colors: selected
                                        ? [
                                            const Color(0xFF63533F),
                                            const Color(0xFF271F15),
                                          ]
                                        : [
                                            const Color(0xFF7A6750),
                                            const Color(0xFF443626),
                                          ],
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
                                                  key: ValueKey(
                                                    'storage-level-${item.ref}',
                                                  ),
                                                  style: TextStyle(
                                                    color: const Color(
                                                      0xA6E9D8C3,
                                                    ),
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
                                              style: TextStyle(
                                                color: _gold,
                                                fontSize: 28 * u,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 20 * u),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _groups.length,
                        (i) => Container(
                          width: 15 * u,
                          height: 15 * u,
                          margin: EdgeInsets.symmetric(horizontal: 8 * u),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _page ? _gold : const Color(0x30FFFFFF),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: bottom),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  Widget _hero(double u) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 1));
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
                        child: back ? _backFace(item, u) : _frontFace(item, u),
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
          item: item,
          active: widget.active && _back,
        )
      : Column(
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
