import 'dart:async';

import 'package:flutter/material.dart';

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
      id: 'champagne',
      category: '酒水',
      subcategory: '香槟',
      name: '星光香槟',
      detail: '香槟 750ml · 含冰桶与香槟杯',
      price: 688,
      originalPrice: 788,
      asset: 'assets/legacy/ordering/product_champagne_v1.png',
      limit: 2,
    ),
    _OrderingProduct(
      id: 'whisky',
      category: '酒水',
      subcategory: '威士忌',
      name: '金标威士忌',
      detail: '威士忌 700ml · 配软饮与冰块',
      price: 498,
      originalPrice: 568,
      asset: 'assets/legacy/ordering/product_whisky_v1.png',
      limit: 3,
    ),
    _OrderingProduct(
      id: 'fruit',
      category: '小吃',
      subcategory: '果盘',
      name: '缤纷鲜果盘',
      detail: '时令鲜果 · 4–6人份',
      price: 88,
      originalPrice: 108,
      asset: 'assets/legacy/ordering/product_fruit_platter_v1.png',
      limit: 4,
    ),
  ];

  final _searchController = TextEditingController();
  final Map<String, int> _quantities = {};
  ScanOrderingScenario _scenario = ScanOrderingScenario.ready;
  String _category = '酒水';
  String _subcategory = '全部';
  bool _quoting = false;

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
          product.detail.toLowerCase().contains(query);
      return matchesCategory && matchesSubcategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
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
      bottomNavigationBar: SafeArea(top: false, child: _buildCartBar()),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('ordering-back'),
            tooltip: '返回',
            onPressed: widget.onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: legacyGold,
              size: 22,
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                key: const ValueKey('ordering-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索酒水、小吃',
                  hintStyle: const TextStyle(color: Color(0xFF81776D)),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: legacyGold,
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
                  fillColor: const Color(0xFF181512),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Color(0xFF4A4137)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Color(0xFF4A4137)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: legacyGold),
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('ordering-orders'),
            onPressed:
                widget.onOpenOrders ??
                () => showFakeResult(context, '已打开本人点单记录'),
            child: const Text('订单', style: TextStyle(color: legacyGold)),
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
        padding: const EdgeInsets.fromLTRB(20, 9, 18, 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: legacyGold),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4C402F), Color(0xFF15100A)],
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                'K',
                style: TextStyle(
                  color: legacyGold,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KINGBAR 湖南工大店',
                    style: TextStyle(
                      color: Color(0xFFE8DED1),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Color(0xFF8F8377),
                      ),
                      SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '泰山路·中心广场 2F',
                          style: TextStyle(
                            color: Color(0xFF8F8377),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2B2116),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFF655541)),
              ),
              child: const Column(
                children: [
                  Text(
                    'V8',
                    style: TextStyle(
                      color: legacyGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '桌位已验证',
                    style: TextStyle(color: Color(0xFF9D8F7E), fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF221D18)),
          bottom: BorderSide(color: Color(0xFF221D18)),
        ),
      ),
      child: Row(
        children: ['酒水', '饮料', '小吃'].map((label) {
          final selected = _category == label;
          return Expanded(
            child: InkWell(
              key: ValueKey('ordering-category-$label'),
              onTap: () => setState(() {
                _category = label;
                _subcategory = '全部';
              }),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? legacyGold : const Color(0xFF756B61),
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: selected ? 24 : 0,
                    height: 2,
                    color: legacyGold,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
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
      '酒水' => const ['全部', '香槟', '威士忌'],
      '饮料' => const ['全部', '软饮', '果汁'],
      _ => const ['全部', '果盘', '热食'],
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 82,
          color: const Color(0xFF11100E),
          child: ListView.builder(
            itemCount: subcategories.length,
            itemBuilder: (context, index) {
              final label = subcategories[index];
              final selected = _subcategory == label;
              return InkWell(
                key: ValueKey('ordering-subcategory-$label'),
                onTap: () => setState(() => _subcategory = label),
                child: Container(
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? Colors.black : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: selected ? legacyGold : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? legacyGold : const Color(0xFF7C736A),
                      fontSize: 13,
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
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: products.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 20, color: Color(0xFF211D18)),
                  itemBuilder: (context, index) =>
                      _buildProductCard(products[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(_OrderingProduct product) {
    final quantity = _quantities[product.id] ?? 0;
    final soldOut =
        _scenario == ScanOrderingScenario.soldOut && product.id == 'whisky';
    final limitReached = quantity >= product.limit;
    return Semantics(
      container: true,
      label: '${product.name}，价格 ${product.price} 元，已选 $quantity 件',
      child: SizedBox(
        height: 116,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                product.asset,
                width: 104,
                height: 104,
                fit: BoxFit.cover,
                color: soldOut ? const Color(0x77000000) : null,
                colorBlendMode: soldOut ? BlendMode.darken : null,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE8DED1),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF81776D),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '¥${product.price}',
                        style: const TextStyle(
                          color: Color(0xFFFFB400),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '¥${product.originalPrice}',
                        style: const TextStyle(
                          color: Color(0xFF665D54),
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
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
                          product.id == 'champagne'))
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
          ],
        ),
      ),
    );
  }

  Widget _buildCartBar() {
    final enabled = _canEdit && _itemCount > 0 && !_quoting;
    return Container(
      key: const ValueKey('ordering-cart-bar'),
      height: 74,
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 10),
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
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2117),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF64533E)),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: legacyGold,
                    size: 27,
                  ),
                ),
                if (_itemCount > 0)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      key: const ValueKey('ordering-cart-badge'),
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _itemCount == 0 ? '购物袋是空的' : '预估 ¥$_total',
                  key: const ValueKey('ordering-estimate'),
                  style: TextStyle(
                    color: _itemCount == 0
                        ? const Color(0xFF7D746B)
                        : const Color(0xFFFFB400),
                    fontSize: _itemCount == 0 ? 13 : 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_itemCount > 0)
                  const Text(
                    '最终价格以确认页报价为准',
                    style: TextStyle(color: Color(0xFF756B61), fontSize: 9),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 104,
            height: 48,
            child: FilledButton(
              key: const ValueKey('ordering-confirm'),
              onPressed: enabled ? _requestFakeQuote : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC9B69E),
                foregroundColor: const Color(0xFF1C150E),
                disabledBackgroundColor: const Color(0xFF332E28),
                disabledForegroundColor: const Color(0xFF756B61),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
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
                      '去确认',
                      style: TextStyle(fontWeight: FontWeight.w800),
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
              detail: product.detail,
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
              'Fake 报价已生成',
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
              '确认页 KC-P-035 将在下一页接续；本次未调用真实接口或支付。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9C9186), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCartSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final selected = _products
              .where((product) => (_quantities[product.id] ?? 0) > 0)
              .toList();
          return SafeArea(
            top: false,
            child: Container(
              key: const ValueKey('ordering-cart-sheet'),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .68,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0E0C0A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF94826C),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_bag_rounded,
                          color: Color(0xFF241B12),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '已选商品（$_itemCount）',
                          style: const TextStyle(
                            color: Color(0xFF211910),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          key: const ValueKey('ordering-clear-cart'),
                          onPressed: () async {
                            final clear = await _confirmClear(sheetContext);
                            if (clear != true || !mounted) return;
                            setState(_quantities.clear);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('清空'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF32261B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: selected.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 76,
                        color: Color(0xFF28231E),
                      ),
                      itemBuilder: (context, index) {
                        final product = selected[index];
                        final quantity = _quantities[product.id] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Image.asset(
                                  product.asset,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        color: Color(0xFFE5DACD),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '¥${product.price}',
                                      style: const TextStyle(
                                        color: Color(0xFFFFB400),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _QuantityControl(
                                productId: 'sheet-${product.id}',
                                quantity: quantity,
                                canDecrease: _canEdit,
                                canIncrease:
                                    _canEdit && quantity < product.limit,
                                onDecrease: () {
                                  _changeQuantity(product, -1);
                                  setSheetState(() {});
                                  if ((_quantities[product.id] ?? 0) == 0 &&
                                      _itemCount == 0) {
                                    Navigator.pop(sheetContext);
                                  }
                                },
                                onIncrease: () {
                                  _changeQuantity(product, 1);
                                  setSheetState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    child: Row(
                      children: [
                        const Text(
                          '合计（预估）',
                          style: TextStyle(color: Color(0xFF9C9186)),
                        ),
                        const Spacer(),
                        Text(
                          '¥$_total',
                          style: const TextStyle(
                            color: Color(0xFFFFB400),
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool?> _confirmClear(BuildContext sheetContext) {
    return showDialog<bool>(
      context: sheetContext,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1713),
        title: const Text('清空购物袋？'),
        content: const Text('只会清理当前门店和桌位的 Fake 草稿。'),
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
              title: Text('点单页 Fake 场景'),
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
        _quantities['champagne'] = 1;
        _quantities['fruit'] = 1;
      }
      if (selected == ScanOrderingScenario.limitReached) {
        _quantities['champagne'] = 2;
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

class _OrderingProduct {
  const _OrderingProduct({
    required this.id,
    required this.category,
    required this.subcategory,
    required this.name,
    required this.detail,
    required this.price,
    required this.originalPrice,
    required this.asset,
    required this.limit,
  });

  final String id;
  final String category;
  final String subcategory;
  final String name;
  final String detail;
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
            width: 30,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE0D4C5), fontSize: 14),
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (enabled ? const Color(0xFFFFB400) : const Color(0xFF39332D))
                : Colors.transparent,
            border: filled
                ? null
                : Border.all(
                    color: enabled
                        ? const Color(0xFFC9B69E)
                        : const Color(0xFF39332D),
                  ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: filled
                ? (enabled ? Colors.black : const Color(0xFF6D655E))
                : (enabled ? legacyGold : const Color(0xFF6D655E)),
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
