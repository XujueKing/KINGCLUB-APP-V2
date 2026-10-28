import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/store_home_repository.dart';
import 'package:kingclub/src/features/commerce/presentation/store_home_page.dart';
import 'package:kingclub/src/features/club/presentation/together_play_page.dart';

import 'together_play_test.dart' as fixtures;

Map<String, dynamic> data() => {
  'store': {
    'ref': 'store',
    'name': '测试店铺',
    'brandName': '测试品牌',
    'branchName': '分店',
    'address': '测试地址',
    'cityCode': 'city',
    'canBook': 1,
  },
  'favourite': 0,
  'activities': <Map<String, dynamic>>[],
  'vouchers': [
    {
      'ref': 'voucher',
      'title': '双人套餐',
      'subtitle': '本店使用',
      'priceCents': '12800',
      'currency': 'CNY',
    },
  ],
  'products': <Map<String, dynamic>>[],
  'more': {'activities': false, 'vouchers': false, 'booking': false},
};
void main() {
  testWidgets('store identity opens store without opening activity', (
    tester,
  ) async {
    var stores = 0, activities = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TogetherAvailableRow(
              party: fixtures.fixture(
                cardPublisher: 'store',
                cardStoreName: 'Test store',
              ),
              showHeading: false,
              showAction: true,
              blurFooter: false,
              onStore: () => stores++,
              onTap: () => activities++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('together-summary-icon-night')),
    );
    await tester.tap(find.byKey(const ValueKey('together-summary-icon-night')));
    expect(stores, 1);
    expect(activities, 0);
    expect(tester.takeException(), isNull);
  });
  test('homepage uses one call and rejects a cross-store response', () async {
    final calls = <String>[];
    final repo = StoreHomeRepository(
      call: (id, p) async {
        calls.add(id);
        return data();
      },
    );
    await repo.home('store');
    expect(calls, ['K261028002080']);
    await expectLater(repo.home('other'), throwsFormatException);
  });
  for (final width in [320.0, 402.0]) {
    testWidgets('store activities then vouchers and adaptive layout $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      final repo = StoreHomeRepository(
        call: (id, p) async {
          calls.add(id);
          return data();
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1000),
              textScaler: TextScaler.linear(1.2),
            ),
            child: StoreHomePage(storeRef: 'store', repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, ['K261028002080']);
      await tester.ensureVisible(find.text('About'));
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();
      expect(find.text('About this store'), findsOneWidget);
      await tester.ensureVisible(find.text('Featured'));
      await tester.tap(find.text('Featured'));
      await tester.pumpAndSettle();
      expect(calls, [
        'K261028002080',
      ]); // introduction and return reuse the initial page
      await tester.scrollUntilVisible(
        find.text('Deals & vouchers'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Store activities')).dy,
        lessThan(tester.getTopLeft(find.text('Deals & vouchers')).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('双人套餐'));
      await tester.pumpAndSettle();
      expect(
        calls.last,
        'K261028002081',
      ); // malformed detail stays in a retry state
      expect(find.textContaining('Voucher unavailable'), findsOneWidget);
    });
  }
}
