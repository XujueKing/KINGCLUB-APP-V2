import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/order_center_page.dart';

void main() {
  Widget subject({
    ValueChanged<FakeOrderRef>? onOpenOrder,
    OrderCenterScenario initialScenario = OrderCenterScenario.content,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: OrderCenterPage(
        onBack: () {},
        onOpenOrder: onOpenOrder,
        initialScenario: initialScenario,
      ),
    );
  }

  testWidgets('统一展示 AA、VIP 和扫码点单订单', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('我的订单'), findsOneWidget);
    expect(find.text('扫码点单'), findsNWidgets(2));
    expect(find.text('VIP组局'), findsOneWidget);
    expect(find.text('一起玩AA'), findsOneWidget);
    expect(find.text('待支付'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('order-center-list')), findsOneWidget);
  });

  testWidgets('筛选只保留对应状态族', (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(
      find.byKey(const ValueKey('order-filter-awaitingPayment')),
    );
    await tester.pump();

    expect(find.text('KINGBAR V8 桌点单'), findsOneWidget);
    expect(find.text('A6 卡座搭子局'), findsNothing);
    expect(find.text('星光香槟套餐'), findsNothing);
  });

  testWidgets('列表只向详情传递不透明 OrderRef', (tester) async {
    FakeOrderRef? opened;
    await tester.pumpWidget(subject(onOpenOrder: (value) => opened = value));

    await tester.tap(
      find.byKey(const ValueKey('order-card-order-scan-v8-0827')),
    );
    expect(opened?.opaqueId, 'order-scan-v8-0827');
  });

  testWidgets('游标加载追加不重复订单并到达末页', (tester) async {
    await tester.pumpWidget(subject());
    await tester.drag(
      find.byKey(const ValueKey('order-center-list')),
      const Offset(0, -1200),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('C3 夏日音乐局'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('周末微醉套餐'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('周末微醉套餐'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-end-reached')), findsOneWidget);
  });

  testWidgets('离线缓存保留列表并标记只读', (tester) async {
    await tester.pumpWidget(
      subject(initialScenario: OrderCenterScenario.offlineCached),
    );

    expect(find.byKey(const ValueKey('order-center-banner')), findsOneWidget);
    expect(find.textContaining('更新于 20:12'), findsOneWidget);
    expect(find.text('KINGBAR V8 桌点单'), findsOneWidget);
  });

  testWidgets('未知状态订单不被丢弃', (tester) async {
    await tester.pumpWidget(
      subject(initialScenario: OrderCenterScenario.unknownStatus),
    );

    expect(find.text('KINGBAR 桌台消费'), findsOneWidget);
    expect(find.text('状态更新中'), findsOneWidget);
  });

  testWidgets('下拉刷新权威替换首屏状态', (tester) async {
    await tester.pumpWidget(subject());
    unawaited(
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('支付确认中'), findsOneWidget);
  });
}
