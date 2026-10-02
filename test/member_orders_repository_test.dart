import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/commerce/data/member_orders_repository.dart';

Map<String, dynamic> orderFixture({String id = 'D00000000001'}) => {
  'orderRef': id,
  'storeRef': 'test-store',
  'storeName': 'Test store',
  'tableRef': 'test-table',
  'tableName': 'Test table',
  'sessionRef': 'H00000000001',
  'sessionStatus': 'open',
  'source': 'cashier',
  'paymentTiming': 'postpay',
  'status': 'pending',
  'currency': 'CNY',
  'totalCents': 2000,
  'refundedCents': 0,
  'createdAt': '2030-01-01T00:00:00.000Z',
  'expiresAt': null,
  'refundedAt': null,
  'items': [
    {
      'productRef': 'test-product',
      'quantity': 2,
      'priceCents': 1000,
      'servedQuantity': 1,
      'snapshot': {
        'revision': 1,
        'names': {
          'zh-CN': '测试商品',
          'zh-TW': '測試商品',
          'en': 'Test product',
          'th': 'สินค้าทดสอบ',
        },
        'specifications': {
          'zh-CN': '测试规格',
          'zh-TW': '測試規格',
          'en': 'Test size',
          'th': 'ขนาดทดสอบ',
        },
      },
    },
  ],
};
Map<String, dynamic> pageFixture({
  List<Map<String, dynamic>>? orders,
  String? next,
}) => {
  'observedAt': '2030-01-01T00:00:00.000Z',
  'orders': orders ?? [orderFixture()],
  'nextBeforeOrder': next,
};
const sessionFixture = <String, dynamic>{
  'sessionId': 'test-session',
  'apiKeyId': 'test-key-id',
  'apiKey': 'test-key',
  'account': {'userAccount': 'test-member'},
};

