import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kingclub/src/features/club/data/together_play.dart';
import 'package:kingclub/src/features/club/presentation/together_ticket_page.dart';

import 'together_play_test.dart' show fixture;

void main() {
  testWidgets(
    'selected ticket uses its own table, date, seats and credential',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final party = fixture(
        state: TogetherJoinState.joined,
        assignedTable: 'V15',
        ticketNumber: 'TEST-0002',
        admissionCode: 'TEST-ONLY-0002',
        day: 3,
        capacity: 14,
      );
      await tester.pumpWidget(
        MaterialApp(home: TogetherTicketPage(party: party)),
      );
      await tester.pumpAndSettle();
      expect(find.text('V15'), findsOneWidget);
      expect(find.text('2026-10-03 21:00–02:00'), findsOneWidget);
      expect(find.text('TEST-0002'), findsOneWidget);
      expect(find.text(party.theme), findsOneWidget);
      expect(find.text(party.storeName), findsOneWidget);
      expect(find.textContaining('票价'), findsNothing);
      expect(
        tester.widget<QrImageView>(find.byType(QrImageView)).semanticsLabel,
        '${party.theme}入场二维码',
      );
      for (var i = 0; i < 14; i++) {
        expect(find.byKey(ValueKey('seat-night-$i')), findsOneWidget);
      }
      expect(
        tester
            .getSize(find.byKey(const ValueKey('together-ticket-sheet')))
            .width,
        closeTo(402 * 690 / 750, .1),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('together-ticket-qr-frame')))
            .width,
        closeTo(402 * 440 / 750, .1),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('入场码已遮盖'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('入场须知'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('入场须知').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unpaid, missing or used credentials do not produce a QR', (
    tester,
  ) async {
    for (final party in [
      fixture(admissionCode: 'not-paid'),
      fixture(state: TogetherJoinState.joined),
      fixture(
        state: TogetherJoinState.joined,
        admissionCode: 'used-code',
        admissionUsed: true,
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(home: TogetherTicketPage(party: party)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(
        find.text(party.admissionUsed ? '已入场' : '入场码暂不可用'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
