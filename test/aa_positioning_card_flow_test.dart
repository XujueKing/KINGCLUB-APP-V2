import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/aa_positioning_card_page.dart';
import 'package:kingclub/src/features/club/presentation/aa_reservations_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('paid AA date exposes the legacy positioning card', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AaReservationsPage(
          onBack: () {},
          onOpenAdmissionTicket: () => opened = true,
        ),
      ),
    );

    await tester.tap(find.text('周四'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('aa-confirmed-positioning-card')),
      findsOneWidget,
    );
    expect(find.text('888'), findsOneWidget);
    expect(find.text('3880卡座套餐'), findsWidgets);
    expect(find.text('一键随机选座'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('aa-confirmed-positioning-card')),
    );
    expect(opened, isTrue);
  });

  testWidgets('legacy AA positioning credential shows complete QR content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AaPositioningCardPage(onBack: () {}),
      ),
    );

    expect(find.text('POSITIONING CARD'), findsNWidgets(2));
    expect(find.text('888'), findsOneWidget);
    expect(find.text('2026-08-27 20:30-04:00'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('K24500000299'), findsOneWidget);
    expect(find.text('3880卡座套餐'), findsOneWidget);
    expect(find.text('单人票价：388元'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('STORAGE INSTRUCTIONS:'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('STORAGE INSTRUCTIONS:'), findsOneWidget);
    expect(find.textContaining('着装邋遢'), findsOneWidget);
  });
}
