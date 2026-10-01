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

  testWidgets(
    'postpay has one submit action and never launches payment or clears cart twice',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final postpay = OrderingContext(
        contextRef: context.contextRef,
        memberRef: context.memberRef,
        storeRef: context.storeRef,
        tableSessionRef: context.tableSessionRef,
        tableId: context.tableId,
        storeName: context.storeName,
        storeAddress: context.storeAddress,
        tableName: context.tableName,
        businessDate: context.businessDate,
        currency: 'CNY',
        paymentTiming: 'postpay',
      );
      var submissions = 0, cleared = 0, paid = 0, back = 0;
      final repo = OrderingOrderRepository(
        readSession: () async => session,
        request: (id, params, _) async {
          if (id == 'K260919000814') {
            submissions++;
            expect(params['initiatePayment'], false);
          }
          return {
            'result': {
              'orderRef': 'D00000000001',
              'storeRef': context.storeRef,
              'tableId': context.tableId,
              'tableSessionRef': context.tableSessionRef,
              'status': 'pending',
              'totalCents': 38800,
              'currency': 'CNY',
              'paymentTiming': 'postpay',
              'expiresAt': null,
            },
          };
        },
      );
      final quote = FakeOrderingQuote(
        itemCount: 1,
        total: 388,
        orderingContext: postpay,
        onOrderSubmitted: () => cleared++,
        onPaymentConfirmed: () => paid++,
        items: [
          const FakeOrderingQuoteItem(
            name: 'Test wine',
            detail: '750ml',
            asset: '',
            quantity: 1,
            unitPrice: 388,
            unitPriceCents: 38800,
            catalogProduct: product,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LiveOrderPaymentPage(
            quote: quote,
            repository: repo,
            onBack: () => back++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('payment-provider-wechat')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('payment-provider-alipay')),
        findsNothing,
      );
      expect(find.text('Place order'), findsOneWidget);
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();
      expect(submissions, 1);
      expect(cleared, 1);
      expect(paid, 0);
      expect(find.byKey(const ValueKey('order-cancel')), findsNothing);
      expect(find.byKey(const ValueKey('live-payment-success')), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(cleared, 1);
      await tester.tap(find.text('Continue ordering'));
      expect(back, 1);
      expect(submissions, 1);
      await tester.pumpWidget(const SizedBox());
    },
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
        var paid = false, submitted = 0, launches = 0, returned = 0;
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
              onBack: () => returned++,
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
        expect(
          find.byKey(const ValueKey('live-payment-success')),
          findsNothing,
        );
        paid = true;
        await tester.ensureVisible(find.text('刷新支付结果'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('刷新支付结果'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('live-payment-success')),
          findsOneWidget,
        );
        expect(returned, 0);
        expect(find.text('D00000000001'), findsNothing);
        expect(find.textContaining('D00000000001'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('live-payment-success-return')),
        );
        expect(returned, 1);
        await tester.pumpWidget(const SizedBox());
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      },
    );
  }
}
