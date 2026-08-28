import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/account_deletion_page.dart';

Widget _frame(
  AccountDeletionScenario scenario, {
  VoidCallback? onCompleted,
  VoidCallback? onSessionResetRequested,
}) {
  return MaterialApp(
    home: AccountDeletionPage(
      initialScenario: scenario,
      onCompleted: onCompleted,
      onSessionResetRequested: onSessionResetRequested,
    ),
  );
}

Future<void> _acknowledgeAndStart(WidgetTester tester) async {
  final ack = find.byKey(const ValueKey('account-deletion-ack'));
  await tester.scrollUntilVisible(ack, 260);
  await tester.tap(ack);
  await tester.pump();
  final start = find.byKey(const ValueKey('account-deletion-start'));
  await tester.scrollUntilVisible(start, 180);
  await tester.tap(start);
  await tester.pumpAndSettle();
}

Future<void> _verifySmsAndConfirm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('account-deletion-sms-input')),
    '888888',
  );
  await tester.tap(find.text('验证'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('account-deletion-confirm-input')),
    '永久注销',
  );
  await tester.tap(find.text('确认永久注销'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('eligible flow completes only after two explicit confirmations', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      _frame(
        AccountDeletionScenario.eligible,
        onCompleted: () => completed = true,
      ),
    );
    expect(find.textContaining('物业账号、物业数据及共享身份不受影响'), findsOne);
    final start = find.byKey(const ValueKey('account-deletion-start'));
    await tester.scrollUntilVisible(start, 260);
    expect(tester.widget<FilledButton>(start).onPressed, isNull);

    await _acknowledgeAndStart(tester);
    await _verifySmsAndConfirm(tester);
    expect(
      find.byKey(const ValueKey('account-deletion-completed')),
      findsOneWidget,
    );
    expect(completed, isFalse);
    await tester.tap(
      find.byKey(const ValueKey('account-deletion-completed-exit')),
    );
    expect(completed, isTrue);
  });

  testWidgets('open order blocker disables deletion and exposes safe intent', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(AccountDeletionScenario.openOrderBlocker));
    expect(find.text('有 1 笔待处理'), findsNothing);
    final blocker = find.byKey(
      const ValueKey('account-deletion-blocker-去处理订单'),
    );
    await tester.scrollUntilVisible(blocker, 220);
    expect(blocker, findsOneWidget);
    await tester.tap(blocker);
    await tester.pump();
    expect(find.textContaining('仅传受控业务引用'), findsOneWidget);
    final ackFinder = find.byKey(const ValueKey('account-deletion-ack'));
    await tester.scrollUntilVisible(ackFinder, 220);
    expect(tester.widget<CheckboxListTile>(ackFinder).onChanged, isNull);
  });

  testWidgets('asset and storage blockers are both actionable', (tester) async {
    await tester.pumpWidget(
      _frame(AccountDeletionScenario.assetStorageBlocker),
    );
    for (final action in <String>['去处理资产', '去处理储物']) {
      final finder = find.byKey(ValueKey('account-deletion-blocker-$action'));
      await tester.scrollUntilVisible(finder, 160);
      expect(finder, findsOneWidget);
    }
  });

  testWidgets('expired SMS challenge cannot advance', (tester) async {
    await tester.pumpWidget(_frame(AccountDeletionScenario.smsExpired));
    await _acknowledgeAndStart(tester);
    await tester.enterText(
      find.byKey(const ValueKey('account-deletion-sms-input')),
      '888888',
    );
    await tester.tap(find.text('验证'));
    await tester.pump();
    expect(find.text('验证码已过期，请重新获取'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-deletion-confirm-input')),
      findsNothing,
    );
  });

  testWidgets('unknown result never claims deletion success', (tester) async {
    await tester.pumpWidget(_frame(AccountDeletionScenario.resultUnknown));
    await _acknowledgeAndStart(tester);
    await _verifySmsAndConfirm(tester);
    expect(
      find.byKey(const ValueKey('account-deletion-result-unknown')),
      findsOneWidget,
    );
    expect(find.textContaining('请勿重复提交'), findsOneWidget);
    expect(find.text('Fake 注销流程已完成'), findsNothing);
  });

  testWidgets('changed eligibility requires preflight again', (tester) async {
    await tester.pumpWidget(_frame(AccountDeletionScenario.stateChanged));
    expect(
      find.byKey(const ValueKey('account-deletion-state-changed')),
      findsOneWidget,
    );
    final ackFinder = find.byKey(const ValueKey('account-deletion-ack'));
    await tester.scrollUntilVisible(ackFinder, 260);
    final ack = tester.widget<CheckboxListTile>(ackFinder);
    expect(ack.onChanged, isNull);
  });

  testWidgets('session invalid requests a single safe reset', (tester) async {
    var resetCount = 0;
    await tester.pumpWidget(
      _frame(
        AccountDeletionScenario.sessionInvalid,
        onSessionResetRequested: () => resetCount++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('deletion-session-dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('deletion-session-confirm')));
    await tester.pumpAndSettle();
    expect(resetCount, 1);
  });
}
