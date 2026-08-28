import 'package:flutter/material.dart';

import '../../commerce/presentation/order_center_page.dart';

enum AssetLedgerType { cashBalance, goldCoin, diamond }

enum _AssetLedgerSection { order, cashBalance, goldCoin, diamond }

enum AssetLedgerScenario {
  allEnabled,
  balanceAndCoinOnly,
  zeroAssets,
  summaryFailure,
  balanceLedger,
  coinLedger,
  diamondLedger,
  emptyLedger,
  yearChanged,
  refreshed,
  nextPage,
  nextPageFailure,
  pendingEntry,
  reversedEntry,
  frozenAsset,
  linkedOrder,
  ordinaryExpanded,
  offlineCached,
  unknownState,
  sessionInvalid,
}

enum AssetLedgerEntryStatus { posted, pending, reversed, unknown }

class FakeAssetLedgerEntry {
  const FakeAssetLedgerEntry({
    required this.refId,
    required this.type,
    required this.title,
    required this.time,
    required this.amount,
    required this.status,
    this.orderRef,
    this.note,
  });

  final String refId;
  final AssetLedgerType type;
  final String title;
  final String time;
  final int amount;
  final AssetLedgerEntryStatus status;
  final FakeOrderRef? orderRef;
  final String? note;
}

class AssetLedgerPage extends StatefulWidget {
  const AssetLedgerPage({
    super.key,
    this.initialType = AssetLedgerType.cashBalance,
    this.initialScenario = AssetLedgerScenario.allEnabled,
    this.onBack,
    this.onOpenOrder,
    this.onSessionResetRequested,
  });

  final AssetLedgerType initialType;
  final AssetLedgerScenario initialScenario;
  final VoidCallback? onBack;
  final ValueChanged<FakeOrderRef>? onOpenOrder;
  final VoidCallback? onSessionResetRequested;

  @override
  State<AssetLedgerPage> createState() => _AssetLedgerPageState();
}

class _AssetLedgerPageState extends State<AssetLedgerPage> {
  static const _background = Color(0xFF0E090C);
  static const _gold = Color(0xFFFFB400);
  static const _text = Color(0xFFCCCCCC);
  static const _muted = Color(0x66FFFFFF);
  static const _divider = Color(0x1AFFFFFF);

  late _AssetLedgerSection _selectedSection;
  late AssetLedgerScenario _scenario;
  int _year = 2026;
  bool _loading = false;
  bool _loadingMore = false;
  bool _showSecondPage = false;
  bool _loadMoreFailed = false;
  bool _refreshMarked = false;
  String? _expandedRef;

  @override
  void initState() {
    super.initState();
    _selectedSection = _sectionForType(widget.initialType);
    _scenario = widget.initialScenario;
    _applyScenarioSelection();
  }

  List<AssetLedgerType> get _supportedTypes =>
      _scenario == AssetLedgerScenario.balanceAndCoinOnly
      ? const [AssetLedgerType.cashBalance, AssetLedgerType.goldCoin]
      : AssetLedgerType.values;

  List<_AssetLedgerSection> get _supportedSections => [
    _AssetLedgerSection.order,
    ..._supportedTypes.map(_sectionForType),
  ];

  AssetLedgerType? get _selectedType => _typeForSection(_selectedSection);

