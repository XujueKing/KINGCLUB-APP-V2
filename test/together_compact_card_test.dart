import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/together_play_page.dart';

import 'together_play_test.dart' show fixture;

void main() {
  testWidgets('compact card keeps reference ratio and independent actions', (
    tester,
  ) async {
    var details = 0, joins = 0;
    for (final width in [320.0, 402.0]) {
      await tester.binding.setSurfaceSize(Size(width, 874));
      final party = fixture(cardLayout: 'compact');
      await tester.pumpWidget(
        MaterialApp(
          theme: KingTheme.dark,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topCenter,
                child: TogetherAvailableRow(
                  party: party,
                  edgeInset: false,
                  showHeading: false,
                  showAction: true,
                  actionLabel: '加入',
                  onTap: () => details++,
                  onAction: () => joins++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('together-compact-night'));
      final size = tester.getSize(card);
      expect(size.width / size.height, closeTo(2.24, .01));
      expect(find.text(party.theme), findsOneWidget);
      expect(find.text(party.feeLabel), findsOneWidget);
      await tester.tap(find.text('加入'));
      await tester.tap(find.text(party.theme));
      expect(tester.takeException(), isNull);
    }
    expect(details, 2);
    expect(joins, 2);
    await tester.binding.setSurfaceSize(null);
  });
}
