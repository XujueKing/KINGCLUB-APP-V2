import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/order_center_page.dart';

void main() {
  Widget subject({
    ValueChanged<FakeOrderRef>? onOpenOrder,
    VoidCallback? onOpenHome,
    VoidCallback? onSessionResetRequested,
    OrderCenterScenario initialScenario = OrderCenterScenario.content,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: OrderCenterPage(
        onBack: () {},
        onOpenOrder: onOpenOrder,
        onOpenHome: onOpenHome,
        onSessionResetRequested: onSessionResetRequested,
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
    expect(find.text('KINGBAR 湖南工大店'), findsOneWidget);
    expect(find.text('888号桌 · 轩尼诗XO、芝华士12年'), findsOneWidget);
    expect(find.text('¥3680'), findsOneWidget);
    expect(find.text('进行中'), findsNWidgets(2));
    expect(find.text('KING CLUB AA预订'), findsOneWidget);
    expect(find.text('08月29日 20:30 · V5卡座 · 3880卡座套餐'), findsOneWidget);
    expect(find.text('¥268'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-center-list')), findsOneWidget);
    expect(find.textContaining('Fake'), findsNothing);
    expect(find.textContaining('Mock'), findsNothing);
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
      find.byKey(const ValueKey('order-card-order-scan-888-paid-0829')),
    );
    expect(opened?.opaqueId, 'order-scan-888-paid-0829');
  });

  testWidgets('V5 AA 已确认订单置顶并打开同一详情引用', (tester) async {
    FakeOrderRef? opened;
    await tester.pumpWidget(subject(onOpenOrder: (value) => opened = value));

    final aaCard = find.byKey(
      const ValueKey('order-card-order-aa-v5-paid-r0-0829'),
    );
    final scanCard = find.byKey(
      const ValueKey('order-card-order-scan-888-paid-0829'),
    );
    expect(
      tester.getTopLeft(aaCard).dy,
      lessThan(tester.getTopLeft(scanCard).dy),
    );
    await tester.tap(aaCard);
    expect(opened?.opaqueId, 'order-aa-v5-paid-r0-0829');
  });

  testWidgets('V5 AA 已确认订单只归入进行中状态族', (tester) async {
    await tester.pumpWidget(subject());

    await tester.tap(find.byKey(const ValueKey('order-filter-active')));
    await tester.pump();
    expect(find.text('KING CLUB AA预订'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('order-filter-awaitingPayment')),
    );
    await tester.pump();
    expect(find.text('KING CLUB AA预订'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('order-filter-completedAndAfterSales')),
    );
    await tester.pump();
    expect(find.text('KING CLUB AA预订'), findsNothing);
  });

  testWidgets('888 号桌已支付订单归入进行中而非待支付', (tester) async {
    await tester.pumpWidget(subject());

    await tester.tap(find.byKey(const ValueKey('order-filter-active')));
    await tester.pump();
    expect(find.text('KINGBAR 湖南工大店'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('order-filter-awaitingPayment')),
    );
    await tester.pump();
    expect(find.text('KINGBAR 湖南工大店'), findsNothing);
    expect(find.text('KINGBAR V8 桌点单'), findsOneWidget);
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

  testWidgets('全部为空可通过正式入口返回首页', (tester) async {
    var openedHome = false;
    await tester.pumpWidget(
      subject(
        initialScenario: OrderCenterScenario.emptyAll,
        onOpenHome: () => openedHome = true,
      ),
    );

    expect(find.text('还没有订单'), findsOneWidget);
    await tester.tap(find.text('返回首页'));
    expect(openedHome, isTrue);
  });

  testWidgets('首屏失败可重试并恢复订单列表', (tester) async {
    await tester.pumpWidget(
      subject(initialScenario: OrderCenterScenario.error),
    );

    expect(find.text('暂时无法加载订单'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(find.text('KINGBAR V8 桌点单'), findsOneWidget);
  });

  testWidgets('会话失效清空列表并请求登录 reset', (tester) async {
    var resetRequested = false;
    await tester.pumpWidget(
      subject(
        initialScenario: OrderCenterScenario.sessionInvalid,
        onSessionResetRequested: () => resetRequested = true,
      ),
    );

    expect(find.text('会话已失效'), findsOneWidget);
    expect(find.text('KINGBAR V8 桌点单'), findsNothing);
    await tester.tap(find.text('重新登录'));
    expect(resetRequested, isTrue);
  });
}
