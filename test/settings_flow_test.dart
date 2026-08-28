import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/settings_page.dart';

Widget _frame(
  SettingsScenario scenario, {
  VoidCallback? onLogoutCompleted,
  VoidCallback? onSessionResetRequested,
  VoidCallback? onOpenPaymentSecurity,
}) {
  return MaterialApp(
    home: SettingsPage(
      initialScenario: scenario,
      onLogoutCompleted: onLogoutCompleted,
      onSessionResetRequested: onSessionResetRequested,
      onOpenPaymentSecurity: onOpenPaymentSecurity,
    ),
  );
}

void main() {
  testWidgets('normal settings keeps all fixed safety entries', (tester) async {
    await tester.pumpWidget(_frame(SettingsScenario.normal));

    for (final key in <String>[
      'payment',
      'notification',
      'cache',
      'about',
      'deletion',
    ]) {
      expect(find.byKey(ValueKey('settings-$key')), findsOneWidget);
      expect(find.byKey(ValueKey('settings-arrow-$key')), findsOneWidget);
    }
  });

  testWidgets('capability failure keeps fixed entries usable', (tester) async {
    var paymentOpened = false;
    await tester.pumpWidget(
      _frame(
        SettingsScenario.capabilityFailure,
        onOpenPaymentSecurity: () => paymentOpened = true,
      ),
    );

    expect(
      find.byKey(const ValueKey('settings-capability-failure')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('settings-payment')));
    expect(paymentOpened, isTrue);
  });

  testWidgets('notification disabled directs only to fake system settings', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(SettingsScenario.notificationDisabled));
    expect(find.text('已关闭'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-notification')));
    await tester.pumpAndSettle();
    expect(find.text('系统通知：已关闭（Fake）'), findsOneWidget);
    await tester.tap(find.text('打开系统设置'));
    await tester.pumpAndSettle();
    expect(find.text('UI Mock：未打开真实系统设置'), findsOneWidget);
  });

  testWidgets('clear cache does not remove the session', (tester) async {
    await tester.pumpWidget(_frame(SettingsScenario.normal));
    await tester.tap(find.byKey(const ValueKey('settings-cache')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认清理'));
    await tester.pumpAndSettle();

    expect(find.text('0 B'), findsOneWidget);
    expect(find.text('Fake 缓存已清理'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-logout')), findsOneWidget);
  });

  testWidgets('logout success confirms then resets the local flow', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      _frame(
        SettingsScenario.normal,
        onLogoutCompleted: () => completed = true,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('settings-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('注销登录').last);
    await tester.pump();

    expect(completed, isTrue);
    expect(find.text('已完成 Fake 注销流程'), findsOneWidget);
  });

  testWidgets('unknown remote logout still performs local safe logout', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      _frame(
        SettingsScenario.logoutUnknown,
        onLogoutCompleted: () => completed = true,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('settings-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('注销登录').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-logout-unknown-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets('session invalid requests a single auth reset', (tester) async {
    var resetCount = 0;
    await tester.pumpWidget(
      _frame(
        SettingsScenario.sessionInvalid,
        onSessionResetRequested: () => resetCount++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-session-dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('settings-session-confirm')));
    await tester.pumpAndSettle();
    expect(resetCount, 1);
  });
}
