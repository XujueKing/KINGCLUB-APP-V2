import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/storage_repository.dart';
import 'package:kingclub/src/features/club/presentation/private_storage_page.dart';

void main() {
  test('coupon classification uses explicit type and legacy asset', () {
    expect(
      const StorageItem(
        ref: 'a',
        name: '任意',
        assetKey: 'aa-ticket',
        category: 'item',
      ).storageCategory,
      'coupon',
    );
    expect(
      const StorageItem(
        ref: 'b',
        name: '券字不决定分类',
        assetKey: 'other',
        category: 'item',
      ).storageCategory,
      'item',
    );
    expect(
      const StorageItem(
        ref: 'c',
        name: '新券',
        assetKey: 'other',
        category: 'coupon',
      ).storageCategory,
      'coupon',
    );
  });

  for (final size in [const Size(360, 640), const Size(393, 852)]) {
    testWidgets('fixed storage with independent axes $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final items = [
        for (var i = 0; i < 11; i++)
          StorageItem(ref: 'wine-$i', name: '酒$i', assetKey: 'vodka'),
        const StorageItem(
          ref: 'coupon',
          name: '券',
          assetKey: 'aa-ticket',
          category: 'item',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateStoragePage(repository: PreviewStorageRepository(items)),
        ),
      );
      await tester.pumpAndSettle();
      final titlePosition = tester.getTopLeft(find.text('储物袋'));
      expect(
        find.byKey(const ValueKey('storage-vertical-dots')),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const PageStorageKey('storage-vertical-0')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('storage-select-wine-9')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.getTopLeft(find.text('储物袋')), titlePosition);
      await tester.drag(
        find.byKey(const ValueKey('storage-category-pages')),
        const Offset(-350, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('storage-select-coupon')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('storage-vertical-dots')), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('storage-category-pages')),
        const Offset(350, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('storage-select-wine-9')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('coupon descriptions fit both faces at enlarged text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const description = '[首次AA免单券]是会员在APP预定AA套餐时，抵用会员自己的消费，最大可抵用388元。';
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: PrivateStoragePage(
          repository: PreviewStorageRepository([
            const StorageItem(
              ref: 'coupon',
              name: '首次AA免单券',
              assetKey: 'aa-ticket',
              category: 'item',
              description: description,
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('券'));
    await tester.pumpAndSettle();
    expect(find.text(description), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('storage-flip')));
    await tester.pumpAndSettle();
    expect(find.text(description), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('inactive storage preloads without a loading spinner', (
    tester,
  ) async {
    final repository = _PendingStorage();
    await tester.pumpWidget(
      MaterialApp(
        home: PrivateStoragePage(active: false, repository: repository),
      ),
    );
    expect(repository.requests, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    repository.result.complete([]);
    await tester.pumpAndSettle();
  });
}

class _PendingStorage extends PreviewStorageRepository {
  final result = Completer<List<StorageItem>>();
  int requests = 0;
  @override
  Future<List<StorageItem>> list() {
    requests++;
    return result.future;
  }
}
