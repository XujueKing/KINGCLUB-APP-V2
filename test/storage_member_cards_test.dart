import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/storage_repository.dart';
import 'package:kingclub/src/features/club/presentation/private_storage_page.dart';

import 'member_balance_snapshot_test.dart' show fixture;

void main() {
  testWidgets(
    'cards tab groups recharge lots into one store card and opens breakdown',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var loads = 0;
      final raw = fixture();
      raw['stores'][0]['storeName'] = 'KINGCLUB 湖南工大店';
      raw['stores'][0]['originalPrincipalCents'] = '20000';
      raw['stores'][0]['originalGiftCents'] = '5000';
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateStoragePage(
            repository: PreviewStorageRepository([
              const StorageItem(ref: 'wine', name: 'Wine', assetKey: 'chivas'),
            ]),
            loadCards: () async {
              loads++;
              return raw;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 1);
      expect(
        tester.widget<Text>(find.text('Vouchers')).style?.color,
        const Color(0xFF756A5C),
      );
      await tester.tap(find.text('Cards'));
      await tester.pumpAndSettle();
      expect(loads, 2);
      expect(
        find
            .byKey(const ValueKey('storage-select-card-test-store'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('storage-grid-卡-1')), findsOneWidget);
      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('storage-grid-卡-1')),
      );
      expect(grid.childrenDelegate.estimatedChildCount, 9);
      await tester.tap(find.byKey(const ValueKey('storage-pickup')));
      await tester.pumpAndSettle();
      expect(find.text('200.00'), findsOneWidget);
      expect(find.text('50.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
