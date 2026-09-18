import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/ordering_context.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';
import 'package:kingclub/src/features/commerce/presentation/table_ordering_entry_page.dart';

OrderingContext scope(String id) => OrderingContext(
  contextRef: id,
  memberRef: 'member',
  storeRef: 'bar-$id',
  tableSessionRef: 'session-$id',
  storeName: '店-$id',
  storeAddress: '地址',
  tableName: id,
  businessDate: '2026/09/18',
  cityId: 'city',
);

void main() {
  testWidgets('查询器未接通不显示演示点单商品', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TableOrderingEntryPage(tableId: 'T1', onBack: () {}),
      ),
    );
    expect(find.text('桌台点单服务尚未接通'), findsOneWidget);
    expect(find.byType(ScanOrderingCartPage), findsNothing);
  });

  testWidgets('仅以 tableId 查询，换桌后忽略旧查询结果', (tester) async {
    final requests = <String>[];
    final a = Completer<OrderingContext>();
    final b = Completer<OrderingContext>();
    Future<OrderingContext> resolve(String id) {
      requests.add(id);
      return id == 'A' ? a.future : b.future;
    }

    Widget page(String id) => MaterialApp(
      home: TableOrderingEntryPage(
        tableId: id,
        onBack: () {},
        resolveTable: resolve,
      ),
    );
    await tester.pumpWidget(page('A'));
    expect(find.byType(ScanOrderingCartPage), findsNothing);
    await tester.pumpWidget(page('B'));
    b.complete(scope('B'));
    await tester.pumpAndSettle();
    a.complete(scope('A'));
    await tester.pumpAndSettle();
    expect(requests, ['A', 'B']);
    final cart = tester.widget<ScanOrderingCartPage>(
      find.byType(ScanOrderingCartPage),
    );
    expect(cart.orderingContext!.storeRef, 'bar-B');
    expect(cart.orderingContext!.cityId, 'city');
  });

  testWidgets('查询失败可重试且不借用其他桌台数据', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TableOrderingEntryPage(
          tableId: 'T1',
          onBack: () {},
          resolveTable: (id) async {
            if (++attempts == 1) throw StateError('unavailable');
            return scope(id);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScanOrderingCartPage), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('店-T1'), findsOneWidget);
    expect(attempts, 2);
  });
}
