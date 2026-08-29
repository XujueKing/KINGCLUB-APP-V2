import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget subject({ValueChanged<FakeOrderingQuote>? onQuoteReady}) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ScanOrderingCartPage(onBack: () {}, onQuoteReady: onQuoteReady),
    );
  }

  testWidgets('复刻旧版点单主要结构', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('KINGBAR 湖南工大店'), findsOneWidget);
    expect(find.byKey(const ValueKey('ordering-table-888')), findsOneWidget);
    expect(find.text('株洲市天元区金华路瀚水栗源1栋102'), findsOneWidget);
    expect(find.text('酒水'), findsOneWidget);
    expect(find.text('轩尼诗XO'), findsOneWidget);
    expect(find.text('芝华士12年'), findsOneWidget);
    expect(find.byKey(const ValueKey('ordering-cart-bar')), findsOneWidget);
    expect(find.text('去结算'), findsOneWidget);
    expect(find.byKey(const ValueKey('ordering-cart-badge')), findsOneWidget);
  });

  testWidgets('加购、预估金额与 Fake 报价可达', (tester) async {
    FakeOrderingQuote? quote;
    await tester.pumpWidget(subject(onQuoteReady: (value) => quote = value));

    final chivasAdd = find.byKey(const ValueKey('ordering-add-chivas-12'));
    await tester.ensureVisible(chivasAdd);
    await tester.pumpAndSettle();
    await tester.tap(chivasAdd);
    await tester.pump();
    expect(find.textContaining('4040'), findsOneWidget);
    expect(find.byKey(const ValueKey('ordering-cart-badge')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(quote?.itemCount, 3);
    expect(quote?.total, 4040);
  });

  testWidgets('购物袋可展开并二次确认清空', (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byKey(const ValueKey('ordering-cart-bag')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ordering-cart-sheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ordering-cart-select-all')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('ordering-clear-cart')));
    await tester.pumpAndSettle();
    expect(find.text('清空购物袋？'), findsOneWidget);
    expect(find.text('只会清理当前门店和桌位的已选商品。'), findsOneWidget);
    expect(find.textContaining('Fake'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ordering-clear-confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('合计 ¥ 0.00'), findsOneWidget);
  });

  testWidgets('搜索会过滤当前目录', (tester) async {
    await tester.pumpWidget(subject());
    await tester.enterText(
      find.byKey(const ValueKey('ordering-search')),
      '芝华士',
    );
    await tester.pump();

    expect(find.text('芝华士12年'), findsOneWidget);
    expect(find.text('轩尼诗XO'), findsNothing);
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
