import 'package:kingclub/src/features/club/presentation/bottle_material_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/bottle_material_preview.dart';
import 'package:kingclub/src/features/club/presentation/private_storage_page.dart';
import 'package:kingclub/src/features/club/presentation/storage_liquid_bottle.dart';

void main() {
  testWidgets(
    'all ten bottles keep the same canvas and shadow after flipping',
    (tester) async {
      for (final size in [const Size(180, 235), const Size(70, 235)]) {
        for (final item
            in BottleMaterialPreviewRepository().items
                .whereType<BottlePreviewItem>()) {
          Widget host(Widget child) => MaterialApp(
            home: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: child,
              ),
            ),
          );
          await tester.pumpWidget(host(BottleMaterialImage(item: item)));
          await tester.pumpAndSettle();
          final front = tester.getRect(
            find.byKey(ValueKey('bottle-backing-${item.ref}')),
          );
          final ground = tester.getRect(
            find.byKey(ValueKey('bottle-ground-${item.ref}')),
          );
          await tester.pumpWidget(
            host(StorageLiquidBottle(item: item, active: false)),
          );
          await tester.pumpAndSettle();
          expect(
            tester.getRect(
              find.byKey(ValueKey('bottle-reverse-canvas-${item.ref}')),
            ),
            rectMoreOrLessEquals(front, epsilon: 0.001),
          );
          expect(
            tester.getRect(find.byKey(ValueKey('bottle-backing-${item.ref}'))),
            rectMoreOrLessEquals(front, epsilon: 0.001),
          );
          expect(
            tester.getRect(find.byKey(ValueKey('bottle-ground-${item.ref}'))),
            rectMoreOrLessEquals(ground, epsilon: 0.001),
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
  test('material fixtures cannot issue pickup codes and include four legacy comparisons', () async {
    final repo = BottleMaterialPreviewRepository();
    final items = await repo.list();
    expect(items.length, 14);
    expect(items.every((item) => !item.canPickup), isTrue);
    expect(items.whereType<LegacyBottleComparisonItem>().length, 4);
    expect(items.whereType<BottlePreviewItem>().length, 10);
    await expectLater(repo.issue(items.first.ref), throwsA(anything));
  });
  for (final size in [const Size(360, 640), const Size(393, 852)]) {
    testWidgets('bag renders both material pages and liquid at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = BottleMaterialPreviewRepository();
      await tester.pumpWidget(
        MaterialApp(home: PrivateStoragePage(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('储物袋 · 素材测试'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('storage-flip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(StorageLiquidBottle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('测试余量'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(0);
      await tester.pump();
      expect(find.text('0%'), findsOneWidget);
      slider.onChanged!(100);
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
      Navigator.of(tester.element(find.byType(Slider))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.drag(
        find.byKey(const PageStorageKey('storage-vertical-0')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('storage-select-bottle_06')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('storage-flip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(StorageLiquidBottle), findsOneWidget);
      // Both thumbnail and reverse face retain their ground shadow.
      expect(
        find.byKey(const ValueKey('bottle-ground-bottle_06')),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
