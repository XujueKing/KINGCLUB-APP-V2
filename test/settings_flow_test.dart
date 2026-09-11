import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/settings_page.dart';

Widget _frame(
  SettingsScenario scenario, {
  VoidCallback? onLogoutCompleted,
  VoidCallback? onSessionResetRequested,
  VoidCallback? onOpenPersonalInfo,
  VoidCallback? onOpenPaymentSecurity,
  VoidCallback? onOpenPrivacyPolicy,
  VoidCallback? onOpenUserAgreement,
  VoidCallback? onOpenAboutLegal,
}) {
  return MaterialApp(
    home: SettingsPage(
      initialScenario: scenario,
      onLogoutCompleted: onLogoutCompleted,
      onSessionResetRequested: onSessionResetRequested,
      onOpenPersonalInfo: onOpenPersonalInfo,
      onOpenPaymentSecurity: onOpenPaymentSecurity,
      onOpenPrivacyPolicy: onOpenPrivacyPolicy,
      onOpenUserAgreement: onOpenUserAgreement,
      onOpenAboutLegal: onOpenAboutLegal,
    ),
  );
}

void main() {
  const entries = <String>[
    'personal-info',
    'account-security',
    'privacy-policy',
    'user-agreement',
    'about-kingbar',
  ];

  testWidgets('normal settings reproduces the five mini-program rows', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(SettingsScenario.normal));

    for (final key in entries) {
      expect(find.byKey(ValueKey('settings-$key')), findsOneWidget);
      expect(find.byKey(ValueKey('settings-arrow-$key')), findsOneWidget);
    }
    for (final label in const ['个人信息', '账号安全', '隐私政策', '用户协议', '关于KINGBAR']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('通知权限'), findsNothing);
    expect(find.text('清理缓存'), findsNothing);
  });

  testWidgets('all five rows emit their fixed destination intents', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      _frame(
        SettingsScenario.normal,
        onOpenPersonalInfo: () => opened.add('personal-info'),
        onOpenPaymentSecurity: () => opened.add('account-security'),
        onOpenPrivacyPolicy: () => opened.add('privacy-policy'),
        onOpenUserAgreement: () => opened.add('user-agreement'),
        onOpenAboutLegal: () => opened.add('about-kingbar'),
      ),
    );

    for (final key in entries) {
      final row = find.byKey(ValueKey('settings-$key'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
    }
    expect(opened, entries);
  });

  testWidgets('capability failure keeps every fixed row usable', (
    tester,
  ) async {
    var securityOpened = false;
    await tester.pumpWidget(
      _frame(
        SettingsScenario.capabilityFailure,
        onOpenPaymentSecurity: () => securityOpened = true,
      ),
    );

    expect(
      find.byKey(const ValueKey('settings-capability-failure')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-personal-info')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('settings-account-security')));
    expect(securityOpened, isTrue);
  });

  testWidgets('privacy and agreement open their direct reader states', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(SettingsScenario.normal));

    await tester.tap(find.byKey(const ValueKey('settings-privacy-policy')));
    await tester.pumpAndSettle();
    expect(find.text('KingClub 隐私政策'), findsWidgets);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-user-agreement')));
    await tester.pumpAndSettle();
    expect(find.text('KING CLUB 会员服务协议'), findsWidgets);
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
    final logout = find.byKey(const ValueKey('settings-logout'));
    await tester.ensureVisible(logout);
    await tester.pumpAndSettle();
    await tester.tap(logout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('注销登录').last);
    await tester.pump();

    expect(completed, isTrue);
    expect(find.text('已退出登录'), findsOneWidget);
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
    final logout = find.byKey(const ValueKey('settings-logout'));
    await tester.ensureVisible(logout);
    await tester.pumpAndSettle();
    await tester.tap(logout);
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