  bool get _contentBlocked =>
      _scenario == AssetLedgerScenario.summaryFailure ||
      _scenario == AssetLedgerScenario.sessionInvalid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_scenario == AssetLedgerScenario.sessionInvalid)
              Expanded(child: _buildSessionInvalid())
            else if (_scenario == AssetLedgerScenario.summaryFailure)
              Expanded(child: _buildSummaryFailure())
            else ...[
              _buildTabs(),
              Expanded(child: _buildLedger()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      width: double.infinity,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            child: IconButton(
              key: const ValueKey('asset-ledger-back'),
              tooltip: '返回',
              onPressed: widget.onBack ?? () => Navigator.maybePop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _text,
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('asset-ledger-title'),
            onLongPress: _showScenarioPicker,
            child: const Text(
              '账单记录',
              style: TextStyle(
                color: _text,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: _supportedSections.map((section) {
          final selected = section == _selectedSection;
          return Expanded(
            child: InkWell(
              key: ValueKey('asset-tab-${section.name}'),
              onTap: () => _selectSection(section),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _sectionName(section),
                    style: TextStyle(
                      color: _text,
                      fontSize: selected ? 18 : 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 7),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 2,
                    width: selected ? 58 : 0,
                    color: selected ? _gold : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLedger() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
      );
    }

    final entries = _entriesForSelectedSection();
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 24) _loadMore();
        return false;
      },
      child: RefreshIndicator(
        color: _gold,
        backgroundColor: const Color(0xFF251C13),
        onRefresh: _refresh,
        child: ListView(
          key: ValueKey('asset-ledger-list-${_selectedSection.name}'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildYearSummary(entries),
            if (_scenario == AssetLedgerScenario.offlineCached)
              _statusBanner(
                Icons.cloud_off_outlined,
                '离线只读 · 缓存更新于 08月28日 09:20',
              ),
            if (_refreshMarked)
              _statusBanner(Icons.check_circle_outline, '摘要与首屏流水已同步刷新'),
            if (_scenario == AssetLedgerScenario.frozenAsset)
              _statusBanner(Icons.lock_outline, '冻结：¥20.00 · 处理中：¥8.00'),
            if (entries.isEmpty)
              _buildEmptyState()
            else
              ...entries.map(_buildEntry),
            if (entries.isNotEmpty) _buildLoadMore(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildYearSummary(List<FakeAssetLedgerEntry> entries) {
    final income = entries
        .where((entry) => entry.amount > 0)
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final expense = entries
        .where((entry) => entry.amount < 0)
        .fold<int>(0, (sum, entry) => sum + entry.amount.abs());
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          PopupMenuButton<int>(
            key: const ValueKey('asset-year-picker'),
            color: const Color(0xFF21191C),
            initialValue: _year,
            onSelected: _changeYear,
            itemBuilder: (_) => [2026, 2025, 2024]
                .map(
                  (year) => PopupMenuItem(
                    value: year,
                    child: Text(
                      '$year年度',
                      style: const TextStyle(color: _text),
                    ),
                  ),
                )
                .toList(),
            child: Row(
              children: [
                Text(
                  '$_year年度',
                  style: const TextStyle(color: _text, fontSize: 14),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more, color: _text, size: 16),
              ],
            ),
          ),
          const Spacer(),
          Text(
            '支出 ${_formatSummary(expense)}  收入 ${_formatSummary(income)}',
            key: const ValueKey('asset-period-summary'),
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(FakeAssetLedgerEntry entry) {
    final expanded = _expandedRef == entry.refId;
    return Material(
      color: const Color(0x08FFFFFF),
      child: InkWell(
        key: ValueKey('asset-entry-${entry.refId}'),
        onTap: () => _openEntry(entry),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _divider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: const BoxDecoration(
                      color: Color(0xFF241C1F),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _assetIcon(entry.type, 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(color: _text, fontSize: 14),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${entry.time} · ${_statusLabel(entry.status)}',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatEntryAmount(entry),
                        style: TextStyle(
                          color: entry.amount > 0 ? _gold : _text,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (entry.orderRef != null) ...[
                        const SizedBox(height: 5),
                        const Text(
                          '查看订单 ›',
                          style: TextStyle(color: _gold, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(11),
                  color: const Color(0x0FFFFFFF),
                  child: Text(
                    entry.note ?? '该笔流水为 Fake 展示记录，金额和状态均不来自真实账户。',
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMore() {
    if (_loadMoreFailed) {
      return TextButton.icon(
        key: const ValueKey('asset-load-more-retry'),
        onPressed: _loadMore,
        icon: const Icon(Icons.refresh, color: _gold, size: 18),
        label: const Text('加载失败，点击重试', style: TextStyle(color: _gold)),
      );
    }
    if (_showSecondPage) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(
          child: Text('已加载全部流水', style: TextStyle(color: _muted, fontSize: 11)),
        ),
      );
    }
    return SizedBox(
      key: const ValueKey('asset-load-more'),
      height: _loadingMore ? 42 : 1,
      child: _loadingMore
          ? const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, color: _muted, size: 42),
            SizedBox(height: 12),
            Text('当前资产和年度暂无流水', style: TextStyle(color: _text)),
            SizedBox(height: 6),
            Text('可切换资产或年度查看', style: TextStyle(color: _muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryFailure() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _gold, size: 48),
            const SizedBox(height: 16),
            const Text(
              '资产摘要加载失败',
              style: TextStyle(color: _text, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              '未使用本地流水推算余额，请重试读取完整摘要。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            FilledButton(
              key: const ValueKey('asset-summary-retry'),
              onPressed: () => _setScenario(AssetLedgerScenario.allEnabled),
              style: _buttonStyle(),
              child: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInvalid() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: _gold, size: 48),
            const SizedBox(height: 16),
            const Text('登录状态已失效', style: TextStyle(color: _text, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              '本地资产摘要、流水和分页位置已清除。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 22),
            FilledButton(
              key: const ValueKey('asset-session-reset'),
              onPressed: widget.onSessionResetRequested,
              style: _buttonStyle(),
              child: const Text('重新登录'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x142B2010),
        border: Border.all(color: const Color(0x33FFB400)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _text, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _buttonStyle() => FilledButton.styleFrom(
    minimumSize: const Size(130, 44),
    backgroundColor: const Color(0xFFC9B69E),
    foregroundColor: const Color(0xFF181205),
  );

  Widget _assetIcon(AssetLedgerType type, double size) {
    if (type == AssetLedgerType.goldCoin) {
      return Image.asset(
        'assets/legacy/profile/gold.png',
        width: size,
        height: size,
      );
    }
    if (type == AssetLedgerType.diamond) {
      return Image.asset(
        'assets/legacy/profile/diamond.png',
        width: size,
        height: size,
      );
    }
    return Icon(
      Icons.account_balance_wallet_outlined,
      color: _gold,
      size: size,
    );
  }

  List<FakeAssetLedgerEntry> _entriesForSelectedSection() {
    if (_scenario == AssetLedgerScenario.emptyLedger ||
        _scenario == AssetLedgerScenario.zeroAssets ||
        _year == 2024) {
      return const [];
    }
    final selectedType = _selectedType;
    if (_selectedSection == _AssetLedgerSection.order) {
      var orderEntries = _baseEntries
          .where((entry) => entry.orderRef != null)
          .toList();
      if (_showSecondPage && orderEntries.isNotEmpty) {
        orderEntries = [
          ...orderEntries,
          const FakeAssetLedgerEntry(
            refId: 'ledger-page-2-order',
            type: AssetLedgerType.cashBalance,
            title: '历史订单调整',
            time: '07月18日 16:08',
            amount: -1200,
            status: AssetLedgerEntryStatus.posted,
          ),
        ];
      }
      return orderEntries;
    }
    if (selectedType == null) return const [];
    var entries = _baseEntries
        .where((entry) => entry.type == selectedType)
        .toList();
    if (_scenario == AssetLedgerScenario.pendingEntry &&
        selectedType == AssetLedgerType.cashBalance) {
      entries = [
        ...entries,
        const FakeAssetLedgerEntry(
          refId: 'ledger-pending-refund',
          type: AssetLedgerType.cashBalance,
          title: '退款处理中',
          time: '08月28日 09:18',
          amount: 2000,
          status: AssetLedgerEntryStatus.pending,
          note: '支付渠道已返回，Fake 服务端尚未确认最终入账。',
        ),
      ];
    }
    if (_scenario == AssetLedgerScenario.reversedEntry &&
        selectedType == AssetLedgerType.goldCoin) {
      entries = [
        ...entries,
        const FakeAssetLedgerEntry(
          refId: 'ledger-reversed-original',
          type: AssetLedgerType.goldCoin,
          title: '活动金币奖励',
          time: '08月26日 18:20',
          amount: 50,
          status: AssetLedgerEntryStatus.reversed,
          note: '原奖励记录保留；对应冲正记录为 -50 枚。',
        ),
        const FakeAssetLedgerEntry(
          refId: 'ledger-reversal',
          type: AssetLedgerType.goldCoin,
          title: '活动奖励冲正',
          time: '08月27日 10:05',
          amount: -50,
          status: AssetLedgerEntryStatus.posted,
        ),
      ];
    }
    if (_scenario == AssetLedgerScenario.unknownState) {
      entries = [
        FakeAssetLedgerEntry(
          refId: 'ledger-unknown',
          type: selectedType,
          title: '状态更新中',
          time: '08月28日 08:30',
          amount: 0,
          status: AssetLedgerEntryStatus.unknown,
          note: '客户端不识别该状态，因此不推断方向、订单或最终余额。',
        ),
      ];
    }
    if (_showSecondPage && entries.isNotEmpty) {
      final second = FakeAssetLedgerEntry(
        refId: 'ledger-page-2-${selectedType.name}',
        type: selectedType,
        title: '${_typeName(selectedType)}历史调整',
        time: '07月18日 16:08',
        amount: selectedType == AssetLedgerType.cashBalance ? -1200 : 12,
        status: AssetLedgerEntryStatus.posted,
      );
      entries = [...entries, second];
    }
    return entries;
  }

  void _applyScenarioSelection() {
    if (_scenario == AssetLedgerScenario.coinLedger ||
        _scenario == AssetLedgerScenario.reversedEntry) {
      _selectedSection = _AssetLedgerSection.goldCoin;
    } else if (_scenario == AssetLedgerScenario.diamondLedger) {
      _selectedSection = _AssetLedgerSection.diamond;
    } else if (!_supportedSections.contains(_selectedSection)) {
      _selectedSection = _AssetLedgerSection.cashBalance;
    }
    if (_scenario == AssetLedgerScenario.yearChanged) _year = 2025;
    if (_scenario == AssetLedgerScenario.nextPage) _showSecondPage = true;
    if (_scenario == AssetLedgerScenario.nextPageFailure) {
      _loadMoreFailed = true;
    }
    if (_scenario == AssetLedgerScenario.refreshed) _refreshMarked = true;
  }

  void _setScenario(AssetLedgerScenario scenario) {
    setState(() {
      _scenario = scenario;
      _loading = false;
      _loadingMore = false;
      _showSecondPage = false;
      _loadMoreFailed = false;
      _refreshMarked = false;
      _expandedRef = null;
      _year = 2026;
      _applyScenarioSelection();
    });
  }

  void _selectSection(_AssetLedgerSection section) {
    if (_contentBlocked || section == _selectedSection) return;
    setState(() {
      _selectedSection = section;
      _expandedRef = null;
      _showSecondPage = false;
      _loadMoreFailed = false;
    });
  }

  Future<void> _changeYear(int year) async {
    setState(() {
      _year = year;
      _loading = true;
      _showSecondPage = false;
      _expandedRef = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() {
      _refreshMarked = true;
      _showSecondPage = false;
      _loadMoreFailed = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _showSecondPage) return;
    final retryingAfterFailure = _loadMoreFailed;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (_scenario == AssetLedgerScenario.nextPageFailure &&
          !retryingAfterFailure) {
        _loadMoreFailed = true;
      } else {
        _showSecondPage = true;
      }
    });
  }

  void _openEntry(FakeAssetLedgerEntry entry) {
    if (entry.orderRef != null && widget.onOpenOrder != null) {
      widget.onOpenOrder!(entry.orderRef!);
      return;
    }
    setState(
      () => _expandedRef = _expandedRef == entry.refId ? null : entry.refId,
    );
  }

  Future<void> _showScenarioPicker() async {
    final selected = await showModalBottomSheet<AssetLedgerScenario>(
      context: context,
      backgroundColor: const Color(0xFF181214),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  '资产流水 Fake 场景',
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: AssetLedgerScenario.values.length,
                  itemBuilder: (context, index) {
                    final scenario = AssetLedgerScenario.values[index];
                    return ListTile(
                      key: ValueKey('asset-scenario-${scenario.name}'),
                      leading: Text(
                        'M${(index + 1).toString().padLeft(2, '0')}',
                        style: const TextStyle(color: _gold),
                      ),
                      title: Text(
                        _scenarioLabel(scenario),
                        style: const TextStyle(color: _text),
                      ),
                      trailing: scenario == _scenario
                          ? const Icon(Icons.check, color: _gold)
                          : null,
                      onTap: () => Navigator.pop(context, scenario),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) _setScenario(selected);
  }

  String _formatEntryAmount(FakeAssetLedgerEntry entry) {
    if (entry.status == AssetLedgerEntryStatus.unknown) return '待确认';
    final sign = entry.amount > 0
        ? '+'
        : entry.amount < 0
        ? '-'
        : '';
    final absolute = entry.amount.abs();
    if (entry.type == AssetLedgerType.cashBalance) {
      return '$sign¥${(absolute / 100).toStringAsFixed(2)}';
    }
    return '$sign$absolute 枚';
  }

  String _formatSummary(int value) {
    if (_selectedSection == _AssetLedgerSection.order ||
        _selectedType == AssetLedgerType.cashBalance) {
      return '¥${(value / 100).toStringAsFixed(2)}';
    }
    return '$value枚';
  }

  _AssetLedgerSection _sectionForType(AssetLedgerType type) => switch (type) {
    AssetLedgerType.cashBalance => _AssetLedgerSection.cashBalance,
    AssetLedgerType.goldCoin => _AssetLedgerSection.goldCoin,
    AssetLedgerType.diamond => _AssetLedgerSection.diamond,
  };

  AssetLedgerType? _typeForSection(_AssetLedgerSection section) =>
      switch (section) {
        _AssetLedgerSection.order => null,
        _AssetLedgerSection.cashBalance => AssetLedgerType.cashBalance,
        _AssetLedgerSection.goldCoin => AssetLedgerType.goldCoin,
        _AssetLedgerSection.diamond => AssetLedgerType.diamond,
      };

  String _sectionName(_AssetLedgerSection section) => switch (section) {
    _AssetLedgerSection.order => '订单',
    _AssetLedgerSection.cashBalance => '余额',
    _AssetLedgerSection.goldCoin => '金币',
    _AssetLedgerSection.diamond => '钻石',
  };

  String _typeName(AssetLedgerType type) => switch (type) {
    AssetLedgerType.cashBalance => '余额',
    AssetLedgerType.goldCoin => '金币',
    AssetLedgerType.diamond => '钻石',
  };

  String _statusLabel(AssetLedgerEntryStatus status) => switch (status) {
    AssetLedgerEntryStatus.posted => '已入账',
    AssetLedgerEntryStatus.pending => '处理中',
    AssetLedgerEntryStatus.reversed => '已冲正',
    AssetLedgerEntryStatus.unknown => '状态更新中',
  };

  String _scenarioLabel(AssetLedgerScenario scenario) => switch (scenario) {
    AssetLedgerScenario.allEnabled => '三类资产均启用',
    AssetLedgerScenario.balanceAndCoinOnly => '只启用余额与金币',
    AssetLedgerScenario.zeroAssets => '全部为零',
    AssetLedgerScenario.summaryFailure => '摘要加载失败',
    AssetLedgerScenario.balanceLedger => '余额流水正常',
    AssetLedgerScenario.coinLedger => '金币流水正常',
    AssetLedgerScenario.diamondLedger => '钻石流水正常',
    AssetLedgerScenario.emptyLedger => '当前筛选无流水',
    AssetLedgerScenario.yearChanged => '年度切换',
    AssetLedgerScenario.refreshed => '摘要与首屏已刷新',
    AssetLedgerScenario.nextPage => '下一页正常',
    AssetLedgerScenario.nextPageFailure => '下一页重复或失败',
    AssetLedgerScenario.pendingEntry => '处理中记录',
    AssetLedgerScenario.reversedEntry => '冲正记录',
    AssetLedgerScenario.frozenAsset => '冻结资产',
    AssetLedgerScenario.linkedOrder => '关联订单',
    AssetLedgerScenario.ordinaryExpanded => '普通流水展开',
    AssetLedgerScenario.offlineCached => '离线缓存只读',
    AssetLedgerScenario.unknownState => '未知资产或状态',
    AssetLedgerScenario.sessionInvalid => '会话失效',
  };

  static const _baseEntries = [
    FakeAssetLedgerEntry(
      refId: 'ledger-order-spend',
      type: AssetLedgerType.cashBalance,
      title: '星光香槟套餐',
      time: '08月27日 20:31',
      amount: -6800,
      status: AssetLedgerEntryStatus.posted,
      orderRef: FakeOrderRef('order-scan-v8-0827'),
    ),
    FakeAssetLedgerEntry(
      refId: 'ledger-balance-refund',
      type: AssetLedgerType.cashBalance,
      title: '订单退款',
      time: '08月24日 18:10',
      amount: 2000,
      status: AssetLedgerEntryStatus.posted,
      note: '退款已由 Fake 服务端确认入账。',
    ),
    FakeAssetLedgerEntry(
      refId: 'ledger-coin-reward',
      type: AssetLedgerType.goldCoin,
      title: '会员活动奖励',
      time: '08月27日 21:08',
      amount: 50,
      status: AssetLedgerEntryStatus.posted,
    ),
    FakeAssetLedgerEntry(
      refId: 'ledger-coin-spend',
      type: AssetLedgerType.goldCoin,
      title: '金币抵扣',
      time: '08月26日 20:18',
      amount: -30,
      status: AssetLedgerEntryStatus.posted,
      orderRef: FakeOrderRef('order-scan-v8-0827'),
    ),
    FakeAssetLedgerEntry(
      refId: 'ledger-diamond-reward',
      type: AssetLedgerType.diamond,
      title: '会员等级奖励',
      time: '08月25日 12:06',
      amount: 8,
      status: AssetLedgerEntryStatus.posted,
    ),
    FakeAssetLedgerEntry(
      refId: 'ledger-diamond-spend',
      type: AssetLedgerType.diamond,
      title: '活动权益兑换',
      time: '08月20日 19:40',
      amount: -2,
      status: AssetLedgerEntryStatus.posted,
    ),
  ];
}
