import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/commerce/data/ordering_catalog_repository.dart';
import 'package:kingclub/src/features/commerce/data/ordering_context.dart';
import 'package:kingclub/src/features/commerce/data/ordering_order_repository.dart';
import 'package:kingclub/src/features/commerce/presentation/live_order_payment_page.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';

void main() {
  const session = <String, dynamic>{
    'sessionId': 'session',
    'apiKeyId': 'key-id',
    'apiKey': 'key',
    'account': {'userAccount': 'member'},
  };
  const context = OrderingContext(
    contextRef: '11111111-1111-1111-1111-111111111111',
    memberRef: 'member',
    tableId: 'fixture-table',
    storeRef: 'store',
    tenantRef: 'tenant',
    brandRef: 'brand',
    cityId: 'fixture-city',
    cityName: 'Fixture City',
    storeName: 'Fixture Store',
    storeAddress: 'address',
    tableName: 'V1',
    tableSessionRef: '22222222-2222-2222-2222-222222222222',
    businessDate: '2026-09-22',
    currency: 'CNY',
    timeZone: 'Asia/Shanghai',
    paymentTiming: 'prepay',
  );
  const product = OrderingCatalogProduct(
    'product-1',
    'category-1',
    {'zh-CN': '酒', 'zh-TW': '酒', 'en': 'Wine', 'th': 'ไวน์'},
    {'zh-CN': '750ml', 'zh-TW': '750ml', 'en': '750ml', 'th': '750ml'},
    38800,
    3,
    2,
  );

  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets(
      'WeChat launch is not payment success; only owned query confirms payment at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        FlutterSecureStorage.setMockInitialValues({});
        var paid = false, submitted = 0, launches = 0;
        const channel = MethodChannel('kingclub/wechat-payment');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            launches++;
            expect(call.method, 'pay');
            return true;
          },
        );
        final repo = OrderingOrderRepository(
          readSession: () async => session,
          request: (id, params, _) async {
            if (id == 'K260919000814') submitted++;
            return {
              'result': {
                'orderRef': 'D00000000001',
                'storeRef': context.storeRef,
                'tableId': context.tableId,
                'tableSessionRef': context.tableSessionRef,
                'totalCents': 10,
                'currency': 'CNY',
                'expiresAt': '2030-01-01T00:00:00Z',
                'status': paid ? 'paid' : 'pending',
                if (id == 'K260919000814')
                  'payment': {
                    'appId': 'wxfixture',
                    'partnerId': 'fixture-partner',
                    'prepayId': 'fixture-prepay',
                    'packageValue': 'Sign=WXPay',
                    'nonceStr': 'fixture-nonce',
                    'timeStamp': '1',
                    'sign': 'fixture-sign',
                  },
              },
            };
          },
        );
        final quote = FakeOrderingQuote(
          itemCount: 1,
          total: 10,
          orderingContext: context,
          items: [
            const FakeOrderingQuoteItem(
              name: 'Fixture wine',
              detail: '750ML',
              asset: '',
              quantity: 1,
              unitPrice: 0,
              unitPriceCents: 10,
              catalogProduct: product,
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: LiveOrderPaymentPage(
              quote: quote,
              repository: repo,
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('微信支付'), findsOneWidget);
        expect(find.textContaining('应付 ￥0.10'), findsOneWidget);
        await tester.tap(find.text('立即支付'));
        await tester.pumpAndSettle();
        expect(submitted, 1);
        expect(launches, 1);
        expect(find.text('支付成功 · 返回'), findsNothing);
        paid = true;
        await tester.ensureVisible(find.text('刷新支付结果'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('刷新支付结果'));
        await tester.pumpAndSettle();
        expect(find.text('支付成功 · 返回'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      },
    );
  }
}
