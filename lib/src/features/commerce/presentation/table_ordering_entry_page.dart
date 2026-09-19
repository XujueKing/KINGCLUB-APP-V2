import 'package:kingclub/src/core/design_system/king_components.dart';
import 'package:flutter/material.dart';

import '../data/ordering_context.dart';
import 'scan_ordering_cart_page.dart';

typedef ResolveOrderingTable = Future<OrderingContext> Function(String tableId);

/// Entry for a scanned tableId. Does not substitute a demo venue on failure.
class TableOrderingEntryPage extends StatefulWidget {
  const TableOrderingEntryPage({
    super.key,
    required this.tableId,
    required this.onBack,
    this.resolveTable,
    this.onQuoteReady,
    this.onOpenOrders,
    this.previewEnabled = false,
    this.tableName,
  });

  final String tableId;
  final VoidCallback onBack;
  final ResolveOrderingTable? resolveTable;
  final ValueChanged<FakeOrderingQuote>? onQuoteReady;
  final VoidCallback? onOpenOrders;
  final bool previewEnabled;
  final String? tableName;

  @override
  State<TableOrderingEntryPage> createState() => _TableOrderingEntryPageState();
}

class _TableOrderingEntryPageState extends State<TableOrderingEntryPage> {
  OrderingContext? _context;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant TableOrderingEntryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tableId != widget.tableId ||
        oldWidget.resolveTable != widget.resolveTable) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final generation = ++_generation;
    setState(() {
      _context = null;
      _loading = widget.resolveTable != null;
      _error = widget.resolveTable == null ? '桌台点单服务尚未接通' : null;
    });
    final resolver = widget.resolveTable;
    if (resolver == null) return;
    try {
      final result = await resolver(widget.tableId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _context = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = '暂时无法读取桌台信息，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previewEnabled && widget.resolveTable == null) {
      final preview = OrderingContext(
        contextRef: 'preview:${widget.tableId}',
        memberRef: 'preview-member',
        storeRef: 'preview-store',
        tableSessionRef: 'preview:${widget.tableId}',
        storeName: 'KINGBAR 湖南工大店',
        storeAddress: '株洲市天元区金华路瀚水栗源1栋102',
        tableName: widget.tableName ?? widget.tableId,
        businessDate: '界面预览',
      );
      return ScanOrderingCartPage(
        key: ValueKey(preview.contextRef),
        orderingContext: preview,
        onBack: widget.onBack,
        onQuoteReady: (_) => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已选商品仅供预览，真实下单尚未开放'))),
      );
    }
    final resolved = _context;
    if (resolved != null) {
      return ScanOrderingCartPage(
        key: ValueKey(resolved.contextRef),
        orderingContext: resolved,
        onBack: widget.onBack,
        onQuoteReady: widget.onQuoteReady,
        onOpenOrders: widget.onOpenOrders,
      );
    }
    return Scaffold(
      appBar: kingAppBar(
        context: context,
        title: const Text('桌台点单'),
        leading: KingBackButton(onPressed: widget.onBack),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? '正在读取桌台信息'),
                  if (widget.resolveTable != null)
                    TextButton(onPressed: _resolve, child: const Text('重试')),
                ],
              ),
      ),
    );
  }
}
