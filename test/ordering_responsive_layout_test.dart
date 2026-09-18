import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/commerce/presentation/table_ordering_entry_page.dart';

void main() {
  for (final width in [320.0, 393.0, 430.0]) {
    for (final scale in [1.0, 1.35]) {
      testWidgets('点单布局宽 $width 字号 $scale 无溢出且结算固定', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 760);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          MaterialApp(
            theme: KingTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: TableOrderingEntryPage(
              tableId: 'K24000000001',
              tableName: 'V1',
              previewEnabled: true,
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('界面预览'), findsNothing);
        final cart = tester.getRect(
          find.byKey(const ValueKey('ordering-cart-bar')),
        );
        final fourth = tester.getRect(
          find.byKey(const ValueKey('ordering-image-absolut-vodka')),
        );
        expect(fourth.top, lessThan(cart.top));
        expect(fourth.bottom, greaterThan(cart.top));
        final backdrop =
            tester
                    .widget<Container>(
                      find.byKey(const ValueKey('ordering-cart-bar')),
                    )
                    .decoration!
                as BoxDecoration;
        expect(backdrop.gradient!.colors.first.a, lessThan(1));
        final checkout = find.byKey(const ValueKey('ordering-confirm'));
        final before = tester.getRect(checkout);
        await tester.drag(
          find.byKey(const ValueKey('ordering-add-hennessy-xo')),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(checkout), before);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
