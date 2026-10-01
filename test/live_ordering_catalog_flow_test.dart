import 'package:kingclub/src/core/media/cached_media_image.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/ordering_catalog_repository.dart';
import 'package:kingclub/src/features/commerce/data/ordering_context.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';
import 'package:kingclub/src/features/commerce/presentation/table_ordering_entry_page.dart';

import 'ordering_catalog_repository_test.dart' as fixture;

OrderingCatalog catalog({
  int available = 2,
  bool remoteImage = false,
}) => OrderingCatalog(
  fixture.scope,
  [OrderingCatalogCategory('c', 'liquor', fixture.names())],
  [
    OrderingCatalogProduct(
      'real-sku',
      'c',
      fixture.names(),
      fixture.names(),
      1999,
      1,
      available,
      thumbnailUrl: remoteImage
          ? 'https://api.example.test/commerce/attachments/fixture?token=test'
          : null,
      imageCacheKey: remoteImage ? 'bottle:store:digest:thumbnail' : null,
    ),
  ],
);

void main() {
  testWidgets(
    'prepay can exceed stock in menu and cart and quote full selection',
    (tester) async {
      FakeOrderingQuote? quote;
      await tester.pumpWidget(
        MaterialApp(
          home: ScanOrderingCartPage(
            onBack: () {},
            orderingContext: fixture.scope,
            catalog: catalog(available: 1),
            onQuoteReady: (value) => quote = value,
          ),
        ),
      );
      final add = find.byKey(const ValueKey('ordering-add-real-sku'));
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ordering-cart-bag')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('ordering-add-sheet-real-sku')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
      await tester.pumpAndSettle();
      expect(quote!.itemCount, 3);
    },
  );
  testWidgets('postpay zero stock continues to block selection', (
    tester,
  ) async {
    const scope = OrderingContext(
      contextRef: 'test',
      memberRef: 'member',
      storeRef: 'store',
      tableSessionRef: 'session',
      storeName: 'Test',
      storeAddress: 'Test',
      tableName: 'T',
      businessDate: '2026-10-01',
      paymentTiming: 'postpay',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ScanOrderingCartPage(
          onBack: () {},
          orderingContext: scope,
          catalog: OrderingCatalog(
            scope,
            catalog().categories,
            catalog(available: 0).products,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('ordering-add-real-sku')), findsNothing);
    expect(find.byKey(const ValueKey('ordering-sold-out')), findsOneWidget);
  });

  testWidgets(
    'remote material is shared by menu and cart with private stable caching',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanOrderingCartPage(
            onBack: () {},
            orderingContext: fixture.scope,
            catalog: catalog(remoteImage: true),
          ),
        ),
      );
      final menu = tester.widget<CachedMediaImage>(
        find.byType(CachedMediaImage),
      );
      expect(menu.private, isTrue);
      expect(menu.fit, BoxFit.contain);
      expect(menu.contentKey, 'bottle:store:digest:thumbnail');
      await tester.tap(find.byKey(const ValueKey('ordering-add-real-sku')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ordering-cart-bag')));
      await tester.pumpAndSettle();
      final images = tester
          .widgetList<CachedMediaImage>(find.byType(CachedMediaImage))
          .toList();
      expect(images.length, 2);
      expect(
        images.every((image) => image.contentKey == menu.contentKey),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'real catalog replaces demo stock and retains decimal cart price',
    (tester) async {
      FakeOrderingQuote? quote;
      await tester.pumpWidget(
        MaterialApp(
          home: ScanOrderingCartPage(
            onBack: () {},
            orderingContext: fixture.scope,
            catalog: catalog(),
            onQuoteReady: (value) => quote = value,
          ),
        ),
      );
      expect(find.text('轩尼诗XO'), findsNothing);
      expect(
        find.byKey(const ValueKey('ordering-add-real-sku')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('ordering-add-real-sku')));
      await tester.pump();
      expect(find.textContaining('19.99', findRichText: true), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(quote!.items.single.catalogProduct!.reference, 'real-sku');
      expect(quote!.items.single.unitPriceCents, 1999);
      expect(quote!.itemCount, 1);
    },
  );
  testWidgets(
    'prepay zero stock allows selecting and empty catalog has no demo fallback',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanOrderingCartPage(
            onBack: () {},
            orderingContext: fixture.scope,
            catalog: catalog(available: 0),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('ordering-add-real-sku')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('ordering-add-real-sku')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ordering-add-real-sku')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: ScanOrderingCartPage(
            key: const ValueKey('empty'),
            onBack: () {},
            orderingContext: fixture.scope,
            catalog: OrderingCatalog(fixture.scope, const [], const []),
          ),
        ),
      );
      expect(find.text('轩尼诗XO'), findsNothing);
      expect(find.text('暂无符合的商品'), findsOneWidget);
    },
  );
  testWidgets('catalog loading and failure never show demo products', (
    tester,
  ) async {
    final pending = Completer<OrderingCatalog>();
    await tester.pumpWidget(
      MaterialApp(
        home: TableOrderingEntryPage(
          tableId: 'table',
          onBack: () {},
          resolveTable: (_) async => fixture.scope,
          readCatalog: (_) => pending.future,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ScanOrderingCartPage), findsNothing);
    pending.completeError(StateError('private diagnostic'));
    await tester.pumpAndSettle();
    expect(find.text('private diagnostic'), findsNothing);
    expect(find.text('轩尼诗XO'), findsNothing);
    expect(find.text('重试'), findsOneWidget);
  });
  testWidgets('table changes discard late catalog result', (tester) async {
    final pending = Completer<OrderingCatalog>();
    Future<OrderingCatalog> read(_) => pending.future;
    Widget page(String table) => MaterialApp(
      home: TableOrderingEntryPage(
        tableId: table,
        onBack: () {},
        resolveTable: (id) async {
          if (id == 'other') throw StateError('closed');
          return fixture.scope;
        },
        readCatalog: read,
      ),
    );
    await tester.pumpWidget(page('table'));
    await tester.pump();
    await tester.pumpWidget(page('other'));
    await tester.pump();
    pending.complete(catalog());
    await tester.pumpAndSettle();
    expect(find.byType(ScanOrderingCartPage), findsNothing);
  });
}
