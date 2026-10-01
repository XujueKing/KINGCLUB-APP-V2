import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
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
  bool alipayUnavailable = false;
  bool soldOut = false;
  bool cancelUnknown = false;
  bool cancellationRequested = false;
  String cancelStatus = 'expired';
  int cancelled = 0;
  final submittedInitiation = <Object?>[];
  final submittedIds = <Object?>[];
  final queriedIds = <Object?>[];
  final submittedProviders = <Object?>[];

  late final repository = OrderingOrderRepository(
    readSession: () async => _session,
    request: (id, params, _) async {
      if (id == 'K260919000814') {
        submitted++;
        submittedInitiation.add(params['initiatePayment']);
        submittedIds.add(params['requestId']);
        submittedProviders.add(params['paymentProvider']);
        if (soldOut) throw const AuthFailure('ORDERING_OUT_OF_STOCK','Sold out');
        if (alipayUnavailable && params['paymentProvider'] == 'alipay') {
          throw const AuthFailure('ALIPAY_NOT_READY', 'Alipay unavailable');
        }
      } else if (id == 'K261001001958') {
        cancelled++;
        cancellationRequested = true;
        if (cancelUnknown) throw const AuthFailure('NETWORK_ERROR', 'Unknown');
        status = cancelStatus;
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
          'cancellationRequested': cancellationRequested,
          if (id == 'K260919000814' && params['initiatePayment'] != false)
            'payment': params['paymentProvider'] == 'alipay'
                ? {'provider': 'alipay', 'orderString': 'signed=fixture%2B%2F'}
                : {
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
    String? savedProvider,
  }) async {
    FlutterSecureStorage.setMockInitialValues({
      if (saved)
        _storageKey: jsonEncode({
          'requestId': _requestId,
          'paymentProvider': ?savedProvider,
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
  testWidgets('create only avoids SDK and later payment reuses original request', (tester) async {
    final h = _Harness();
    await h.mount(tester, saved: false);
    await tester.tap(find.byKey(const ValueKey('order-create-only')));
    await tester.pumpAndSettle();
    expect(h.submittedInitiation, [false]);
    expect(h.launched, 0);
    expect(h.confirmed, 0);
    expect(await const FlutterSecureStorage().read(key: _storageKey), isNotNull);
    await tester.tap(find.text('立即支付'));
    await tester.pumpAndSettle();
    expect(h.submittedInitiation, [false, true]);
    expect(h.submittedIds.toSet(), hasLength(1));
    expect(h.launched, 1);
    await h.finish(tester);
  });
  for (final result in ['expired', 'paid', 'pending', 'unknown']) {
    testWidgets('explicit cancellation honors authoritative result: $result', (tester) async {
      final h = _Harness()..cancelStatus = result == 'unknown' ? 'pending' : result..cancelUnknown = result == 'unknown';
      await h.mount(tester);
      final cancel = find.byKey(const ValueKey('order-cancel'));
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(h.cancelled, 1);
      expect(h.launched, 0);
      expect(h.confirmed, result == 'paid' ? 1 : 0);
      expect(await const FlutterSecureStorage().read(key: _storageKey), result == 'expired' || result == 'paid' ? isNull : isNotNull);
      await h.finish(tester);
    });
  }
  for (final result in ['expired','pending','missing','paid']) {
    testWidgets('sold-out retry clears saved request only after terminal proof: $result', (tester) async {
      final h=_Harness()..soldOut=true..status=result=='missing'?'pending':result..missing=result=='missing';
      await h.mount(tester,saved:false);
      await tester.tap(find.text('立即支付'));
      await tester.pumpAndSettle();
      expect(h.submitted,1);
      expect(h.launched,0);
      final saved=await const FlutterSecureStorage().read(key:_storageKey);
      expect(saved,result=='expired'||result=='paid'?isNull:isNotNull);
      expect(h.confirmed,result=='paid'?1:0);
      if(result=='expired')expect(find.textContaining('No charge was initiated'),findsOneWidget);
      if(result=='pending'||result=='missing')expect(find.textContaining('Checking the original order'),findsOneWidget);
      await h.finish(tester);
    });
  }
  for (final orderExists in [false, true]) {
    testWidgets(
      'disabled Alipay unlocks only after no-order lookup: exists=$orderExists',
      (tester) async {
        const alipay = MethodChannel('com.jarvanmo/tobias');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          alipay,
          (_) async => true,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _channel,
          (_) async => true,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            alipay,
            null,
          ),
        );
        final h = _Harness()
          ..alipayUnavailable = true
          ..missing = !orderExists;
        await h.mount(tester, saved: false);
        await tester.ensureVisible(
          find.byKey(const ValueKey('payment-provider-alipay')),
        );
        await tester.tap(find.byKey(const ValueKey('payment-provider-alipay')));
        await tester.tap(find.text('立即支付'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('payment-provider-wechat')),
        );
        await tester.tap(find.byKey(const ValueKey('payment-provider-wechat')));
        await tester.tap(find.text('立即支付'));
        await tester.pumpAndSettle();
        expect(h.submittedProviders, [
          'alipay',
          orderExists ? 'alipay' : 'wechat',
        ]);
        expect(h.submittedIds.toSet().length, 1);
        await h.finish(tester);
      },
    );
  }
  for (final restored in [false, true]) {
    testWidgets(
      'Alipay channel stays locked and SDK success still queries: restored=$restored',
      (tester) async {
        const alipay = MethodChannel('com.jarvanmo/tobias');
        var paidCalls = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(alipay, (
          call,
        ) async {
          if (call.method == 'isAliPayInstalled') return true;
          expect(call.method, 'pay');
          expect((call.arguments as Map)['order'], 'signed=fixture%2B%2F');
          paidCalls++;
          return {'resultStatus': '9000'};
        });
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            alipay,
            null,
          ),
        );
        final h = _Harness();
        await h.mount(tester, saved: restored, savedProvider: 'alipay');
        if (!restored) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('payment-provider-alipay')),
          );
          await tester.tap(
            find.byKey(const ValueKey('payment-provider-alipay')),
          );
          await tester.pump();
        }
        await tester.tap(find.text('立即支付'));
        await tester.pumpAndSettle();
        expect(paidCalls, 1);
        expect(h.confirmed, 0);
        expect(h.queried, greaterThanOrEqualTo(1));
        expect(h.submittedProviders, ['alipay']);
        final cache = jsonDecode(
          (await const FlutterSecureStorage().read(key: _storageKey))!,
        );
        expect(cache['paymentProvider'], 'alipay');
        await tester.ensureVisible(
          find.byKey(const ValueKey('payment-provider-wechat')),
        );
        await tester.tap(find.byKey(const ValueKey('payment-provider-wechat')));
        await tester.tap(find.text('立即支付'));
        await tester.pumpAndSettle();
        expect(h.submittedProviders, ['alipay', 'alipay']);
        expect(h.submittedIds.toSet().length, 1);
        h.status = 'paid';
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(h.confirmed, 1);
        expect(
          find.byKey(const ValueKey('live-payment-success')),
          findsOneWidget,
        );
        expect(
          await const FlutterSecureStorage().read(key: _storageKey),
          isNull,
        );
        await h.finish(tester);
      },
    );
  }

  testWidgets(
    'unknown persisted provider cannot be bypassed by selecting WeChat',
    (tester) async {
      final h = _Harness();
      await h.mount(tester, savedProvider: 'invalid');
      await tester.ensureVisible(
        find.byKey(const ValueKey('payment-provider-wechat')),
      );
      await tester.tap(find.byKey(const ValueKey('payment-provider-wechat')));
      await tester.tap(find.text('立即支付'));
      await tester.pumpAndSettle();
      expect(h.submitted, 0);
      expect(find.text('暂时无法恢复订单，请返回后重试'), findsOneWidget);
      await h.finish(tester);
    },
  );

  for (final withOrderRef in [true, false]) {
    testWidgets(
      'restore paid order confirms same basket without resubmitting: ref=$withOrderRef',
      (tester) async {
        final h = _Harness()..status = 'paid';
        await h.mount(tester, withOrderRef: withOrderRef);
        expect(
          find.byKey(const ValueKey('live-payment-success')),
          findsOneWidget,
        );
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
