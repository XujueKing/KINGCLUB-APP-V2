import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/storage_repository.dart';
import 'package:kingclub/src/features/club/presentation/private_storage_page.dart';
import 'package:kingclub/src/features/club/presentation/storage_liquid_bottle.dart';

const fixture = [
  StorageItem(
    ref: 'wine-1',
    name: '瑞典绝对伏特加 750ML',
    assetKey: 'vodka',
    quantity: 2,
    remainingPercent: 65,
  ),
  StorageItem(ref: 'wine-2', name: '芝华士12年', assetKey: 'chivas'),
  StorageItem(ref: 'wine-3', name: '轩尼诗VSOP', assetKey: 'hennessy'),
  StorageItem(
    ref: 'coupon-1',
    name: '首次AA免单券',
    assetKey: 'aa-ticket',
    category: 'item',
    description: '[首次AA免单券]是会员在APP预定AA套餐时，抵用会员自己的消费，最大可抵用388元。',
    maximumValue: 388,
    expiresAt: '2026-11-07T22:41:53Z',
  ),
];
void main() {
  testWidgets(
    'selection, flip midpoint and category paging follow storage data',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateStoragePage(
            repository: PreviewStorageRepository(fixture),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('storage-select-wine-1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('storage-flip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(StorageLiquidBottle), findsNothing);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(StorageLiquidBottle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StorageLiquidBottle),
          matching: find.text('65%'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('storage-flip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('storage-tab-物-idle')));
      await tester.pumpAndSettle();
      expect(find.text('首次AA免单券'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('storage-flip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('最大抵用金额：388元'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(360, 640),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('cabinet fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateStoragePage(
            repository: PreviewStorageRepository(fixture),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
