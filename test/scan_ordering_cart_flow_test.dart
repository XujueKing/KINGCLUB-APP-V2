import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';

void main() {
  Widget subject({ValueChanged<FakeOrderingQuote>? onQuoteReady}) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ScanOrderingCartPage(onBack: () {}, onQuoteReady: onQuoteReady),
    );
  }

  testWidgets('复刻旧版点单主要结构', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('KINGBAR 湖南工大店'), findsOneWidget);
    expect(find.text('V8'), findsOneWidget);
    expect(find.text('酒水'), findsOneWidget);
    expect(find.text('星光香槟'), findsOneWidget);
    expect(find.byKey(const ValueKey('ordering-cart-bar')), findsOneWidget);
    expect(find.text('购物袋是空的'), findsOneWidget);
  });

  testWidgets('加购、预估金额与 Fake 报价可达', (tester) async {
    FakeOrderingQuote? quote;
    await tester.pumpWidget(subject(onQuoteReady: (value) => quote = value));

    await tester.tap(find.byKey(const ValueKey('ordering-add-champagne')));
    await tester.pump();
    expect(find.text('预估 ¥688'), findsOneWidget);
    expect(find.byKey(const ValueKey('ordering-cart-badge')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(quote?.itemCount, 1);
    expect(quote?.total, 688);
  });

  testWidgets('购物袋可展开并二次确认清空', (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byKey(const ValueKey('ordering-add-champagne')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ordering-cart-bag')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ordering-cart-sheet')), findsOneWidget);
    expect(find.text('已选商品（1）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ordering-clear-cart')));
    await tester.pumpAndSettle();
    expect(find.text('清空购物袋？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ordering-clear-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('购物袋是空的'), findsOneWidget);
  });

  testWidgets('搜索会过滤当前目录', (tester) async {
    await tester.pumpWidget(subject());
    await tester.enterText(
      find.byKey(const ValueKey('ordering-search')),
      '威士忌',
    );
    await tester.pump();

    expect(find.text('金标威士忌'), findsOneWidget);
    expect(find.text('星光香槟'), findsNothing);
  });

  testWidgets('售罄场景在商品原位提示', (tester) async {
    await tester.pumpWidget(subject());
    await tester.longPressAt(const Offset(120, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('局部售罄'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ordering-sold-out')), findsOneWidget);
  });
}
