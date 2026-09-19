import 'package:kingclub/src/core/design_system/king_components.dart';
import 'package:flutter/material.dart';

import '../data/ordering_context.dart';
import '../../auth/domain/auth_repository.dart';
import 'ordering_entry_status.dart';
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
    this.onSignIn,
    this.locale = const Locale('zh'),
  });

  final String tableId;
  final VoidCallback onBack;
  final ResolveOrderingTable? resolveTable;
  final ValueChanged<FakeOrderingQuote>? onQuoteReady;
  final VoidCallback? onOpenOrders;
  final bool previewEnabled;
  final String? tableName;
  final VoidCallback? onSignIn;
  final Locale locale;

  @override
  State<TableOrderingEntryPage> createState() => _TableOrderingEntryPageState();
}

class _TableOrderingEntryPageState extends State<TableOrderingEntryPage> {
  OrderingContext? _context;
  bool _loading = false;
  OrderingEntryStatus? _error;
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
      _error = widget.resolveTable == null
          ? const OrderingEntryStatus('ORDERING_SERVICE_UNAVAILABLE')
          : null;
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
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = OrderingEntryStatus(
          error is AuthFailure ? error.code : 'UNKNOWN',
        );
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
        title: Text(
          OrderingEntryStatus.text(widget.locale, [
            '桌台点单',
            'Table ordering',
            '桌台點單',
            'สั่งอาหารที่โต๊ะ',
          ]),
        ),
        leading: KingBackButton(onPressed: widget.onBack),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error?.message(widget.locale) ?? '',
                        textAlign: TextAlign.center,
                      ),
                      if (widget.resolveTable != null &&
                          (_error?.canRefresh ?? false))
                        TextButton(
                          onPressed: _resolve,
                          child: Text(
                            OrderingEntryStatus.text(widget.locale, [
                              '重试',
                              'Refresh',
                              '重試',
                              'รีเฟรช',
                            ]),
                          ),
                        ),
                      if ((_error?.requiresLogin ?? false) &&
                          widget.onSignIn != null)
                        TextButton(
                          onPressed: widget.onSignIn,
                          child: Text(
                            OrderingEntryStatus.text(widget.locale, [
                              '重新登录',
                              'Sign in',
                              '重新登入',
                              'เข้าสู่ระบบ',
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
