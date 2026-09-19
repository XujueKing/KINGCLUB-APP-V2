import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/bottle_material_preview.dart';
import 'package:kingclub/src/features/club/presentation/private_storage_page.dart';
import 'package:kingclub/src/features/club/presentation/storage_liquid_bottle.dart';

void main() {
  test(
    'material fixtures cannot issue pickup codes and exclude Chivas',
    () async {
      final repo = BottleMaterialPreviewRepository();
      final items = await repo.list();
      expect(items.length, 10);
      expect(items.every((item) => !item.canPickup), isTrue);
      expect(items.any((item) => item.name.contains('芝华士')), isFalse);
      await expectLater(repo.issue(items.first.ref), throwsA(anything));
    },
  );
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
        find.byKey(const ValueKey('storage-select-bottle_10')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('storage-flip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(StorageLiquidBottle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
