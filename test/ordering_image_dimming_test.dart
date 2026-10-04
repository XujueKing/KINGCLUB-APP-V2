import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';

import 'live_ordering_catalog_flow_test.dart' as flow;
import 'ordering_catalog_repository_test.dart' as fixture;

void main() {
  testWidgets(
    'stock changes do not alter product pictures or menu brightness',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pixels = <List<int>>[];
      for (final available in [2, 2, 0]) {
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: ScanOrderingCartPage(
                onBack: () {},
                orderingContext: fixture.scope,
                catalog: flow.catalog(available: available),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final widget in tester.widgetList<Image>(find.byType(Image))) {
            await precacheImage(widget.image, boundaryKey.currentContext!);
          }
        });
        await tester.pumpAndSettle();
        final rect = tester.getRect(
          find.byKey(const ValueKey('ordering-product-list')),
        );
        final addRect = tester
            .getRect(find.byKey(const ValueKey('ordering-add-real-sku')))
            .inflate(2);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final sample = <int>[];
          // Picture and text stay unchanged; only the add button can dim.
          for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
            for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
              if (addRect.contains(Offset(x.toDouble(), y.toDouble()))) {
                continue;
              }
              final offset = (y * image.width + x) * 4;
              sample.add(data.getUint32(offset));
            }
          }
          pixels.add(sample);
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
      expect(pixels[1].toSet().length, greaterThan(3));
      expect(pixels[2], pixels[1]);
    },
  );
}
