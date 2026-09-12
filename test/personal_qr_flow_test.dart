import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/personal_qr_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

Widget _frame(
  PersonalQrScenario scenario, {
  Duration tickInterval = const Duration(seconds: 1),
  VoidCallback? onSessionResetRequested,
}) {
  return MaterialApp(
    home: PersonalQrPage(
      initialScenario: scenario,
      tickInterval: tickInterval,
      onSessionResetRequested: onSessionResetRequested,
    ),
  );
}

void main() {
  testWidgets('ready state exposes only a short-lived mock QR', (tester) async {
    await tester.pumpWidget(_frame(PersonalQrScenario.ready));

    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      tester.widget<QrImageView>(find.byType(QrImageView)).key,
      isA<ValueKey<String>>(),
    );
    expect(find.text('杨嘉琪'), findsOneWidget);
    expect(find.text('KingClub 好友邀请'), findsOneWidget);
    expect(find.textContaining('K456'), findsNothing);
    expect(find.textContaining('手机号'), findsOneWidget);
    expect(find.textContaining('保存'), findsNothing);
    expect(find.textContaining('分享'), findsNothing);
    expect(find.textContaining('复制'), findsNothing);
  });

  testWidgets('refresh destroys old QR immediately and issues a new one', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(PersonalQrScenario.ready));
    final oldKey = tester.widget<QrImageView>(find.byType(QrImageView)).key;

    await tester.tap(find.byKey(const ValueKey('personal-qr-refresh')));
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('正在刷新二维码'), findsWidgets);

    // A second tap cannot create a second request because the action is gone.
    expect(find.byKey(const ValueKey('personal-qr-refresh')), findsNothing);
    await tester.pump(const Duration(milliseconds: 430));
    final newKey = tester.widget<QrImageView>(find.byType(QrImageView)).key;
    expect(newKey, isNot(oldKey));
  });

  testWidgets('refresh failure never restores the old QR', (tester) async {
    await tester.pumpWidget(_frame(PersonalQrScenario.refreshError));
    expect(find.byType(QrImageView), findsNothing);

    await tester.tap(find.byKey(const ValueKey('personal-qr-refresh')));
    await tester.pump(const Duration(milliseconds: 430));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('二维码生成失败'), findsWidgets);
    expect(find.textContaining('不会恢复'), findsOneWidget);
  });

  testWidgets('expired offline and initial error states never show a QR', (
    tester,
  ) async {
    for (final scenario in <PersonalQrScenario>[
      PersonalQrScenario.expired,
      PersonalQrScenario.offline,
      PersonalQrScenario.issueError,
    ]) {
      await tester.pumpWidget(_frame(scenario));
      expect(find.byType(QrImageView), findsNothing, reason: scenario.name);
    }
  });

  testWidgets('background hides QR and resume creates a fresh QR', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(PersonalQrScenario.ready));
    final oldKey = tester.widget<QrImageView>(find.byType(QrImageView)).key;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('二维码已隐藏'), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    await tester.pump(const Duration(milliseconds: 430));
    final newKey = tester.widget<QrImageView>(find.byType(QrImageView)).key;
    expect(newKey, isNot(oldKey));
  });

  testWidgets('countdown expires and removes the scannable QR', (tester) async {
    await tester.pumpWidget(
      _frame(
        PersonalQrScenario.nearlyExpired,
        tickInterval: const Duration(milliseconds: 1),
      ),
    );
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('二维码已过期'), findsWidgets);
  });

  testWidgets('late issue response is ignored after scenario switch', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(PersonalQrScenario.delayedIssue));
    expect(find.byType(QrImageView), findsNothing);

    await tester.longPress(find.byKey(const ValueKey('personal-qr-title')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('personal-qr-scenario-offline')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('当前无法联网'), findsWidgets);
  });

  testWidgets('session invalid clears state and requests auth reset', (
    tester,
  ) async {
    var resetRequested = false;
    await tester.pumpWidget(
      _frame(
        PersonalQrScenario.sessionInvalid,
        onSessionResetRequested: () => resetRequested = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsNothing);
    expect(find.byKey(const ValueKey('personal-qr-session-dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('personal-qr-session-confirm')));
    await tester.pumpAndSettle();
    expect(resetRequested, isTrue);
  });

  testWidgets('large text remains scrollable without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: _frame(PersonalQrScenario.ready),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
