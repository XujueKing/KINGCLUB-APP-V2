import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../club/presentation/legacy_club_components.dart';

enum ScanOrderingScenario {
  ready,
  offline,
  soldOut,
  limitReached,
  invalidContext,
  venueClosed,
  emptyCatalog,
  catalogError,
  restoredDraft,
}

class FakeOrderingQuote {
  const FakeOrderingQuote({
    required this.itemCount,
    required this.total,
    required this.items,
  });

  final int itemCount;
  final int total;
  final List<FakeOrderingQuoteItem> items;
}

class FakeOrderingQuoteItem {
  const FakeOrderingQuoteItem({
    required this.name,
    required this.detail,
    required this.asset,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final String detail;
  final String asset;
  final int quantity;
  final int unitPrice;

  int get subtotal => quantity * unitPrice;
}

class ScanOrderingCartPage extends StatefulWidget {
  const ScanOrderingCartPage({
    super.key,
    required this.onBack,
    this.onQuoteReady,
    this.onOpenOrders,
  });

  final VoidCallback onBack;
  final ValueChanged<FakeOrderingQuote>? onQuoteReady;
  final VoidCallback? onOpenOrders;

  @override
  State<ScanOrderingCartPage> createState() => _ScanOrderingCartPageState();
}

class _ScanOrderingCartPageState extends State<ScanOrderingCartPage> {
  static const _products = <_OrderingProduct>[
    _OrderingProduct(
      id: 'hennessy-xo',
      category: '酒水',
      subcategory: '畅饮套餐',
      name: '轩尼诗XO',
      englishName: 'Hennessy XO',
      specs: '750ML',
      price: 3380,
      originalPrice: 3380,
      asset: 'assets/legacy/ordering/hennessy_xo.png',
      limit: 2,
    ),
    _OrderingProduct(
      id: 'chivas-12',
      category: '酒水',
      subcategory: '威士忌',
      name: '芝华士12年',
      englishName: 'CHIVAS REGAL 12 YEARS',
      specs: '750ML',
      price: 330,
      originalPrice: 330,
      asset: 'assets/legacy/ordering/chivas_12.png',
      limit: 3,
    ),
    _OrderingProduct(
      id: 'hennessy-vsop',
      category: '酒水',
      subcategory: '白兰地',
      name: '轩尼诗VSOP',
      englishName: 'Hennessy VSOP',
      specs: '750ML',
      price: 1240,
      originalPrice: 1240,
      asset: 'assets/legacy/ordering/hennessy_vsop.png',
      limit: 4,
    ),
    _OrderingProduct(
      id: 'absolut-vodka',
      category: '酒水',
      subcategory: '伏特加',
      name: '瑞典绝对伏特加',
      englishName: 'Absolut Vodka',
      specs: '750ML',
      price: 498,
      originalPrice: 498,
      asset: 'assets/legacy/ordering/absolut_vodka.png',
      limit: 4,
    ),
  ];

  final _searchController = TextEditingController();
  final Map<String, int> _quantities = {'hennessy-xo': 1, 'chivas-12': 1};
  ScanOrderingScenario _scenario = ScanOrderingScenario.ready;
  String _category = '酒水';
  String _subcategory = '畅饮套餐';
  bool _quoting = false;
  bool _cartPanelOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _itemCount =>
      _quantities.values.fold(0, (total, quantity) => total + quantity);

  int get _total => _products.fold(
    0,
    (total, product) => total + product.price * (_quantities[product.id] ?? 0),
  );

  bool get _canEdit => !{
    ScanOrderingScenario.offline,
    ScanOrderingScenario.invalidContext,
    ScanOrderingScenario.venueClosed,
    ScanOrderingScenario.catalogError,
    ScanOrderingScenario.emptyCatalog,
  }.contains(_scenario);

  List<_OrderingProduct> get _visibleProducts {
    if (_scenario == ScanOrderingScenario.emptyCatalog) return const [];
    final query = _searchController.text.trim().toLowerCase();
    return _products.where((product) {
      final matchesCategory = product.category == _category;
      final matchesSubcategory =
          _subcategory == '全部' || product.subcategory == _subcategory;
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.englishName.toLowerCase().contains(query) ||
          product.specs.toLowerCase().contains(query);
      final showLegacyInitialList = _category == '酒水' && _subcategory == '畅饮套餐';
      return matchesCategory &&
          (showLegacyInitialList || matchesSubcategory) &&
          matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildSearchHeader(),
                _buildStoreHeader(),
                _buildCategoryTabs(),
                ...switch (_scenarioBanner) {
                  final banner? => [banner],
                  null => const <Widget>[],
                },
                Expanded(child: _buildCatalog()),
              ],
            ),
          ),
          if (_cartPanelOpen) _buildCartOverlay(),
        ],
      ),
      bottomNavigationBar: SafeArea(top: false, child: _buildCartBar()),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 24, 8),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 48,
            child: IconButton(
              key: const ValueKey('ordering-back'),
              tooltip: '返回',
              onPressed: widget.onBack,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFFF0ECE7),
                size: 25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                key: const ValueKey('ordering-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Color(0xFFD8D3CD), fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜一搜你想要的饮品',
                  hintStyle: const TextStyle(color: Color(0xFF5D5A57)),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 21,
                    color: Color(0xFF575653),
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空搜索',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: legacyGold,
                          ),
                        ),
                  filled: true,
                  fillColor: const Color(0xFF191919),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: Color(0xFF4D443A)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreHeader() {
    return GestureDetector(
      key: const ValueKey('ordering-store-header'),
      behavior: HitTestBehavior.opaque,
      onLongPress: _showScenarioPicker,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 10, 26, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/legacy/home/logo_2.png',
                  width: 52,
                  height: 34,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'KINGBAR 湖南工大店',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFF1EEEA),
                      fontSize: 16,
                      height: 1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  'assets/legacy/ordering/table_888.svg',
                  key: ValueKey('ordering-table-888'),
                  width: 78,
                  height: 34,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerRight,
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '株洲市天元区金华路瀚水栗源1栋102',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF4B4947),
                fontSize: 12,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF312F2D), width: .7)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          ...['酒水', '饮料', '小吃'].map((label) {
            final selected = _category == label;
            return SizedBox(
              width: 80,
              child: InkWell(
                key: ValueKey('ordering-category-$label'),
                onTap: () => setState(() {
                  _category = label;
                  _subcategory = label == '酒水' ? '畅饮套餐' : '全部';
                }),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFFEAE7E3)
                            : const Color(0xFF6E6B68),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 9),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: selected ? 36 : 0,
                      height: 3,
                      color: const Color(0xFFFFB400),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget? get _scenarioBanner {
    final data = switch (_scenario) {
      ScanOrderingScenario.offline => (
        Icons.cloud_off_rounded,
        '当前离线，可查看目录，暂不能报价',
      ),
      ScanOrderingScenario.invalidContext => (
        Icons.qr_code_2_rounded,
        '桌位上下文已失效，请返回重新扫码',
      ),
      ScanOrderingScenario.venueClosed => (
        Icons.nightlife_rounded,
        '门店已停止接单，请联系现场工作人员',
      ),
      ScanOrderingScenario.catalogError => (
        Icons.sync_problem_rounded,
        '商品目录加载失败，请稍后重试',
      ),
      ScanOrderingScenario.restoredDraft => (
        Icons.restore_rounded,
        '已恢复当前桌位的本地购物草稿',
      ),
      _ => null,
    };
    if (data == null) return null;
    return Container(
      key: const ValueKey('ordering-scenario-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: const Color(0xFF33291D),
      child: Row(
        children: [
          Icon(data.$1, color: legacyGold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data.$2,
              style: const TextStyle(color: legacyGold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalog() {
    if (_scenario == ScanOrderingScenario.catalogError) {
      return _OrderingEmptyState(
        icon: Icons.sync_problem_rounded,
        title: '商品目录暂不可用',
        subtitle: '保留当前购物草稿，不会自动提交',
        action: '重新加载',
        onAction: () => setState(() => _scenario = ScanOrderingScenario.ready),
      );
    }
    final products = _visibleProducts;
    final subcategories = switch (_category) {
      '酒水' => const ['畅饮套餐', '威士忌', '白兰地', '伏特加', '香槟', '红葡萄酒', '清酒', '鸡尾酒'],
      '饮料' => const ['全部', '软饮', '果汁'],
      _ => const ['全部', '果盘', '热食'],
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 75,
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(
              right: BorderSide(color: Color(0xFF332E29), width: .7),
            ),
          ),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: subcategories.length,
            itemBuilder: (context, index) {
              final label = subcategories[index];
              final selected = _subcategory == label;
              return InkWell(
                key: ValueKey('ordering-subcategory-$label'),
                onTap: () => setState(() => _subcategory = label),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 74),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFC9B69E)
                        : Colors.transparent,
                    borderRadius: selected
                        ? const BorderRadius.horizontal(
                            right: Radius.circular(5),
                          )
                        : BorderRadius.zero,
                    border: Border(
                      bottom: BorderSide(
                        color: selected
                            ? const Color(0x33C9B69E)
                            : const Color(0xFF24211F),
                        width: .7,
                      ),
                    ),
                  ),
                  child: Text(
                    _legacyCategoryLabel(label),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF1B1510)
                          : const Color(0xFFDDD8D2),
                      fontSize: selected ? 16 : 15,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const _OrderingEmptyState(
                  icon: Icons.wine_bar_outlined,
                  title: '暂无符合的商品',
                  subtitle: '可切换分类或修改搜索词',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 5, 10, 80),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (context, index) =>
                      _buildProductCard(products[index]),
                ),
        ),
      ],
    );
  }

  String _legacyCategoryLabel(String label) {
    if (label.length == 4) {
      return '${label.substring(0, 2)}\n${label.substring(2)}';
    }
    if (label.length == 6) {
      return '${label.substring(0, 3)}\n${label.substring(3)}';
    }
    return label;
  }

  Widget _buildProductCard(_OrderingProduct product) {
    final quantity = _quantities[product.id] ?? 0;
    final soldOut =
        _scenario == ScanOrderingScenario.soldOut && product.id == 'chivas-12';
    final limitReached = quantity >= product.limit;
    return Semantics(
      container: true,
      label: '${product.name}，价格 ${product.price} 元，已选 $quantity 件',
      child: SizedBox(
        height: 176,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                product.asset,
                width: 109,
                height: 138,
                fit: BoxFit.contain,
                color: soldOut ? const Color(0x77000000) : null,
                colorBlendMode: soldOut ? BlendMode.darken : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 138,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE8DED1),
                              fontSize: 18,
                              height: 1.12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            product.englishName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFC9B69E),
                              fontSize: 16,
                              height: 1.22,
                            ),
                          ),
                          Text(
                            product.specs,
                            style: const TextStyle(
                              color: Color(0xFFC9B69E),
                              fontSize: 16,
                              height: 1.18,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: '¥ ',
                                  style: TextStyle(
                                    color: Color(0xFFC9B69E),
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: '${product.price}',
                                  style: const TextStyle(
                                    color: Color(0xFFE8E3DD),
                                    fontSize: 21,
                                    height: 1,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (soldOut)
                            const Text(
                              '已售罄',
                              key: ValueKey('ordering-sold-out'),
                              style: TextStyle(color: Color(0xFF8C8177)),
                            )
                          else
                            _QuantityControl(
                              productId: product.id,
                              quantity: quantity,
                              canDecrease: _canEdit && quantity > 0,
                              canIncrease: _canEdit && !limitReached,
                              onDecrease: () => _changeQuantity(product, -1),
                              onIncrease: () => _changeQuantity(product, 1),
                            ),
                        ],
                      ),
                      if (limitReached ||
                          (_scenario == ScanOrderingScenario.limitReached &&
                              product.id == 'hennessy-xo'))
                        Text(
                          '每桌限购 ${product.limit} 份',
                          key: const ValueKey('ordering-limit-message'),
                          style: const TextStyle(
                            color: Color(0xFFFFC96E),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartBar() {
    final enabled = _canEdit && _itemCount > 0 && !_quoting;
    return Container(
      key: const ValueKey('ordering-cart-bar'),
      height: 80,
      padding: const EdgeInsets.fromLTRB(22, 10, 18, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF181512), Color(0xFF080706)],
        ),
        border: Border(top: BorderSide(color: Color(0xFF302820))),
      ),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('ordering-cart-bag'),
            onTap: _itemCount == 0 ? null : _showCartSheet,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: _itemCount > 0 ? 1 : .4,
                  child: Image.asset(
                    'assets/legacy/ordering/shopping_bag.png',
                    width: 54,
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                ),
                if (_itemCount > 0)
                  Positioned(
                    right: -4,
                    top: 6,
                    child: Container(
                      key: const ValueKey('ordering-cart-badge'),
                      constraints: const BoxConstraints(minWidth: 25),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFB400),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$_itemCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text.rich(
              key: const ValueKey('ordering-estimate'),
              TextSpan(
                children: [
                  TextSpan(
                    text: '合计 ¥ ',
                    style: TextStyle(
                      color: _itemCount > 0
                          ? const Color(0xFF8E867E)
                          : const Color(0xFF56514C),
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: _itemCount > 0 ? _total.toStringAsFixed(0) : '0',
                    style: TextStyle(
                      color: _itemCount > 0
                          ? const Color(0xFFE1D3C1)
                          : const Color(0xFF5A554F),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: '.00',
                    style: TextStyle(
                      color: _itemCount > 0
                          ? const Color(0xFF8E867E)
                          : const Color(0xFF56514C),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 112,
            height: 50,
            child: FilledButton(
              key: const ValueKey('ordering-confirm'),
              onPressed: enabled ? _requestFakeQuote : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC9B69E),
                foregroundColor: const Color(0xFF1C150E),
                disabledBackgroundColor: const Color(0xFF332E28),
                disabledForegroundColor: const Color(0xFF756B61),
                shape: const StadiumBorder(),
              ),
              child: _quoting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      '去结算',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeQuantity(_OrderingProduct product, int delta) {
    if (!_canEdit) return;
    final current = _quantities[product.id] ?? 0;
    final next = (current + delta).clamp(0, product.limit);
    setState(() {
      if (next == 0) {
        _quantities.remove(product.id);
      } else {
        _quantities[product.id] = next;
      }
    });
    if (delta > 0 && next == current) {
      showFakeResult(context, '已达到${product.name}的单桌限购数量');
    }
  }

  Future<void> _requestFakeQuote() async {
    setState(() => _quoting = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _quoting = false);
    final quote = FakeOrderingQuote(
      itemCount: _itemCount,
      total: _total,
      items: _products
          .where((product) => (_quantities[product.id] ?? 0) > 0)
          .map(
            (product) => FakeOrderingQuoteItem(
              name: product.name,
              detail: '${product.englishName} · ${product.specs}',
              asset: product.asset,
              quantity: _quantities[product.id]!,
              unitPrice: product.price,
            ),
          )
          .toList(growable: false),
    );
    if (widget.onQuoteReady case final callback?) {
      callback(quote);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF191510),
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_rounded, color: legacyGold, size: 38),
            const SizedBox(height: 12),
            const Text(
              '报价已生成',
              style: TextStyle(
                color: Color(0xFFF3E9DC),
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${quote.itemCount} 件商品 · 预估 ¥${quote.total}',
              style: const TextStyle(color: legacyGold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '请在下一页核对商品和金额后确认。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9C9186), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCartSheet() async {
    setState(() => _cartPanelOpen = true);
  }

  Widget _buildCartOverlay() {
    final selected = _products
        .where((product) => (_quantities[product.id] ?? 0) > 0)
        .toList();
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            key: const ValueKey('ordering-cart-scrim'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _cartPanelOpen = false),
            child: Container(color: const Color(0xB3000000)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              key: const ValueKey('ordering-cart-sheet'),
              height: 470,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF94826C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        const _LegacySelectionMark(selected: true),
                        const SizedBox(width: 10),
                        Text.rich(
                          key: const ValueKey('ordering-cart-select-all'),
                          TextSpan(
                            children: [
                              const TextSpan(text: '全选'),
                              TextSpan(
                                text: '(共$_itemCount件商品)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            color: Color(0xFF211910),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          key: const ValueKey('ordering-clear-cart'),
                          onPressed: () async {
                            final clear = await _confirmClear(context);
                            if (clear != true || !mounted) return;
                            setState(() {
                              _quantities.clear();
                              _cartPanelOpen = false;
                            });
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 21,
                          ),
                          label: const Text('清空购物袋'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2C2218),
                            textStyle: const TextStyle(fontSize: 15),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF090806),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        for (var index = 0; index < selected.length; index++)
                          _buildCartPanelItem(
                            selected[index],
                            showDivider: index < selected.length - 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xAAC9B69E),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '商品总价',
                          style: TextStyle(
                            color: Color(0xFF181205),
                            fontSize: 17,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '¥ ${_total.toStringAsFixed(0)}.00',
                          style: const TextStyle(
                            color: Color(0xFF181205),
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanelItem(
    _OrderingProduct product, {
    required bool showDivider,
  }) {
    final quantity = _quantities[product.id] ?? 0;
    return Container(
      height: 112,
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: Color(0xFF2A251F), width: .8),
              )
            : null,
      ),
      child: Row(
        children: [
          const _LegacySelectionMark(selected: true),
          const SizedBox(width: 8),
          Image.asset(
            product.asset,
            width: 58,
            height: 88,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE8DED1),
                    fontSize: 16,
                    height: 1.15,
                  ),
                ),
                Text(
                  product.englishName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94826C),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                Text(
                  product.specs,
                  style: const TextStyle(
                    color: Color(0xFF94826C),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                Text(
                  '¥ ${product.price}',
                  style: const TextStyle(
                    color: Color(0xFFE2D7C8),
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          _QuantityControl(
            productId: 'sheet-${product.id}',
            quantity: quantity,
            canDecrease: _canEdit,
            canIncrease: _canEdit && quantity < product.limit,
            onDecrease: () {
              _changeQuantity(product, -1);
              if (_itemCount == 0) {
                setState(() => _cartPanelOpen = false);
              }
            },
            onIncrease: () => _changeQuantity(product, 1),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmClear(BuildContext sheetContext) {
    return showDialog<bool>(
      context: sheetContext,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1713),
        title: const Text('清空购物袋？'),
        content: const Text('只会清理当前门店和桌位的已选商品。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('ordering-clear-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  Future<void> _showScenarioPicker() async {
    final selected = await showModalBottomSheet<ScanOrderingScenario>(
      context: context,
      backgroundColor: const Color(0xFF181512),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('点单页验收场景'),
              subtitle: Text('仅用于 UI 验收，长按门店区域再次打开'),
            ),
            for (final scenario in ScanOrderingScenario.values)
              ListTile(
                leading: Icon(
                  scenario == _scenario
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: scenario == _scenario
                      ? legacyGold
                      : const Color(0xFF756B61),
                ),
                title: Text(_scenarioLabel(scenario)),
                onTap: () => Navigator.pop(context, scenario),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scenario = selected;
      if (selected == ScanOrderingScenario.restoredDraft &&
          _quantities.isEmpty) {
        _quantities['hennessy-xo'] = 1;
        _quantities['chivas-12'] = 1;
      }
      if (selected == ScanOrderingScenario.limitReached) {
        _quantities['hennessy-xo'] = 2;
      }
    });
  }

  String _scenarioLabel(ScanOrderingScenario scenario) => switch (scenario) {
    ScanOrderingScenario.ready => '正常浏览',
    ScanOrderingScenario.offline => '离线 / 不可报价',
    ScanOrderingScenario.soldOut => '局部售罄',
    ScanOrderingScenario.limitReached => '已达限购',
    ScanOrderingScenario.invalidContext => '桌位上下文失效',
    ScanOrderingScenario.venueClosed => '门店停止接单',
    ScanOrderingScenario.emptyCatalog => '空目录',
    ScanOrderingScenario.catalogError => '目录加载失败',
    ScanOrderingScenario.restoredDraft => '恢复购物草稿',
  };
}

class _LegacySelectionMark extends StatelessWidget {
  const _LegacySelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFFC9B69E) : Colors.black,
        border: Border.all(color: const Color(0xFFC9B69E), width: 1.5),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: Color(0xFF211910))
          : null,
    );
  }
}

class _OrderingProduct {
  const _OrderingProduct({
    required this.id,
    required this.category,
    required this.subcategory,
    required this.name,
    required this.englishName,
    required this.specs,
    required this.price,
    required this.originalPrice,
    required this.asset,
    required this.limit,
  });

  final String id;
  final String category;
  final String subcategory;
  final String name;
  final String englishName;
  final String specs;
  final int price;
  final int originalPrice;
  final String asset;
  final int limit;
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.productId,
    required this.quantity,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String productId;
  final int quantity;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (quantity > 0) ...[
          _RoundQuantityButton(
            key: ValueKey('ordering-remove-$productId'),
            icon: Icons.remove,
            enabled: canDecrease,
            onTap: onDecrease,
          ),
          SizedBox(
            width: 27,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE0D4C5), fontSize: 13),
            ),
          ),
        ],
        _RoundQuantityButton(
          key: ValueKey('ordering-add-$productId'),
          icon: Icons.add,
          enabled: canIncrease,
          filled: true,
          onTap: onIncrease,
        ),
      ],
    );
  }
}

class _RoundQuantityButton extends StatelessWidget {
  const _RoundQuantityButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: filled ? 25 : 23,
          height: filled ? 25 : 23,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (enabled ? const Color(0xFFFFB400) : const Color(0xFF39332D))
                : Colors.transparent,
            border: filled
                ? null
                : Border.all(
                    color: enabled
                        ? const Color(0xFFFFB400)
                        : const Color(0xFF39332D),
                  ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: filled
                ? (enabled ? Colors.black : const Color(0xFF6D655E))
                : (enabled ? const Color(0xFFFFB400) : const Color(0xFF6D655E)),
          ),
        ),
      ),
    );
  }
}

class _OrderingEmptyState extends StatelessWidget {
  const _OrderingEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF665B4E), size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: legacyGold,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF776E65), fontSize: 12),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              TextButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
