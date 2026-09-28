import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets(
      'cart animates, scrolls and quotes only checked goods at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        final font = Platform.environment['KINGCLUB_QA_FONT'];
        if (font != null) {
          await tester.runAsync(() async {
            await (FontLoader('OrderingQA')..addFont(
                  Future.value(
                    ByteData.sublistView(await File(font).readAsBytes()),
                  ),
                ))
                .load();
          });
        }
        FakeOrderingQuote? quote;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark().copyWith(
                textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: font == null ? null : 'OrderingQA',
                ),
              ),
              home: ScanOrderingCartPage(
                onBack: () {},
                onQuoteReady: (value) => quote = value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> capture(String name) async {
          if (font == null) return;
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/ordering-qa').create(recursive: true);
            await File('build/ordering-qa/${size.width.toInt()}-$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('menu');
        final bag = find.byKey(const ValueKey('ordering-cart-bag'));
        await tester.tap(bag);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final sheet = find.byKey(const ValueKey('ordering-cart-sheet'));
        final middleTop = tester.getTopLeft(sheet).dy;
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(sheet).dy, lessThan(middleTop));
        expect(tester.getSize(sheet).height, closeTo(size.height * .6, .01));
        expect(
          find.byKey(const ValueKey('ordering-confirm')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await capture('cart');
        await tester.tap(
          find.byKey(const ValueKey('ordering-cart-select-all')),
        );
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('ordering-confirm')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(
          find.byKey(const ValueKey('ordering-cart-select-hennessy-xo')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
        await tester.pump(const Duration(milliseconds: 500));
        expect(quote!.items.single.name, '轩尼诗XO');
        expect(quote!.total, 3380);
        expect(quote!.itemCount, 1);
        await tester.tap(bag);
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        final add = find.byKey(const ValueKey('ordering-add-chivas-12'));
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pump();
        expect(find.byKey(const ValueKey('ordering-fly-item')), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('ordering-fly-item')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
