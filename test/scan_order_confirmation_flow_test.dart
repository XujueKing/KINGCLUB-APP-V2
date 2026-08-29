import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_order_confirmation_page.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';

void main() {
  const quote = FakeOrderingQuote(
    itemCount: 2,
    total: 1186,
    items: [
      FakeOrderingQuoteItem(
        name: '星光香槟',
        detail: '香槟 750ml',
        asset: 'assets/legacy/ordering/product_champagne_v1.png',
        quantity: 1,
        unitPrice: 688,
      ),
      FakeOrderingQuoteItem(
        name: '金标威士忌',
        detail: '威士忌 700ml',
        asset: 'assets/legacy/ordering/product_whisky_v1.png',
        quantity: 1,
        unitPrice: 498,
      ),
    ],
  );

  Widget subject({
    ValueChanged<FakeOrderCreatedIntent>? onOrderCreated,
    VoidCallback? onModify,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ScanOrderConfirmationPage(
        quote: quote,
        onBack: () {},
        onModify: onModify ?? () {},
        onOrderCreated: onOrderCreated,
      ),
    );
  }

  testWidgets('复刻旧版确认页且移除客户端资产分摊', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('提交订单'), findsNWidgets(2));
    expect(find.text('KINGBAR 湖南工大店'), findsOneWidget);
    expect(find.text('星光香槟'), findsOneWidget);
    expect(find.text('金标威士忌'), findsOneWidget);
    expect(find.text('应付金额'), findsOneWidget);
    expect(find.text('立即支付'), findsNothing);
    expect(find.textContaining('金币兑换'), findsNothing);
    expect(find.textContaining('余额（'), findsNothing);
    expect(find.textContaining('Fake'), findsNothing);
    expect(find.textContaining('QuoteRef'), findsNothing);
  });

  testWidgets('商品更多控制沿用旧版显示与隐藏文案', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('隐藏更多（共2件物品）'), findsOneWidget);
    expect(find.text('金标威士忌'), findsOneWidget);
    final firstItem = tester.widget<Container>(
      find.byKey(const ValueKey('order-item-星光香槟')),
    );
    final lastItem = tester.widget<Container>(
      find.byKey(const ValueKey('order-item-金标威士忌')),
    );
    expect(firstItem.decoration, isNotNull);
    expect(lastItem.decoration, isNull);

    await tester.tap(find.byKey(const ValueKey('order-toggle-items')));
    await tester.pump();

    expect(find.text('显示更多（共2件物品）'), findsOneWidget);
    expect(find.text('金标威士忌'), findsNothing);
    expect(
      tester
          .widget<Container>(find.byKey(const ValueKey('order-item-星光香槟')))
          .decoration,
      isNull,
    );
  });

  testWidgets('提交只生成一个 Fake 待支付订单意图', (tester) async {
    FakeOrderCreatedIntent? result;
    await tester.pumpWidget(subject(onOrderCreated: (value) => result = value));

    await tester.tap(find.byKey(const ValueKey('order-submit')));
    await tester.pump(const Duration(milliseconds: 650));

    expect(result?.orderRef, 'fake-order-v8-0827');
    expect(result?.amountDue, 1156);
  });

  testWidgets('价格变化需明确接受后才能提交', (tester) async {
    FakeOrderCreatedIntent? result;
    await tester.pumpWidget(subject(onOrderCreated: (value) => result = value));
    await tester.longPress(find.byKey(const ValueKey('legacy-club-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('价格变化'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quote-change-card')), findsOneWidget);
    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('order-submit')),
    );
    expect(submit.onPressed, isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('accept-quote-change')),
    );
    await tester.tap(find.byKey(const ValueKey('accept-quote-change')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('order-submit')));
    await tester.pump(const Duration(milliseconds: 650));
    expect(result?.amountDue, 1176);
  });

  testWidgets('结果未知只对账原提交', (tester) async {
    FakeOrderCreatedIntent? result;
    await tester.pumpWidget(subject(onOrderCreated: (value) => result = value));
    await tester.longPress(find.byKey(const ValueKey('legacy-club-title')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('提交结果未知'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('提交结果未知'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('order-status-banner')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('order-submit')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('order-reconcile')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(result?.orderRef, 'fake-order-v8-0827');
  });

  testWidgets('返回修改保留强类型出口', (tester) async {
    var modified = false;
    await tester.pumpWidget(subject(onModify: () => modified = true));
    await tester.tap(find.byTooltip('返回'));
    expect(modified, isTrue);
  });

  testWidgets('无路由回调时使用正式待支付结果文案', (tester) async {
    await tester.pumpWidget(subject());

    await tester.tap(find.byKey(const ValueKey('order-submit')));
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('待支付订单已创建'), findsOneWidget);
    expect(find.text('应付¥1156'), findsOneWidget);
    expect(find.text('订单已创建，请前往订单中心继续完成支付。'), findsOneWidget);
    expect(find.textContaining('fake-order'), findsNothing);
    expect(find.textContaining('Fake'), findsNothing);
  });
}