void main() {
  test(
    'table read requires matching server scope and rejects foreign rows',
    () async {
      var page = pageFixture();
      page['tableScope'] = {
        'storeRef': 'test-store',
        'tableRef': 'test-table',
        'sessionRef': 'H00000000001',
      };
      final repository = MemberOrdersRepository(
        readSession: () async => sessionFixture,
        request: (id, params, session) async {
          expect(params, {
            'tableRef': 'test-table',
            'sessionRef': 'H00000000001',
          });
          return {'result': page};
        },
      );
      Future<MemberOrdersSnapshot> read() => repository.readTable(
        storeRef: 'test-store',
        tableRef: 'test-table',
        sessionRef: 'H00000000001',
      );
      expect((await read()).orders, hasLength(1));
      (page['orders'] as List).first['sessionRef'] = 'H00000000002';
      await expectLater(read(), throwsA(isA<AuthFailure>()));
      page = pageFixture();
      await expectLater(read(), throwsA(isA<AuthFailure>()));
    },
  );
  test(
    'reads unified own orders without caller-supplied member or store',
    () async {
      final repo = MemberOrdersRepository(
        readSession: () async => sessionFixture,
        request: (id, params, session) async {
          expect(id, 'K261001001955');
          expect(params, isEmpty);
          expect(session, sessionFixture);
          return {'result': pageFixture()};
        },
      );
      final result = await repo.read();
      expect(result.orders.single.paymentTiming, 'postpay');
      expect(result.orders.single.expiresAt, isNull);
      expect(result.orders.single.items.single.remainingQuantity, 1);
      expect(() => result.orders.clear(), throwsUnsupportedError);
    },
  );
  test(
    'partial refund preserves gross and excludes returned units from delivery',
    () {
      final raw = orderFixture()
        ..addAll({
          'status': 'paid',
          'refundedCents': 1000,
          'refundedAt': '2030-01-01T01:00:00.000Z',
        });
      (raw['items'] as List).first['refundedQuantity'] = 1;
      final order = MemberOrder.parse(raw);
      expect(order.totalCents, 2000);
      expect(order.netPaidCents, 1000);
      expect(order.fullyRefunded, isFalse);
      expect(order.items.single.activeQuantity, 1);
      expect(order.items.single.remainingQuantity, 0);
      (raw['items'] as List).first['servedQuantity'] = 2;
      expect(() => MemberOrder.parse(raw), throwsA(isA<AuthFailure>()));
      (raw['items'] as List).first['servedQuantity'] = 1;
      (raw['items'] as List).first.remove('refundedQuantity');
      expect(() => MemberOrder.parse(raw), throwsA(isA<AuthFailure>()));
    },
  );
  test('retains paid total separately from refund', () {
    final order = orderFixture()
      ..addAll({
        'status': 'paid',
        'refundedCents': 2000,
        'refundedAt': '2030-01-01T01:00:00.000Z',
      });
    final value = MemberOrder.parse(order);
    expect(value.totalCents, 2000);
    expect(value.refundedCents, 2000);
    expect(value.status, 'paid');
  });
  test('rejects late response after member session or key changes', () async {
    for (final replacement in [
      null,
      {...sessionFixture, 'sessionId': 'other-session'},
      {...sessionFixture, 'apiKey': 'other-key'},
      {
        ...sessionFixture,
        'account': {'userAccount': 'other-member'},
      },
    ]) {
      Map<String, dynamic>? session = sessionFixture;
      final response = Completer<Map<String, dynamic>>(),
          called = Completer<void>();
      final repo = MemberOrdersRepository(
        readSession: () async => session,
        request: (_, _, _) {
          called.complete();
          return response.future;
        },
      );
      final pending = repo.read();
      final check = expectLater(
        pending,
        throwsA(
          isA<AuthFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
        ),
      );
      await called.future;
      session = replacement;
      response.complete({'result': pageFixture()});
      await check;
    }
  });
  test(
    'rejects missing session and invalid navigation without request',
    () async {
      var calls = 0;
      final repo = MemberOrdersRepository(
        readSession: () async => null,
        request: (_, _, _) async {
          calls++;
          return {};
        },
      );
      await expectLater(repo.read(), throwsA(isA<AuthFailure>()));
      await expectLater(
        repo.read(orderRef: 'fake-order'),
        throwsA(isA<AuthFailure>()),
      );
      await expectLater(
        repo.read(orderRef: 'D00000000001', beforeOrder: 'D00000000002'),
        throwsA(isA<AuthFailure>()),
      );
      expect(calls, 0);
    },
  );
  test('detail response must match the requested order', () async {
    final repo = MemberOrdersRepository(
      readSession: () async => sessionFixture,
      request: (_, params, _) async {
        expect(params, {'orderRef': 'D00000000002'});
        return {'result': pageFixture()};
      },
    );
    await expectLater(
      repo.read(orderRef: 'D00000000002'),
      throwsA(isA<AuthFailure>()),
    );
  });
  test('rejects pagination cursor mismatch and duplicated order', () {
    expect(
      () => MemberOrdersSnapshot.parse(pageFixture(next: 'D00000000001')),
      throwsA(isA<AuthFailure>()),
    );
    expect(
      () => MemberOrdersSnapshot.parse(
        pageFixture(orders: [orderFixture(), orderFixture()]),
      ),
      throwsA(isA<AuthFailure>()),
    );
  });
  test(
    'validates amounts, delivery progress, refund evidence and prepay expiry',
    () {
      for (final patch in [
        <String, dynamic>{'totalCents': 1000},
        {'refundedCents': 1000},
        {'currency': 'USD'},
        {'paymentTiming': 'prepay'},
        {'items': []},
        {'createdAt': 'not-a-date'},
      ]) {
        expect(
          () => MemberOrder.parse(orderFixture()..addAll(patch)),
          throwsA(isA<AuthFailure>()),
        );
      }
      final invalid = orderFixture();
      (invalid['items'] as List).first['servedQuantity'] = 3;
      expect(() => MemberOrder.parse(invalid), throwsA(isA<AuthFailure>()));
    },
  );
}
