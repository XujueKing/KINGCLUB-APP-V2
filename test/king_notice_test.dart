import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_notice.dart';

void main() {
  testWidgets(
    'global notice is compact, above center, replaces and fades away',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                page = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      KingNotice.of(page).show('商店暂未开放');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final card = find.byKey(const ValueKey('king-global-notice'));
      final opacity = tester
          .widget<Opacity>(
            find.ancestor(of: card, matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      expect(tester.getSize(card).width, lessThan(300));
      expect(tester.getCenter(card).dx, closeTo(196.5, 1));
      expect(tester.getCenter(card).dy, lessThan(426));
      KingNotice.of(page).show('已复制');
      await tester.pump();
      expect(find.text('商店暂未开放'), findsNothing);
      expect(card, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump(const Duration(milliseconds: 200));
      expect(card, findsNothing);
    },
  );
}
