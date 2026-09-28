import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/ordering_catalog_repository.dart';
import 'package:kingclub/src/features/commerce/data/ordering_context.dart';
import 'package:kingclub/src/features/commerce/data/ordering_order_repository.dart';
import 'package:kingclub/src/features/commerce/presentation/live_order_payment_page.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';

const _requestId = '33333333-3333-4333-8333-333333333333';
const _tableSession = '22222222-2222-2222-2222-222222222222';
const _storageKey = 'commerce.pending.member.$_tableSession';
const _channel = MethodChannel('kingclub/wechat-payment');
const _session = <String, dynamic>{
  'sessionId': 'session',
  'apiKeyId': 'key-id',
  'apiKey': 'key',
  'account': {'userAccount': 'member'},
};
const _product = OrderingCatalogProduct(
  'product-1',
  'category-1',
  {'en': 'Fixture'},
  {'en': 'unit'},
  100,
  3,
  2,
);

OrderingContext _context({String timing = 'prepay'}) => OrderingContext(
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
  tableSessionRef: _tableSession,
  businessDate: '2026-09-29',
  currency: 'CNY',
  timeZone: 'Asia/Shanghai',
  paymentTiming: timing,
);

class _Harness {
  int submitted = 0, queried = 0, confirmed = 0, launched = 0;
  String status = 'pending';
  bool missing = false;
  final submittedIds = <Object?>[];
  final queriedIds = <Object?>[];

  late final repository = OrderingOrderRepository(
    readSession: () async => _session,
    request: (id, params, _) async {
      if (id == 'K260919000814') {
        submitted++;
        submittedIds.add(params['requestId']);
      } else {
        queried++;
        queriedIds.add(params['requestId']);
        if (missing) {
          return {
            'result': {'notFound': true},
          };
        }
      }
      return {
        'result': {
          'orderRef': 'D00000000001',
          'storeRef': 'store',
          'tableId': 'fixture-table',
          'tableSessionRef': _tableSession,
          'totalCents': 100,
          'currency': 'CNY',
          'expiresAt': '2030-01-01T00:00:00Z',
          'status': status,
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

  Future<void> mount(
    WidgetTester tester, {
    bool saved = true,
    bool sameBasket = true,
    bool withOrderRef = true,
    String timing = 'prepay',
  }) async {
    FlutterSecureStorage.setMockInitialValues({
      if (saved)
        _storageKey: jsonEncode({
          'requestId': _requestId,
          'scope': jsonEncode([
            [
              sameBasket ? 'product-1' : 'old-product',
              _product.revision,
              1,
              100,
            ],
          ]),
          if (withOrderRef) 'orderRef': 'D00000000001',
        }),
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      launched++;
      return true;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LiveOrderPaymentPage(
          repository: repository,
          onBack: () {},
          quote: FakeOrderingQuote(
            itemCount: 1,
            total: 1,
            orderingContext: _context(timing: timing),
            onPaymentConfirmed: () => confirmed++,
            items: const [
              FakeOrderingQuoteItem(
                name: 'Current basket product',
                detail: 'unit',
                asset: '',
                quantity: 1,
                unitPrice: 1,
                unitPriceCents: 100,
                catalogProduct: _product,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    );
    expect(tester.takeException(), isNull);
  }
}

void main() {
  for (final withOrderRef in [true, false]) {
    testWidgets(
      'restore paid order confirms same basket without resubmitting: ref=$withOrderRef',
      (tester) async {
        final h = _Harness()..status = 'paid';
        await h.mount(tester, withOrderRef: withOrderRef);
        expect(find.byKey(const ValueKey('live-payment-success')), findsOneWidget);
        expect(h.confirmed, 1);
        expect(h.submitted, 0);
        expect(h.launched, 0);
        await tester.pump(const Duration(seconds: 8));
        expect(h.confirmed, 1);
        expect(h.queried, 1);
        expect(
          await const FlutterSecureStorage().read(key: _storageKey),
          isNull,
        );
        await h.finish(tester);
      },
    );
  }

  testWidgets(
    'different basket restores only old order; paid never clears current products',
    (tester) async {
      final h = _Harness();
      await h.mount(tester, sameBasket: false);
      expect(find.text('Current basket product'), findsNothing);
      expect(find.text('商品明细'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '立即支付'))
            .onPressed,
        isNull,
      );
      h.status = 'paid';
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.textContaining('当前购物车未改动'), findsOneWidget);
      expect(h.confirmed, 0);
      expect(h.submitted, 0);
      expect(h.launched, 0);
      await h.finish(tester);
    },
  );

  testWidgets('already-paid different basket preserves current cart', (
    tester,
  ) async {
    final h = _Harness()..status = 'paid';
    await h.mount(tester, sameBasket: false);
    expect(h.confirmed, 0);
    expect(h.submitted, 0);
    expect(find.text('Current basket product'), findsNothing);
    expect(find.byKey(const ValueKey('live-payment-success')), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('pending recovery reuses request ID and acknowledges only once', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await tester.tap(find.text('立即支付'));
    await tester.pumpAndSettle();
    expect(h.submittedIds, [_requestId]);
    expect(h.confirmed, 0);
    h.status = 'paid';
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 8));
    expect(h.confirmed, 1);
    expect(h.submitted, 1);
    await h.finish(tester);
  });

  testWidgets(
    'lost response with no order found retains the original idempotency key',
    (tester) async {
      final h = _Harness()..missing = true;
      await h.mount(tester, withOrderRef: false);
      expect(h.queriedIds, [_requestId]);
      h.missing = false;
      await tester.tap(find.text('立即支付'));
      await tester.pumpAndSettle();
      expect(h.submittedIds, [_requestId]);
      await h.finish(tester);
    },
  );

  testWidgets(
    'expired order stays terminal until the user returns to the cart',
    (tester) async {
      final h = _Harness()..status = 'expired';
      await h.mount(tester);
      expect(find.text('重新选购'), findsOneWidget);
      expect(find.text('立即支付'), findsNothing);
      expect(h.confirmed, 0);
      expect(h.submitted, 0);
      await h.finish(tester);
    },
  );

  testWidgets('iOS cannot create orders but may query an existing order', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester, saved: false);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '立即支付'))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('当前设备尚未开放微信付款'), findsOneWidget);
    expect(h.submitted, 0);
    await h.finish(tester);
    await h.mount(tester);
    expect(h.queried, 1);
    h.status = 'paid';
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(h.confirmed, 1);
    expect(h.submitted, 0);
    expect(h.launched, 0);
    await h.finish(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'postpay fails before submission with an explicit capability message',
    (tester) async {
      final h = _Harness();
      await h.mount(tester, saved: false, timing: 'postpay');
      expect(find.textContaining('尚未开放后付费下单'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '立即支付'))
            .onPressed,
        isNull,
      );
      expect(h.submitted, 0);
      await h.finish(tester);
    },
  );

  testWidgets(
    'missing native bridge disables relaunch and retains status recovery',
    (tester) async {
      final h = _Harness();
      await h.mount(tester, saved: false);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        (_) async => throw MissingPluginException('Fixture missing bridge'),
      );
      await tester.tap(find.text('立即支付'));
      await tester.pumpAndSettle();
      expect(h.submitted, 1);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '立即支付'))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('当前设备尚未开放微信付款'), findsOneWidget);
      h.status = 'paid';
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(h.confirmed, 1);
      expect(h.submitted, 1);
      await h.finish(tester);
    },
  );
}
