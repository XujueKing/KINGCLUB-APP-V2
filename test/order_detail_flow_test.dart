import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/order_center_page.dart';
import 'package:kingclub/src/features/commerce/presentation/order_detail_page.dart';

void main() {
  Widget subject({
    FakeOrderRef orderRef = const FakeOrderRef('order-scan-v8-0827'),
    OrderDetailScenario? initialScenario,
    ValueChanged<String>? onPaymentIntent,
    ValueChanged<String>? onAdmission,
    VoidCallback? onSessionResetRequested,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: OrderDetailPage(
        orderRef: orderRef,
        onBack: () {},
        initialScenario: initialScenario,
        onPaymentIntent: onPaymentIntent,
        onAdmission: onAdmission,
        onSessionResetRequested: onSessionResetRequested,
      ),
    );
  }

  testWidgets('待支付详情展示旧版商品金额层级和安全动作', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('订单详情'), findsOneWidget);
    expect(find.text('KINGBAR V8 桌点单'), findsOneWidget);
    expect(find.text('星光香槟'), findsOneWidget);
    expect(find.text('金标威士忌'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('应付金额'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('¥1156'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-pay')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-cancel')), findsOneWidget);
  });

  testWidgets('继续支付只输出受控 Fake PaymentIntentRef', (tester) async {
    String? opened;
    await tester.pumpWidget(
      subject(onPaymentIntent: (value) => opened = value),
    );

    await tester.tap(find.byKey(const ValueKey('order-pay')));
    expect(opened, 'payment-intent-order-scan-v8-0827');
  });

  testWidgets('已确认订单从 OrderRef 映射并只输出 AdmissionRef', (tester) async {
    String? opened;
    await tester.pumpWidget(
      subject(
        orderRef: const FakeOrderRef('order-vip-a6-0828'),
        onAdmission: (value) => opened = value,
      ),
    );

    expect(find.text('已确认'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-pay')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('order-admission')));
    expect(opened, 'admission-order-vip-a6-0828');
  });

  testWidgets('离线缓存保留详情并移除写动作', (tester) async {
    await tester.pumpWidget(
      subject(initialScenario: OrderDetailScenario.offlineCached),
    );

    expect(find.textContaining('离线缓存'), findsOneWidget);
    expect(find.text('星光香槟'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-pay')), findsNothing);
    expect(find.byKey(const ValueKey('order-cancel')), findsNothing);
    expect(find.byKey(const ValueKey('order-refresh')), findsOneWidget);
  });

  testWidgets('无效引用使用统一安全错误而不泄露对象', (tester) async {
    await tester.pumpWidget(
      subject(initialScenario: OrderDetailScenario.invalidRef),
    );

    expect(find.text('无法查看此订单'), findsOneWidget);
    expect(find.textContaining('不存在、已失效或不属于'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-detail-products')), findsNothing);
  });

  testWidgets('取消需要二次确认并只更新本地 Fake 状态', (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byKey(const ValueKey('order-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('确认取消订单？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('order-cancel-confirm')));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('已取消'), findsOneWidget);
    expect(find.textContaining('未发生真实退款'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-pay')), findsNothing);
  });

  testWidgets('取消状态冲突后重读为已确认', (tester) async {
    await tester.pumpWidget(
      subject(initialScenario: OrderDetailScenario.cancelConflict),
    );
    await tester.tap(find.byKey(const ValueKey('order-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('order-cancel-confirm')));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('已确认'), findsOneWidget);
    expect(find.textContaining('本次取消未执行'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-admission')), findsOneWidget);
  });

  testWidgets('取消结果未知使用原 Fake 请求查询后收敛', (tester) async {
    await tester.pumpWidget(
      subject(initialScenario: OrderDetailScenario.cancelResultUnknown),
    );
    await tester.tap(find.byKey(const ValueKey('order-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('order-cancel-confirm')));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byKey(const ValueKey('order-reconcile-cancel')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('order-reconcile-cancel')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('已取消'), findsOneWidget);
  });

  testWidgets('会话失效清空详情并请求登录重置', (tester) async {
    var reset = false;
    await tester.pumpWidget(
      subject(
        initialScenario: OrderDetailScenario.sessionInvalid,
        onSessionResetRequested: () => reset = true,
      ),
    );

    expect(find.text('会话已失效'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-detail-products')), findsNothing);
    await tester.tap(find.text('重新登录'));
    expect(reset, isTrue);
  });
}
