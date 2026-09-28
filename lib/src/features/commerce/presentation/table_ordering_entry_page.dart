import '../data/table_management_repository.dart';
import 'table_party_page.dart';
import 'walk_in_party_page.dart';
import '../data/ordering_table_repository.dart';

import 'package:uuid/uuid.dart';

import 'package:kingclub/src/core/design_system/king_components.dart';
import 'package:flutter/material.dart';

import '../data/ordering_context.dart';
import '../data/ordering_catalog_repository.dart';
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
    this.readCatalog,
    this.tableManagement,
    this.openWalkIn,
    this.onQuoteReady,
    this.onOpenOrders,
    this.previewEnabled = false,
    this.tableName,
    this.onSignIn,
    this.locale = const Locale('zh'),
  });

  final TableManagementRepository? tableManagement;
  final Future<OrderingContext> Function(
    OrderingEntryRequired entry,
    int count,
    String requestId,
  )?
  openWalkIn;
  final String tableId;
  final VoidCallback onBack;
  final ResolveOrderingTable? resolveTable;
  final Future<OrderingCatalog> Function(OrderingContext)? readCatalog;
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
  OrderingCatalog? _catalog;
  bool _loading = false;
  OrderingEntryStatus? _error;
  int _generation = 0;
  bool _partyReady = false;
  OrderingEntryRequired? _entry;
  String? _openingRequest;
  int? _openingCount;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant TableOrderingEntryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tableId != widget.tableId) {
      _openingRequest = null;
      _openingCount = null;
    }
    if (oldWidget.tableId != widget.tableId ||
        oldWidget.resolveTable != widget.resolveTable ||
        oldWidget.readCatalog != widget.readCatalog) {
      _resolve();
    }
  }

  Future<void> _resolve([
    Future<OrderingContext> Function()? confirmation,
  ]) async {
    final generation = ++_generation;
    setState(() {
      _partyReady = false;
      _entry = null;
      _context = null;
      _catalog = null;
      _loading = widget.resolveTable != null;
      _error = widget.resolveTable == null
          ? const OrderingEntryStatus('ORDERING_SERVICE_UNAVAILABLE')
          : null;
    });
    final resolver = widget.resolveTable;
    if (resolver == null) return;
    try {
      final result = await (confirmation?.call() ?? resolver(widget.tableId));
      if (!mounted || generation != _generation) return;
      final reader = widget.readCatalog;
      if (reader == null) {
        throw const AuthFailure('CATALOG_NOT_ENABLED', '商品目录尚未开放');
      }
      final catalog = await reader(result);
      if (!catalog.context.hasSameScope(result)) {
        throw const AuthFailure('ORDERING_SESSION_CHANGED', '桌台已变化');
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _context = result;
        _catalog = catalog;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        if (error is OrderingEntryRequired) {
          _entry = error;
          _error = null;
          return;
        }
        _error = OrderingEntryStatus(
          error is AuthFailure ? error.code : 'UNKNOWN',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    if (entry != null && widget.openWalkIn != null) {
      return WalkInPartyPage(
        entry: entry,
        locale: widget.locale,
        onBack: widget.onBack,
        onRefresh: () => _resolve(),
        onConfirm: (count) async {
          if (_openingCount != count || _openingRequest == null) {
            _openingCount = count;
            _openingRequest = const Uuid().v4();
          }
          await _resolve(
            () => widget.openWalkIn!(entry, count, _openingRequest!),
          );
        },
      );
    }
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
      final management = widget.tableManagement;
      if (management != null && widget.openWalkIn == null && !_partyReady) {
        return TablePartyPage(
          key: ValueKey('party:${resolved.contextRef}'),
          tableName: resolved.tableName,
          locale: widget.locale,
          onBack: widget.onBack,
          read: () => management.readParty(resolved),
          save: (count, revision, requestId) =>
              management.saveParty(resolved, count, revision, requestId),
          onReady: () {
            if (mounted) setState(() => _partyReady = true);
          },
        );
      }
      return ScanOrderingCartPage(
        key: ValueKey(resolved.contextRef),
        orderingContext: resolved,
        catalog: _catalog,
        locale: widget.locale,
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
