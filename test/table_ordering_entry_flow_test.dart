import 'package:kingclub/src/features/commerce/data/ordering_catalog_repository.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/commerce/data/ordering_context.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';
import 'package:kingclub/src/features/commerce/presentation/table_ordering_entry_page.dart';

OrderingContext scope(String id) => OrderingContext(
  contextRef: id,
  memberRef: 'member',
  storeRef: 'bar-$id',
  tableSessionRef: 'session-$id',
  storeName: '店-$id',
  storeAddress: '地址',
  tableName: id,
  businessDate: '2026/09/18',
  cityId: 'city',
);

void main() {
  testWidgets('未开台和清台中保留明确状态，员工处理后可刷新', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TableOrderingEntryPage(
          tableId: 'T1',
          onBack: () {},
          resolveTable: (_) async {
            attempts++;
            throw AuthFailure(
              attempts == 1
                  ? 'ORDERING_TABLE_NOT_OPEN'
                  : 'ORDERING_TABLE_CLEARING',
              'private server details',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('确认预约或开台'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.textContaining('正在清台'), findsOneWidget);
    expect(find.textContaining('private server details'), findsNothing);
    expect(find.byType(ScanOrderingCartPage), findsNothing);
    expect(attempts, 2);
  });

  testWidgets('登录失效提供登录回调，不继续重试桌台接口', (tester) async {
    var signIns = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TableOrderingEntryPage(
          tableId: 'T1',
          onBack: () {},
          onSignIn: () => signIns++,
          resolveTable: (_) async =>
              throw const AuthFailure('SESSION_CHANGED', 'hidden'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsNothing);
    await tester.tap(find.text('重新登录'));
    expect(signIns, 1);
    expect(find.byType(ScanOrderingCartPage), findsNothing);
  });

  for (final entry in <Locale, String>{
    const Locale('zh'): '桌台正在清台，请稍候再刷新',
    const Locale('en'): 'This table is being cleared. Please refresh later.',
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'):
        '桌台正在清台，請稍候再重新整理',
    const Locale('th'): 'กำลังเคลียร์โต๊ะ กรุณารอสักครู่แล้วรีเฟรช',
  }.entries) {
    testWidgets('清台状态支持 ${entry.key}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TableOrderingEntryPage(
            locale: entry.key,
            tableId: 'T1',
            onBack: () {},
            resolveTable: (_) async =>
                throw const AuthFailure('ORDERING_TABLE_CLEARING', 'hidden'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    });
  }
  testWidgets('商务预览展示扫码桌名、空购物袋，结算不进入真实订单', (tester) async {
    var quotes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TableOrderingEntryPage(
          tableId: 'K24000000001',
          tableName: 'V1',
          previewEnabled: true,
          onBack: () {},
          onQuoteReady: (_) => quotes++,
        ),
      ),
    );
    expect(find.text('V1'), findsOneWidget);
    expect(find.textContaining('门店、商品和价格为演示数据'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('已选商品仅供预览，真实下单尚未开放'), findsNothing);
    final add = find.byKey(const ValueKey('ordering-add-hennessy-xo'));
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('已选商品仅供预览，真实下单尚未开放'), findsOneWidget);
    expect(quotes, 0);
  });
  testWidgets('查询器未接通不显示演示点单商品', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TableOrderingEntryPage(tableId: 'T1', onBack: () {}),
      ),
    );
    expect(find.text('桌台点单服务尚未接通'), findsOneWidget);
    expect(find.byType(ScanOrderingCartPage), findsNothing);
  });

  testWidgets('仅以 tableId 查询，换桌后忽略旧查询结果', (tester) async {
    final requests = <String>[];
    final a = Completer<OrderingContext>();
    final b = Completer<OrderingContext>();
    Future<OrderingContext> resolve(String id) {
      requests.add(id);
      return id == 'A' ? a.future : b.future;
    }

    Widget page(String id) => MaterialApp(
      home: TableOrderingEntryPage(
        tableId: id,
        onBack: () {},
        resolveTable: resolve,
        readCatalog: (c) async => OrderingCatalog(c, const [], const []),
      ),
    );
    await tester.pumpWidget(page('A'));
    expect(find.byType(ScanOrderingCartPage), findsNothing);
    await tester.pumpWidget(page('B'));
    b.complete(scope('B'));
    await tester.pumpAndSettle();
    a.complete(scope('A'));
    await tester.pumpAndSettle();
    expect(requests, ['A', 'B']);
    final cart = tester.widget<ScanOrderingCartPage>(
      find.byType(ScanOrderingCartPage),
    );
    expect(cart.orderingContext!.storeRef, 'bar-B');
    expect(cart.orderingContext!.cityId, 'city');
  });

  testWidgets('查询失败可重试且不借用其他桌台数据', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TableOrderingEntryPage(
          tableId: 'T1',
          onBack: () {},
          readCatalog: (c) async => OrderingCatalog(c, const [], const []),
          resolveTable: (id) async {
            if (++attempts == 1) throw StateError('unavailable');
            return scope(id);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScanOrderingCartPage), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('店-T1'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('真实目录结算把报价回调交给确认页，不再停在购物车提示', (tester) async {
    FakeOrderingQuote? quote;
    final context = scope('V1');
    final catalog = OrderingCatalog(
      context,
      const [
        OrderingCatalogCategory('cat-liquor', 'liquor', {
          'zh-CN': '畅饮套餐',
          'zh-TW': '暢飲套餐',
          'en': 'Package',
          'th': 'แพ็กเกจ',
        }),
      ],
      const [
        OrderingCatalogProduct(
          'product-xo',
          'cat-liquor',
          {
            'zh-CN': '轩尼诗XO',
            'zh-TW': '軒尼詩XO',
            'en': 'Hennessy XO',
            'th': 'Hennessy XO',
          },
          {'zh-CN': '750ML', 'zh-TW': '750ML', 'en': '750ML', 'th': '750ML'},
          338000,
          1,
          2,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TableOrderingEntryPage(
          tableId: 'K24000000001',
          onBack: () {},
          resolveTable: (_) async => context,
          readCatalog: (_) async => catalog,
          onQuoteReady: (value) => quote = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final add = find.byKey(const ValueKey('ordering-add-product-xo'));
    expect(add, findsOneWidget);
    await tester.tap(add);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ordering-confirm')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(quote?.itemCount, 1);
    expect(quote?.items.single.unitPrice, 3380);
    expect(quote?.items.single.unitPriceCents, 338000);
  });
}
