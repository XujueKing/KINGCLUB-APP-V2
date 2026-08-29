import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/payment_security_page.dart';

Widget _frame(
  PaymentSecurityScenario scenario, {
  VoidCallback? onSessionResetRequested,
}) {
  return MaterialApp(
    home: PaymentSecurityPage(
      initialScenario: scenario,
      onSessionResetRequested: onSessionResetRequested,
    ),
  );
}

Future<void> _submit(
  WidgetTester tester,
  String inputKey,
  String submitKey,
  String value,
) async {
  await tester.enterText(find.byKey(ValueKey(inputKey)), value);
  await tester.tap(find.byKey(ValueKey(submitKey)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('set status verifies old PIN and changes successfully', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(PaymentSecurityScenario.statusSet));
    expect(find.text('支付 PIN 已设置'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payment-pin-change')));
    await tester.pumpAndSettle();
    await _submit(
      tester,
      'payment-pin-input-old',
      'payment-pin-submit-old',
      '246801',
    );
    await _submit(
      tester,
      'payment-pin-input-new',
      'payment-pin-submit-new',
      '246810',
    );
    await _submit(
      tester,
      'payment-pin-input-confirm',
      'payment-pin-submit-confirm',
      '246810',
    );
    expect(find.byKey(const ValueKey('payment-pin-success')), findsOneWidget);
    expect(find.text('新的支付 PIN 已生效，请妥善保管。'), findsOneWidget);
    expect(find.textContaining('Mock'), findsNothing);
  });

  testWidgets('not-set status requires fake SMS verification first', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(PaymentSecurityScenario.statusNotSet));
    expect(find.text('支付 PIN 未设置'), findsOneWidget);
    expect(find.text('设置支付 PIN'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payment-pin-change')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payment-pin-sms')), findsOneWidget);
    await _submit(
      tester,
      'payment-pin-input-sms',
      'payment-pin-submit-sms',
      '888888',
    );
    expect(find.byKey(const ValueKey('payment-pin-new')), findsOneWidget);
  });

  testWidgets('wrong old PIN shows safe remaining count and stays put', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(PaymentSecurityScenario.wrongOldPin));
    await tester.tap(find.byKey(const ValueKey('payment-pin-change')));
    await tester.pumpAndSettle();
    await _submit(
      tester,
      'payment-pin-input-old',
      'payment-pin-submit-old',
      '111222',
    );
    expect(find.text('原 PIN 错误，还可尝试 2 次'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-pin-old')), findsOneWidget);
  });

  testWidgets('locked status blocks all PIN operations', (tester) async {
    await tester.pumpWidget(_frame(PaymentSecurityScenario.locked));
    expect(find.text('支付 PIN 已锁定'), findsOneWidget);
    expect(find.text('暂时无法操作'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('payment-pin-change')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('payment-pin-forgot')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('simple and mismatching new PINs are rejected locally', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(PaymentSecurityScenario.statusSet));
    await tester.tap(find.byKey(const ValueKey('payment-pin-forgot')));
    await tester.pumpAndSettle();
    await _submit(
      tester,
      'payment-pin-input-sms',
      'payment-pin-submit-sms',
      '888888',
    );
    await _submit(
      tester,
      'payment-pin-input-new',
      'payment-pin-submit-new',
      '123456',
    );
    expect(find.text('PIN 过于简单，请重新设置'), findsOneWidget);
    await _submit(
      tester,
      'payment-pin-input-new',
      'payment-pin-submit-new',
      '246810',
    );
    await _submit(
      tester,
      'payment-pin-input-confirm',
      'payment-pin-submit-confirm',
      '135790',
    );
    expect(find.text('两次输入不一致，请重新输入'), findsOneWidget);
  });

  testWidgets('unknown result clears input and forbids duplicate submit', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(PaymentSecurityScenario.resultUnknown));
    await tester.tap(find.byKey(const ValueKey('payment-pin-forgot')));
    await tester.pumpAndSettle();
    await _submit(
      tester,
      'payment-pin-input-sms',
      'payment-pin-submit-sms',
      '888888',
    );
    await _submit(
      tester,
      'payment-pin-input-new',
      'payment-pin-submit-new',
      '246810',
    );
    await _submit(
      tester,
      'payment-pin-input-confirm',
      'payment-pin-submit-confirm',
      '246810',
    );
    expect(
      find.byKey(const ValueKey('payment-pin-result-unknown')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('请勿重复设置'), findsOneWidget);
  });

  testWidgets('background transition clears sensitive input', (tester) async {
    await tester.pumpWidget(_frame(PaymentSecurityScenario.statusSet));
    await tester.tap(find.byKey(const ValueKey('payment-pin-change')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('payment-pin-input-old')),
      '246801',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('payment-pin-input-old')),
          )
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('session invalid clears input and requests auth reset', (
    tester,
  ) async {
    var resetCount = 0;
    await tester.pumpWidget(
      _frame(
        PaymentSecurityScenario.sessionInvalid,
        onSessionResetRequested: () => resetCount++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payment-session-dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('payment-session-confirm')));
    await tester.pumpAndSettle();
    expect(resetCount, 1);
  });
}
