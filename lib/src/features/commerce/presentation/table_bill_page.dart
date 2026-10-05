import 'package:flutter/material.dart';

import '../../auth/data/auth_repository_provider.dart';
import '../data/member_orders_repository.dart';
import '../data/ordering_context.dart';
import '../data/ordering_catalog_repository.dart';
import 'member_orders_page.dart';
import 'ordering_entry_status.dart';

/// Read-only current table receipt. Payment authorization remains separate.
class TableBillPage extends StatefulWidget {
  const TableBillPage({
    super.key,
    required this.table,
    required this.onBack,
    this.repository,
    this.events,
    this.products = const [],
  });
  final OrderingContext table;
  final List<OrderingCatalogProduct> products;
  final VoidCallback onBack;
  final MemberOrdersRepository? repository;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<TableBillPage> createState() => _TableBillPageState();
}

class _TableBillPageState extends State<TableBillPage> {
  late final repository =
      widget.repository ?? MemberOrdersRepository.secure(kingclubApiBaseUrl);
  Future<MemberOrdersSnapshot> load({String? orderRef, String? beforeOrder}) =>
      repository.readTable(
        storeRef: widget.table.storeRef,
        tableRef: widget.table.tableId ?? '',
        sessionRef: widget.table.tableSessionRef,
        orderRef: orderRef,
        beforeOrder: beforeOrder,
      );
  @override
  Widget build(BuildContext context) => MemberOrdersPage(
    key: ValueKey('${widget.table.storeRef}/${widget.table.tableSessionRef}'),
    onBack: widget.onBack,
    load: load,
    onOpenOrder: (orderRef) => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        allowSnapshotting: false,
        builder: (pageContext) => MemberOrdersPage(
          orderRef: orderRef,
          load: load,
          events: widget.events,
          onBack: () => Navigator.of(pageContext).pop(),
        ),
      ),
    ),
    events: widget.events,
    retainDuringRefresh: true,
    tableBill: true,
    products: widget.products,
    tableStoreName: widget.table.storeName,
    tableName: widget.table.tableName,
    expandItems: true,
    // Table closure may have no order event. Revalidate visible seating scope
    // even when the socket remains connected; personal order history needn't poll.
    refreshInterval: const Duration(seconds: 20),
    title:
        '${widget.table.tableName} · ${OrderingEntryStatus.text(Localizations.localeOf(context), ['本桌账单', 'Table bill', '本桌帳單', 'บิลโต๊ะนี้'])}',
  );
}
