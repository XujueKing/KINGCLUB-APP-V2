import 'package:flutter_test/flutter_test.dart';

import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/commerce/data/ordering_catalog_repository.dart';
import 'package:kingclub/src/features/commerce/data/ordering_context.dart';
import 'package:kingclub/src/features/commerce/data/ordering_order_repository.dart';

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
    tableId: 'K24000000001',
    storeRef: 'store',
    tenantRef: 'tenant',
    brandRef: 'brand',
    cityId: 'zhuzhou',
    cityName: '株洲市',
    storeName: '克洛泽清吧',
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

  test('submits only server re-pricing fields and parses receipt', () async {
    Map<String, dynamic>? sent;
    final repo = OrderingOrderRepository(
      readSession: () async => session,
      request: (id, params, _) async {
        expect(id, 'K260919000814');
        sent = params;
        return {
          'result': {
            'orderRef': '33333333-3333-3333-3333-333333333333',
            'storeRef': 'store',
            'tableId': 'K24000000001',
            'tableSessionRef': context.tableSessionRef,
            'status': 'awaitingPayment',
            'totalCents': 38800,
            'currency': 'CNY',
            'expiresAt': '2026-09-22T12:00:00Z',
          },
        };
      },
    );
    final receipt = await repo.submit(
      context: context,
      requestId: '44444444-4444-4444-4444-444444444444',
      lines: [const OrderingOrderLine(product: product, quantity: 1)],
    );
    expect(receipt.totalCents, 38800);
    expect(sent!['items'], [
      {
        'productRef': 'product-1',
        'quantity': 1,
        'expectedRevision': 3,
        'expectedPriceCents': 38800,
      },
    ]);
    expect(sent!.containsKey('totalCents'), isFalse);
    expect(sent!.containsKey('paymentState'), isFalse);
  });

  test('rejects duplicate lines before network request', () async {
    var called = false;
    final repo = OrderingOrderRepository(
      readSession: () async => session,
      request: (_, _, _) async {
        called = true;
        return <String, dynamic>{};
      },
    );
    await expectLater(
      repo.submit(
        context: context,
        requestId: '44444444-4444-4444-4444-444444444444',
        lines: [
          const OrderingOrderLine(product: product, quantity: 1),
          const OrderingOrderLine(product: product, quantity: 1),
        ],
      ),
      throwsA(isA<AuthFailure>()),
    );
    expect(called, isFalse);
  });
  test('owned payment requires the same order and scope and accepts authoritative cents', () async {
    var wrong = false;
    final repo = OrderingOrderRepository(
      readSession: () async => session,
      request: (id, params, _) async {
        expect(id, 'K260919000815');
        expect(params, {'orderRef': 'D00000000001'});
        return {
          'result': {
            'orderRef': wrong ? 'D00000000002' : 'D00000000001',
            'storeRef': 'store',
            'tableId': context.tableId,
            'tableSessionRef': context.tableSessionRef,
            'status': 'paid',
            'totalCents': 10,
            'currency': 'CNY',
            'expiresAt': '2026-09-25T12:00:00Z',
          },
        };
      },
    );
    final receipt = await repo.owned(
      context: context,
      orderRef: 'D00000000001',
    );
    expect(receipt.totalCents, 10);
    expect(receipt.status, 'paid');
    wrong = true;
    await expectLater(
      repo.owned(context: context, orderRef: 'D00000000001'),
      throwsA(isA<AuthFailure>()),
    );
  });
  test(
    'does not accept a payment result after switching login sessions',
    () async {
      var reads = 0;
      final repo = OrderingOrderRepository(
        readSession: () async => reads++ == 0 ? session : null,
        request: (_, _, _) async => {'result': {}},
      );
      await expectLater(
        repo.owned(context: context, orderRef: 'D00000000001'),
        throwsA(
          isA<AuthFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
        ),
      );
    },
  );
}
