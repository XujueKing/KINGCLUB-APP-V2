import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/order_center_page.dart';
import 'package:kingclub/src/features/commerce/presentation/payment_result_page.dart';

void main() {
  Widget subject({
    PaymentResultScenario scenario = PaymentResultScenario.normalSuccess,
    ValueChanged<FakePaymentAttemptRef>? onAttemptCreated,
    ValueChanged<FakeOrderRef>? onOpenOrder,
    VoidCallback? onSessionResetRequested,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: PaymentResultPage(
        intentRef: const FakePaymentIntentRef(
          'payment-intent-order-scan-v8-0827',
        ),
        onClose: () {},
        initialScenario: scenario,
        onAttemptCreated: onAttemptCreated,
        onOpenOrder: onOpenOrder,
        onSessionResetRequested: onSessionResetRequested,
      ),
    );
  }

  Future<void> finishProviderFlow(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('准备态展示 Fake 权威金额和服务端方式列表', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('¥1156.00'), findsOneWidget);
    expect(find.text('微信支付'), findsOneWidget);
    expect(find.text('余额支付'), findsOneWidget);
    expect(find.text('服务端未开放此方式'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-confirm')), findsOneWidget);
  });

  testWidgets('快速重复点击只创建一个 Fake attempt', (tester) async {
    final attempts = <FakePaymentAttemptRef>[];
    await tester.pumpWidget(subject(onAttemptCreated: attempts.add));

    final button = find.byKey(const ValueKey('payment-confirm'));
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();

    expect(attempts, hasLength(1));
    expect(attempts.single.opaqueId, contains('attempt-payment-intent'));
    await finishProviderFlow(tester);
  });

  testWidgets('provider success 仍经验证后显示服务端已确认', (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byKey(const ValueKey('payment-confirm')));
    await finishProviderFlow(tester);

    expect(find.text('支付已确认'), findsOneWidget);
    expect(find.textContaining('Fake 服务端已确认'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-view-order')), findsOneWidget);
  });

  testWidgets('provider success 但服务端 pending 不显示成功', (tester) async {
    await tester.pumpWidget(
      subject(scenario: PaymentResultScenario.providerSuccessPending),
    );
    await tester.tap(find.byKey(const ValueKey('payment-confirm')));
    await finishProviderFlow(tester);

    expect(find.text('支付结果待确认'), findsOneWidget);
    expect(find.text('支付已确认'), findsNothing);
    expect(find.byKey(const ValueKey('payment-reconcile')), findsOneWidget);
  });

  testWidgets('provider cancel 保留待支付订单出口', (tester) async {
    FakeOrderRef? opened;
    await tester.pumpWidget(
      subject(
        scenario: PaymentResultScenario.providerCancelled,
        onOpenOrder: (value) => opened = value,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('payment-confirm')));
    await finishProviderFlow(tester);

    expect(find.text('本次支付已取消'), findsOneWidget);
    expect(find.textContaining('订单仍保持待支付'), findsOneWidget);
    await tester.tap(find.text('稍后支付'));
    expect(opened?.opaqueId, 'order-scan-v8-0827');
  });

  testWidgets('明确失败后安全重试回到新意图准备态', (tester) async {
    await tester.pumpWidget(
      subject(scenario: PaymentResultScenario.providerFailed),
    );
    await tester.tap(find.byKey(const ValueKey('payment-confirm')));
    await finishProviderFlow(tester);

    expect(find.text('支付未完成'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payment-safe-retry')));
    await tester.pump();
    expect(find.byKey(const ValueKey('payment-confirm')), findsOneWidget);
  });

  testWidgets('晚到成功只通过原 attempt 查询收敛', (tester) async {
    await tester.pumpWidget(
      subject(scenario: PaymentResultScenario.lateSuccess),
    );
    await tester.tap(find.byKey(const ValueKey('payment-confirm')));
    await finishProviderFlow(tester);
    expect(find.text('支付结果待确认'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('payment-reconcile')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('支付已确认'), findsOneWidget);
  });

  testWidgets('过期意图禁止创建 attempt', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      subject(
        scenario: PaymentResultScenario.expiredIntent,
        onAttemptCreated: (_) => attempts += 1,
      ),
    );

    expect(find.text('支付意图已过期'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-confirm')), findsNothing);
    expect(attempts, 0);
  });

  testWidgets('离线恢复前不创建 attempt', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      subject(
        scenario: PaymentResultScenario.offline,
        onAttemptCreated: (_) => attempts += 1,
      ),
    );

    expect(find.text('当前网络不可用'), findsOneWidget);
    expect(attempts, 0);
    await tester.tap(find.byKey(const ValueKey('payment-recover-network')));
    await tester.pump();
    expect(find.byKey(const ValueKey('payment-confirm')), findsOneWidget);
  });

  testWidgets('不可用方式更新后确认按钮被禁用', (tester) async {
    await tester.pumpWidget(
      subject(scenario: PaymentResultScenario.methodUnavailable),
    );

    expect(find.text('当前暂不可用'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('payment-confirm')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('0 元订单不创建 attempt 直接查询确认', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      subject(
        scenario: PaymentResultScenario.zeroAmount,
        onAttemptCreated: (_) => attempts += 1,
      ),
    );

    expect(find.text('¥0.00'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-methods')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('payment-confirm')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('支付已确认'), findsOneWidget);
    expect(attempts, 0);
  });

  testWidgets('会话失效清理引用并请求登录重置', (tester) async {
    var reset = false;
    await tester.pumpWidget(
      subject(
        scenario: PaymentResultScenario.sessionInvalid,
        onSessionResetRequested: () => reset = true,
      ),
    );

    expect(find.text('会话已失效'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-confirm')), findsNothing);
    await tester.tap(find.text('重新登录'));
    expect(reset, isTrue);
  });
}
