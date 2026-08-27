import 'dart:async';

import 'package:flutter/material.dart';

import '../../club/presentation/legacy_club_components.dart';

enum OrderCenterFilter { all, awaitingPayment, active, completedAndAfterSales }

enum OrderCenterScenario {
  content,
  initialLoading,
  emptyAll,
  emptyFilter,
  error,
  offlineCached,
  loadMoreError,
  endReached,
  updateAvailable,
  unknownStatus,
  sessionInvalid,
}

enum FakeOrderStatus {
  awaitingPayment,
  paymentProcessing,
  confirmed,
  inService,
  completed,
  cancelled,
  refunding,
  refunded,
  unknown,
}

class FakeOrderRef {
  const FakeOrderRef(this.opaqueId);

  final String opaqueId;
}

class OrderCenterPage extends StatefulWidget {
  const OrderCenterPage({
    super.key,
    required this.onBack,
    this.onOpenOrder,
    this.onOpenHome,
    this.onSessionResetRequested,
    this.initialScenario = OrderCenterScenario.content,
  });

  final VoidCallback onBack;
  final ValueChanged<FakeOrderRef>? onOpenOrder;
  final VoidCallback? onOpenHome;
  final VoidCallback? onSessionResetRequested;
  final OrderCenterScenario initialScenario;

  @override
  State<OrderCenterPage> createState() => _OrderCenterPageState();
}

class _OrderCenterPageState extends State<OrderCenterPage> {
  static const _firstPage = <_FakeOrderSummary>[
    _FakeOrderSummary(
      ref: FakeOrderRef('order-scan-v8-0827'),
      type: '扫码点单',
      title: 'KINGBAR V8 桌点单',
      summary: '星光香槟、金标威士忌 · 共2件',
      time: '08月27日 20:18',
      amount: 1156,
      status: FakeOrderStatus.awaitingPayment,
      asset: 'assets/legacy/ordering/product_champagne_v1.png',
    ),
    _FakeOrderSummary(
      ref: FakeOrderRef('order-vip-a6-0828'),
      type: 'VIP组局',
      title: 'A6 卡座搭子局',
      summary: '08月28日 20:30 · A6卡座 · 已确认席位',
      time: '08月27日 18:42',
      amount: 688,
      status: FakeOrderStatus.confirmed,
      asset: 'assets/legacy/ordering/product_whisky_v1.png',
    ),
    _FakeOrderSummary(
      ref: FakeOrderRef('order-aa-v2-0826'),
      type: '一起玩AA',
      title: '星光香槟套餐',
      summary: '08月26日 20:30 · V2卡座 · 已完成',
      time: '08月25日 21:06',
      amount: 168,
      status: FakeOrderStatus.completed,
      asset: 'assets/legacy/ordering/product_champagne_v1.png',
    ),
    _FakeOrderSummary(
      ref: FakeOrderRef('order-scan-fruit-0825'),
      type: '扫码点单',
      title: 'V2 桌鲜果盘加购',
      summary: '缤纷鲜果盘 · 退款原路返回中',
      time: '08月25日 22:16',
      amount: 88,
      status: FakeOrderStatus.refunding,
      asset: 'assets/legacy/ordering/product_fruit_platter_v1.png',
    ),
  ];

  static const _secondPage = <_FakeOrderSummary>[
    _FakeOrderSummary(
      ref: FakeOrderRef('order-vip-c3-0823'),
      type: 'VIP组局',
      title: 'C3 夏日音乐局',
      summary: '08月23日 21:00 · C3卡座 · 已取消',
      time: '08月22日 17:30',
      amount: 398,
      status: FakeOrderStatus.cancelled,
      asset: 'assets/legacy/ordering/product_whisky_v1.png',
    ),
    _FakeOrderSummary(
      ref: FakeOrderRef('order-aa-b5-0818'),
      type: '一起玩AA',
      title: '周末微醉套餐',
      summary: '08月18日 20:30 · B5卡座 · 已退款',
      time: '08月17日 19:12',
      amount: 198,
      status: FakeOrderStatus.refunded,
      asset: 'assets/legacy/ordering/product_champagne_v1.png',
    ),
  ];

