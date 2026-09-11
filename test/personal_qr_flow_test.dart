import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/personal_qr_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

Widget _frame(
  PersonalQrScenario scenario, {
  VoidCallback? onBack,
  VoidCallback? onSessionResetRequested,
}) {
  return MaterialApp(
    home: PersonalQrPage(
      initialScenario: scenario,
      onBack: onBack,
      onSessionResetRequested: onSessionResetRequested,
    ),
  );
}

void main() {
  testWidgets('ready state reproduces the permanent mini-program QR', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(PersonalQrScenario.ready));

    expect(find.text('我的二维码'), findsOneWidget);
    expect(find.text('杨嘉琪'), findsNothing);
    expect(find.text('K45600000799'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('扫一扫上面的二维码图案，加我成为朋友'), findsOneWidget);
    expect(find.textContaining('有效期'), findsNothing);
    expect(find.textContaining('过期'), findsNothing);
    expect(find.textContaining('刷新'), findsNothing);
    expect(find.textContaining('隐藏'), findsNothing);

    final avatar = tester.getRect(
      find.byKey(const ValueKey('personal-qr-avatar')),
    );
    final canvas = tester.getRect(
      find.byKey(const ValueKey('personal-qr-code')),
    );
    final qrImage = tester.getRect(
      find.byKey(const ValueKey('personal-qr-image')),
    );
    final viewportWidth = MediaQuery.sizeOf(
      tester.element(find.byKey(const ValueKey('personal-qr-code'))),
    ).width;
    expect(canvas.width, closeTo(viewportWidth * 500 / 750, 0.5));
    expect(qrImage.width, closeTo(viewportWidth * 412 / 750, 0.5));
    expect(canvas.top - avatar.bottom, closeTo(viewportWidth * 40 / 750, 0.5));
  });

  testWidgets('QR payload stays stable across lifecycle changes', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(PersonalQrScenario.ready));
    final before = tester.widget<QrImageView>(find.byType(QrImageView)).key;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    final after = tester.widget<QrImageView>(find.byType(QrImageView)).key;
    expect(after, before);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('legacy expiry scenarios no longer change the permanent page', (
    tester,
  ) async {
    for (final scenario in const [
      PersonalQrScenario.nearlyExpired,
      PersonalQrScenario.expired,
      PersonalQrScenario.offline,
      PersonalQrScenario.issueError,
      PersonalQrScenario.refreshError,
      PersonalQrScenario.delayedIssue,
    ]) {
      await tester.pumpWidget(_frame(scenario));
      expect(find.byType(QrImageView), findsOneWidget, reason: scenario.name);
      expect(find.textContaining('刷新'), findsNothing, reason: scenario.name);
      expect(find.textContaining('过期'), findsNothing, reason: scenario.name);
    }
  });

  testWidgets('back delegates to the profile route', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(
      _frame(PersonalQrScenario.ready, onBack: () => backCount++),
    );

    await tester.tap(find.byKey(const ValueKey('personal-qr-back')));
    expect(backCount, 1);
  });

  testWidgets('session invalid hides the page and requests auth reset', (
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
