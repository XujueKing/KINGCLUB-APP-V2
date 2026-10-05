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
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateStoragePage(
            repository: PreviewStorageRepository([]),
            loadCards: () async {
              loads++;
              return raw;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 0);
      expect(
        tester.widget<Text>(find.text('Vouchers')).style?.color,
        const Color(0xFFB8AD9C),
      );
      await tester.tap(find.text('Cards'));
      await tester.pumpAndSettle();
      expect(loads, 1);
      expect(
        find.byKey(const ValueKey('storage-card-test-store')),
        findsOneWidget,
      );
      expect(find.textContaining('250.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('storage-card-test-store')));
      await tester.pumpAndSettle();
      expect(find.text('200.00'), findsOneWidget);
      expect(find.text('50.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