  final ScrollController _scrollController = ScrollController();
  OrderCenterFilter _filter = OrderCenterFilter.all;
  late OrderCenterScenario _scenario;
  bool _loadingMore = false;
  bool _hasSecondPage = false;
  bool _refreshed = false;

  @override
  void initState() {
    super.initState();
    _scenario = widget.initialScenario;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  List<_FakeOrderSummary> get _allOrders {
    final result = <_FakeOrderSummary>[
      ..._firstPage,
      if (_hasSecondPage) ..._secondPage,
    ];
    if (_refreshed) {
      result[0] = result[0].copyWith(status: FakeOrderStatus.paymentProcessing);
    }
    if (_scenario == OrderCenterScenario.unknownStatus) {
      result.insert(
        1,
        const _FakeOrderSummary(
          ref: FakeOrderRef('order-unknown-0827'),
          type: '扫码点单',
          title: 'KINGBAR 桌台消费',
          summary: '服务端状态暂未识别 · 只读',
          time: '08月27日 19:52',
          amount: 268,
          status: FakeOrderStatus.unknown,
          asset: 'assets/legacy/ordering/product_fruit_platter_v1.png',
        ),
      );
    }
    return result;
  }

  List<_FakeOrderSummary> get _visibleOrders {
    if (_scenario == OrderCenterScenario.emptyAll ||
        _scenario == OrderCenterScenario.emptyFilter ||
        _scenario == OrderCenterScenario.sessionInvalid) {
      return const [];
    }
    return _allOrders.where((order) {
      return switch (_filter) {
        OrderCenterFilter.all => true,
        OrderCenterFilter.awaitingPayment => {
          FakeOrderStatus.awaitingPayment,
          FakeOrderStatus.paymentProcessing,
        }.contains(order.status),
        OrderCenterFilter.active => {
          FakeOrderStatus.confirmed,
          FakeOrderStatus.inService,
        }.contains(order.status),
        OrderCenterFilter.completedAndAfterSales => {
          FakeOrderStatus.completed,
          FakeOrderStatus.cancelled,
          FakeOrderStatus.refunding,
          FakeOrderStatus.refunded,
        }.contains(order.status),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LegacyClubScaffold(
      title: '我的订单',
      onBack: widget.onBack,
      showMockLabel: false,
      onTitleLongPress: _showScenarioPicker,
      child: Column(
        children: [
          _buildFilters(),
          ...switch (_statusBanner) {
            final banner? => [banner],
            null => const <Widget>[],
          },
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      key: const ValueKey('order-center-filters'),
      height: 54,
      decoration: const BoxDecoration(
        color: Color(0xFF0E090C),
        border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: Row(
        children: OrderCenterFilter.values.map((filter) {
          final selected = filter == _filter;
          return Expanded(
            child: InkWell(
              key: ValueKey('order-filter-${filter.name}'),
              onTap: () => setState(() {
                _filter = filter;
                if (_scenario == OrderCenterScenario.emptyFilter) {
                  _scenario = OrderCenterScenario.content;
                }
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(0);
                }
              }),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _filterLabel(filter),
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? legacyGold : const Color(0xFF7D746B),
                      fontSize: selected ? 15 : 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: selected ? 32 : 0,
                    height: 2,
                    color: const Color(0xFFFFB400),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_scenario == OrderCenterScenario.initialLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => const _OrderSkeleton(),
      );
    }
    if (_scenario == OrderCenterScenario.error) {
      return _OrderCenterEmpty(
        icon: Icons.sync_problem_rounded,
        title: '暂时无法加载订单',
        subtitle: '当前筛选和返回路径仍然保留',
        action: '重试',
        onAction: () => setState(() => _scenario = OrderCenterScenario.content),
      );
    }
    if (_scenario == OrderCenterScenario.sessionInvalid) {
      return _OrderCenterEmpty(
        icon: Icons.lock_reset_rounded,
        title: '会话已失效',
        subtitle: '当前账号的订单列表已从内存清理',
        action: '重新登录',
        onAction: widget.onSessionResetRequested,
      );
    }
    final orders = _visibleOrders;
    if (orders.isEmpty) {
      final filtered =
          _filter != OrderCenterFilter.all ||
          _scenario == OrderCenterScenario.emptyFilter;
      return _OrderCenterEmpty(
        icon: Icons.receipt_long_outlined,
        title: filtered ? '当前筛选暂无订单' : '还没有订单',
        subtitle: filtered ? '切换到“全部”查看其他状态' : '完成卡座预订或扫码点单后将在这里显示',
        action: filtered ? '查看全部' : '返回首页',
        onAction: filtered
            ? () => setState(() => _filter = OrderCenterFilter.all)
            : widget.onOpenHome,
      );
    }
    return RefreshIndicator(
      color: legacyGold,
      backgroundColor: const Color(0xFF251E17),
      onRefresh: _refresh,
      child: ListView.separated(
        key: const ValueKey('order-center-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 34),
        itemCount: orders.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == orders.length) return _buildPaginationFooter();
          return _buildOrderCard(orders[index]);
        },
      ),
    );
  }

  Widget _buildOrderCard(_FakeOrderSummary order) {
    final status = _statusPresentation(order.status);
    return Material(
      key: ValueKey('order-card-${order.ref.opaqueId}'),
      color: const Color(0xFF15110E),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openOrder(order.ref),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF5C4C3A), width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30271E),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF554638)),
                      ),
                      child: Text(
                        order.type,
                        style: const TextStyle(color: legacyGold, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE8DED1),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: status.$2.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: status.$2,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            status.$1,
                            style: TextStyle(
                              color: status.$2,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        order.asset,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB7ACA0),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            order.time,
                            style: const TextStyle(
                              color: Color(0xFF6E665F),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥${order.amount}',
                          style: const TextStyle(
                            color: Color(0xFFFFB400),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 13),
                        const Row(
                          children: [
                            Text(
                              '查看详情',
                              style: TextStyle(color: legacyGold, fontSize: 12),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: legacyGold,
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: legacyGold),
          ),
        ),
      );
    }
    if (_scenario == OrderCenterScenario.loadMoreError) {
      return TextButton.icon(
        key: const ValueKey('order-load-more-retry'),
        onPressed: () {
          setState(() => _scenario = OrderCenterScenario.content);
          _loadMore();
        },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('下一页加载失败，点击重试'),
      );
    }
    if (_hasSecondPage || _scenario == OrderCenterScenario.endReached) {
      return const Padding(
        key: ValueKey('order-end-reached'),
        padding: EdgeInsets.all(18),
        child: Center(
          child: Text(
            '没有更多订单了',
            style: TextStyle(color: Color(0xFF5F5851), fontSize: 11),
          ),
        ),
      );
    }
    return TextButton(
      key: const ValueKey('order-load-more'),
      onPressed: _loadMore,
      child: const Text('加载更多'),
    );
  }

  Widget? get _statusBanner {
    final data = switch (_scenario) {
      OrderCenterScenario.offlineCached => (
        Icons.cloud_off_rounded,
        '离线缓存 · 更新于 20:12 · 只读',
      ),
      OrderCenterScenario.updateAvailable => (
        Icons.notifications_active_outlined,
        '订单状态可能已更新，请刷新确认',
      ),
      OrderCenterScenario.unknownStatus => (
        Icons.help_outline_rounded,
        '存在未识别状态，已保留订单并标记只读',
      ),
      _ => null,
    };
    if (data == null) return null;
    return Container(
      key: const ValueKey('order-center-banner'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      color: const Color(0xFF30261B),
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
          if (_scenario == OrderCenterScenario.updateAvailable)
            TextButton(onPressed: _refresh, child: const Text('立即刷新')),
        ],
      ),
    );
  }

  void _openOrder(FakeOrderRef ref) {
    if (widget.onOpenOrder case final callback?) {
      callback(ref);
      return;
    }
    showFakeResult(context, '已生成订单详情意图 ${ref.opaqueId}');
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    setState(() {
      _refreshed = true;
      _scenario = OrderCenterScenario.content;
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 90 ||
        _hasSecondPage ||
        _loadingMore) {
      return;
    }
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _hasSecondPage) return;
    setState(() => _loadingMore = true);
    await Future<void>.delayed(const Duration(milliseconds: 430));
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (_scenario != OrderCenterScenario.loadMoreError) {
        _hasSecondPage = true;
        _scenario = OrderCenterScenario.endReached;
      }
    });
  }

  Future<void> _showScenarioPicker() async {
    final selected = await showModalBottomSheet<OrderCenterScenario>(
      context: context,
      backgroundColor: const Color(0xFF181512),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: ListView(
            children: [
              const ListTile(
                title: Text('订单中心 Fake 场景'),
                subtitle: Text('仅用于 UI 验收，长按标题再次打开'),
              ),
              for (final scenario in OrderCenterScenario.values)
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
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scenario = selected;
      if (selected == OrderCenterScenario.emptyFilter) {
        _filter = OrderCenterFilter.awaitingPayment;
      }
      if (selected == OrderCenterScenario.content) {
        _filter = OrderCenterFilter.all;
      }
    });
  }

  String _filterLabel(OrderCenterFilter filter) => switch (filter) {
    OrderCenterFilter.all => '全部',
    OrderCenterFilter.awaitingPayment => '待支付',
    OrderCenterFilter.active => '进行中',
    OrderCenterFilter.completedAndAfterSales => '完成·售后',
  };

  String _scenarioLabel(OrderCenterScenario scenario) => switch (scenario) {
    OrderCenterScenario.content => '混合类型订单',
    OrderCenterScenario.initialLoading => '首屏加载',
    OrderCenterScenario.emptyAll => '全部为空',
    OrderCenterScenario.emptyFilter => '筛选为空',
    OrderCenterScenario.error => '首屏失败',
    OrderCenterScenario.offlineCached => '离线缓存',
    OrderCenterScenario.loadMoreError => '下一页失败',
    OrderCenterScenario.endReached => '已到末页',
    OrderCenterScenario.updateAvailable => '收到状态事件',
    OrderCenterScenario.unknownStatus => '未知订单状态',
    OrderCenterScenario.sessionInvalid => '会话失效',
  };

  (String, Color) _statusPresentation(FakeOrderStatus status) =>
      switch (status) {
        FakeOrderStatus.awaitingPayment => ('待支付', const Color(0xFFFFB400)),
        FakeOrderStatus.paymentProcessing => ('支付确认中', const Color(0xFFFFC96E)),
        FakeOrderStatus.confirmed => ('已确认', const Color(0xFF77D9A5)),
        FakeOrderStatus.inService => ('进行中', const Color(0xFF77D9A5)),
        FakeOrderStatus.completed => ('已完成', const Color(0xFF9E958D)),
        FakeOrderStatus.cancelled => ('已取消', const Color(0xFF827A73)),
        FakeOrderStatus.refunding => ('退款中', const Color(0xFFFFC96E)),
        FakeOrderStatus.refunded => ('已退款', const Color(0xFF9E958D)),
        FakeOrderStatus.unknown => ('状态更新中', const Color(0xFFC9B69E)),
      };
}

class _FakeOrderSummary {
  const _FakeOrderSummary({
    required this.ref,
    required this.type,
    required this.title,
    required this.summary,
    required this.time,
    required this.amount,
    required this.status,
    required this.asset,
  });

  final FakeOrderRef ref;
  final String type;
  final String title;
  final String summary;
  final String time;
  final int amount;
  final FakeOrderStatus status;
  final String asset;

  _FakeOrderSummary copyWith({FakeOrderStatus? status}) => _FakeOrderSummary(
    ref: ref,
    type: type,
    title: title,
    summary: summary,
    time: time,
    amount: amount,
    status: status ?? this.status,
    asset: asset,
  );
}

class _OrderSkeleton extends StatelessWidget {
  const _OrderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        color: const Color(0xFF15110E),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(width: 76, height: 76, color: const Color(0xFF27211B)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(widthFactor: .72),
                SizedBox(height: 13),
                _SkeletonLine(widthFactor: .9),
                SizedBox(height: 10),
                _SkeletonLine(widthFactor: .48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(height: 12, color: const Color(0xFF2B251F)),
    );
  }
}

class _OrderCenterEmpty extends StatelessWidget {
  const _OrderCenterEmpty({
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
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF675C50), size: 54),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: legacyGold,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF827970), fontSize: 12),
            ),
            if (action != null) ...[
              const SizedBox(height: 15),
              TextButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
