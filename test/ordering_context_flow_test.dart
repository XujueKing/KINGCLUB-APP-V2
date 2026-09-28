import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/ordering_context.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_order_confirmation_page.dart';

OrderingContext scope(String session) => OrderingContext(
  contextRef: 'context-$session',
  memberRef: 'member-demo',
  storeRef: 'store-demo',
  tableSessionRef: session,
  storeName: '测试门店',
  storeAddress: '合成地址',
  tableName: session,
  businessDate: '2026/09/18',
);

void main() {
  testWidgets('新桌空购物袋，报价和确认页保留同一门店场次', (tester) async {
    FakeOrderingQuote? quote;
    await tester.pumpWidget(
      MaterialApp(
        home: ScanOrderingCartPage(
          orderingContext: scope('A06'),
          onBack: () {},
          onQuoteReady: (v) => quote = v,
        ),
      ),
    );
    expect(find.text('测试门店'), findsOneWidget);
    expect(find.text('A06'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
    await tester.pumpAndSettle();
    expect(quote, isNull);
    final add = find.byKey(const ValueKey('ordering-add-hennessy-xo'));
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(quote!.itemCount, 1);
    expect(quote!.orderingContext!.tableSessionRef, 'A06');
    await tester.pumpWidget(
      MaterialApp(
        home: ScanOrderConfirmationPage(
          quote: quote,
          onBack: () {},
          onModify: () {},
        ),
      ),
    );
    expect(find.text('测试门店'), findsOneWidget);
    expect(find.text('A06'), findsOneWidget);
    expect(find.text('2026/09/18'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('报价等待期间换桌，旧桌报价不跳转且新桌为空', (tester) async {
    var emitted = 0;
    Widget page(String session) => MaterialApp(
      home: ScanOrderingCartPage(
        orderingContext: scope(session),
        onBack: () {},
        onQuoteReady: (_) => emitted++,
      ),
    );
    await tester.pumpWidget(page('A06'));
    final add = find.byKey(const ValueKey('ordering-add-hennessy-xo'));
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(page('B08'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(emitted, 0);
    expect(find.text('B08'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
    await tester.pumpAndSettle();
    expect(emitted, 0);
  });
}
