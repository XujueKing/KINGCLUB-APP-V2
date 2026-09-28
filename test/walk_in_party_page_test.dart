import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/ordering_table_repository.dart';
import 'package:kingclub/src/features/commerce/presentation/walk_in_party_page.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('select guests and more without overflow $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final counts = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: WalkInPartyPage(
            entry: const OrderingEntryRequired(
              tableName: 'V1',
              businessDate: '2026-09-25',
              revision: 0,
              minimumPeople: 1,
              staffRequired: false,
            ),
            locale: const Locale('zh'),
            onBack: () {},
            onRefresh: () {},
            onConfirm: (n) async => counts.add(n),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(counts, isEmpty);
      await tester.tap(find.text('3'));
      await tester.ensureVisible(find.text('开始点餐'));
      await tester.tap(find.text('开始点餐'));
      await tester.pumpAndSettle();
      expect(counts, [3]);
      await tester.ensureVisible(find.text('更多'));
      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12');
      await tester.ensureVisible(find.text('开始点餐'));
      await tester.tap(find.text('开始点餐'));
      await tester.pumpAndSettle();
      expect(counts, [3, 12]);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('staff table cannot submit guest opening', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WalkInPartyPage(
          entry: const OrderingEntryRequired(
            tableName: 'V1',
            businessDate: '2026-09-25',
            revision: 1,
            minimumPeople: 1,
            staffRequired: true,
          ),
          locale: const Locale('zh'),
          onBack: () {},
          onRefresh: () {},
          onConfirm: (_) async => fail('must not open'),
        ),
      ),
    );
    expect(find.text('开始点餐'), findsNothing);
    expect(find.text('请联系预订人员'), findsOneWidget);
  });
}
