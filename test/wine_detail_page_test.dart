import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/wine_stories.dart';
import 'package:kingclub/src/features/commerce/data/ordering_catalog_repository.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';
import 'package:kingclub/src/features/commerce/presentation/wine_detail_page.dart';

import 'ordering_catalog_repository_test.dart' as fixture;

Map<String, String> names(String value) => {
  'zh-CN': value,
  'zh-TW': value,
  'en': value,
  'th': value,
};

void main() {
  testWidgets(
    'known detail opens, unknown stays closed, add and return preserve cart',
    (tester) async {
      FakeOrderingQuote? quote;
      await tester.pumpWidget(
        MaterialApp(
          home: ScanOrderingCartPage(
            onBack: () {},
            onQuoteReady: (value) => quote = value,
            orderingContext: fixture.scope,
            catalog: OrderingCatalog(
              fixture.scope,
              [OrderingCatalogCategory('wine', 'liquor', names('洋酒'))],
              [
                OrderingCatalogProduct(
                  'known',
                  'wine',
                  names('獭祭39'),
                  names('300ml'),
                  1234,
                  1,
                  8,
                ),
                OrderingCatalogProduct(
                  'unknown',
                  'wine',
                  names('XO黑珍珠'),
                  names('750ml'),
                  9900,
                  1,
                  8,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('ordering-add-known')));
      await tester.pumpAndSettle();
      expect(find.byType(WineDetailPage), findsNothing);
      await tester.tap(find.text('XO黑珍珠').first);
      await tester.pumpAndSettle();
      expect(find.byType(WineDetailPage), findsNothing);
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey('ordering-details-unknown')),
            )
            .onTap,
        isNull,
      );
      for (final target in [
        find.text('獭祭39').first,
        find.text('300ml').first,
        find.text('¥ 12.34').first,
        find.byKey(const ValueKey('ordering-details-unknown')),
      ]) {
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.byType(WineDetailPage), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('ordering-details-known')));
      await tester.pumpAndSettle();
      expect(find.byType(WineDetailPage), findsOneWidget);
      expect(find.text('300ml'), findsOneWidget);
      expect(find.text('¥ 12.34'), findsOneWidget);
      expect(find.text(wineStories['獭祭39']!.introductions[0]), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
      await tester.pumpAndSettle();
      expect(quote!.itemCount, 1);
      expect(quote!.total, 1234);
    },
  );

  final locales = [
    const Locale('zh'),
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    const Locale('th'),
  ];
  for (var i = 0; i < locales.length; i++) {
    testWidgets('small screen readable and scrollable in ${locales[i]}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final story = wineStories['獭祭39']!;
      await tester.pumpWidget(
        MaterialApp(
          home: WineDetailPage(
            name: 'Dassai 39',
            englishName: 'Dassai 39',
            specifications: '300ml',
            price: '12.34',
            image: const Icon(Icons.local_bar),
            story: story,
            locale: locales[i],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('wine-introduction')),
      );
      await tester.pumpAndSettle();
      expect(find.text(story.introductions[i]), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
