import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/admission_ticket_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('ready admission ticket keeps legacy card and dynamic QR', (
    tester,
  ) async {
    await _pumpTicket(tester);

    expect(find.text('POSITIONING CARD'), findsNWidgets(2));
    expect(find.text('VIP 区 V8'), findsOneWidget);
    expect(find.text('星光香槟套餐'), findsOneWidget);
    expect(find.text('当前可入场'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('后更新'), findsOneWidget);
    expect(find.textContaining('单人票价'), findsNothing);
  });

  testWidgets('A6 order admission ref restores the matching credential', (
    tester,
  ) async {
    await _pumpTicket(
      tester,
      admissionRef: const FakeAdmissionRef('admission-order-vip-a6-0828'),
    );

    expect(find.text('VIP 区 A6'), findsOneWidget);
    expect(find.text('08月28日 20:30 - 次日04:00'), findsOneWidget);
    expect(find.text('星光香槟套餐'), findsOneWidget);
    expect(find.text('VIP 区 V8'), findsNothing);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.key.toString(), contains('20260828-A6'));
    expect(qr.key.toString(), isNot(contains('20260827-V8')));
  });

  testWidgets('checked in state hides QR and shows the legacy stamp', (
    tester,
  ) async {
    await _pumpTicket(tester);
    await _selectScenario(tester, 'checkedIn');

    expect(find.byType(QrImageView), findsNothing);
    expect(
      find.byKey(const ValueKey('admission-checked-in-stamp')),
      findsOneWidget,
    );
    expect(find.textContaining('21:03 入场'), findsOneWidget);
  });

  testWidgets('exit requires confirmation then offers a fresh reentry code', (
    tester,
  ) async {
    await _pumpTicket(tester);
    await _selectScenario(tester, 'exitConfirmation');

    final exitButton = find.byKey(const ValueKey('confirm-ticket-exit'));
    await tester.ensureVisible(exitButton);
    await tester.pumpAndSettle();
    await tester.tap(exitButton);
    await tester.pumpAndSettle();
    expect(find.text('确认登记离场？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-ticket-exit-dialog')));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('已离场'), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket-reenter')), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ticket-reenter')));
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('当前可入场'), findsOneWidget);
  });

  testWidgets('offline ticket never exposes a reusable QR', (tester) async {
    await _pumpTicket(tester);
    await _selectScenario(tester, 'offline');

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('无法生成凭证'), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket-assistance')), findsOneWidget);
  });

  testWidgets('background transition covers and reissues the token', (
    tester,
  ) async {
    await _pumpTicket(tester);
    final firstQr = tester.widget<QrImageView>(find.byType(QrImageView));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('隐私保护中'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final secondQr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(secondQr.key, isNot(firstQr.key));
  });
}

Future<void> _pumpTicket(
  WidgetTester tester, {
  FakeAdmissionRef? admissionRef,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: KingTheme.dark,
      home: AdmissionTicketPage(admissionRef: admissionRef, onBack: () {}),
    ),
  );
}

Future<void> _selectScenario(WidgetTester tester, String scenario) async {
  await tester.longPress(find.byKey(const ValueKey('admission-ticket-title')));
  await tester.pumpAndSettle();
  final target = find.byKey(ValueKey('ticket-scenario-$scenario'));
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  tester.widget<ListTile>(target).onTap!();
  await tester.pumpAndSettle();
}
