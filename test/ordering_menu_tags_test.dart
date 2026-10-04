import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/ordering_catalog_repository.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';

import 'ordering_catalog_repository_test.dart' as fixture;

Map<String, String> names(String text) => {
  'zh-CN': text,
  'zh-TW': text,
  'en': text,
  'th': text,
};
OrderingCatalog menu() => OrderingCatalog(
  fixture.scope,
  [
    OrderingCatalogCategory('wine', 'liquor', names('洋酒')),
    OrderingCatalogCategory('activity', 'liquor', names('活动套餐')),
    OrderingCatalogCategory('selected', 'liquor', names('精选套餐')),
  ],
  [
    OrderingCatalogProduct(
      'wine-sku',
      'wine',
      names('Wine'),
      names('750ml'),
      10000,
      1,
      8,
      isNew: true,
      isRecommended: true,
      isHot: true,
    ),
    OrderingCatalogProduct(
      'package-a',
      'activity',
      names('A'),
      names('1'),
      20000,
      1,
      8,
    ),
    OrderingCatalogProduct(
      'package-b',
      'selected',
      names('B'),
      names('1'),
      30000,
      1,
      8,
    ),
  ],
);
void main() {
  test(
    'tags precede a single package section and preserve original wine category',
    () {
      final projected = menu().forAppMenu();
      expect(projected.categories.map((c) => c.names['zh-CN']), [
        '新品',
        '推荐',
        '套餐',
        '洋酒',
      ]);
      expect(
        projected.products.where((p) => p.reference == 'wine-sku').length,
        3,
      );
      expect(
        projected.products
            .where((p) => p.reference.startsWith('package'))
            .map((p) => p.categoryRef)
            .toSet(),
        {'activity'},
      );
      expect(menu().products.length, 3);
    },
  );
  testWidgets('tag duplicates share one quantity and one checkout item', (
    tester,
  ) async {
    FakeOrderingQuote? quote;
    await tester.pumpWidget(
      MaterialApp(
        home: ScanOrderingCartPage(
          onBack: () {},
          orderingContext: fixture.scope,
          catalog: menu(),
          onQuoteReady: (v) => quote = v,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('ordering-tag-new')), findsWidgets);
    expect(find.byKey(const ValueKey('ordering-tag-recommended')), findsWidgets);
    expect(find.byKey(const ValueKey('ordering-tag-hot')), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('ordering-add-wine-sku')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
    await tester.pumpAndSettle();
    expect(quote!.items.length, 1);
    expect(quote!.itemCount, 1);
    expect(quote!.items.single.unitPriceCents, 10000);
    expect(quote!.total, 10000);
  });
}
