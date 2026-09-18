import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/commerce/presentation/table_ordering_entry_page.dart';

void main() {
  for (final viewport in [
    const Size(320, 694),
    const Size(360, 640),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    final width = viewport.width;
    for (final scale in [1.0, 1.35]) {
      testWidgets('点单布局宽 $width 字号 $scale 无溢出且结算固定', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPadding);
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
        expect(
          tester.getSize(find.byKey(const ValueKey('ordering-search'))).height,
          closeTo(width * 76 / 750, .01),
        );
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
        expect(backdrop.gradient!.colors.first.a, closeTo(.8, .001));
        expect(backdrop.gradient!.colors.last.a, 1);
        final checkout = find.byKey(const ValueKey('ordering-confirm'));
        final before = tester.getRect(checkout);
        await tester.drag(
          find.byKey(const ValueKey('ordering-add-hennessy-xo')),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(checkout), before);
        expect(tester.takeException(), isNull);
        final list = find.byKey(const ValueKey('ordering-product-list'));
        final listTop = tester.getRect(list).top;
        await tester.tap(
          find.byKey(const ValueKey('ordering-subcategory-伏特加')),
        );
        await tester.pumpAndSettle();
        final vodka = tester.getRect(
          find.byKey(const ValueKey('ordering-image-absolut-vodka')),
        );
        expect(vodka.top, greaterThanOrEqualTo(listTop));
        expect(vodka.top, lessThan(listTop + 40));
        final position = tester.widget<ListView>(list).controller!.offset;
        expect(position, greaterThan(0));
        expect(
          tester
              .getRect(find.byKey(const ValueKey('ordering-add-absolut-vodka')))
              .bottom,
          lessThan(cart.top),
        );
        // Category navigation preserves other goods in the same scroll list.
        await tester.drag(list, const Offset(0, 1200));
        await tester.pumpAndSettle();
        expect(find.text('轩尼诗XO').hitTestable(), findsOneWidget);
        expect(find.text('芝华士12年').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
