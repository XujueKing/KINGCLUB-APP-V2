import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/commerce/data/ordering_catalog_repository.dart';
import 'package:kingclub/src/features/commerce/data/ordering_context.dart';

const scope = OrderingContext(
  contextRef: '00000000-0000-4000-8000-000000000001',
  memberRef: 'member',
  storeRef: 'store',
  tableSessionRef: '00000000-0000-4000-8000-000000000001',
  storeName: 'Test',
  storeAddress: 'Test',
  tableName: 'T',
  businessDate: '2026-09-20',
  tableId: 'table',
  tenantRef: 'tenant',
  brandRef: 'brand',
  cityId: 'city',
  currency: 'CNY',
  timeZone: 'Asia/Shanghai',
  paymentTiming: 'prepay',
);
Map<String, dynamic> credentials() => {
  'sessionId': 's',
  'apiKeyId': 'k',
  'apiKey': 'synthetic',
  'account': {'userAccount': 'member'},
};
Map<String, dynamic> payload() => {
  'result': {
    'context': {
      'contextRef': scope.contextRef,
      'memberRef': 'member',
      'storeRef': 'store',
      'tableSessionRef': scope.tableSessionRef,
      'tableId': 'table',
      'tenantRef': 'tenant',
      'brandRef': 'brand',
      'cityId': 'city',
      'currency': 'CNY',
      'timeZone': 'Asia/Shanghai',
      'paymentTiming': 'prepay',
      'businessDate': '2026-09-20',
    },
    'categories': [
      {'categoryRef': 'category', 'majorCategory': 'liquor', 'names': names()},
    ],
    'products': [
      {
        'productRef': 'product',
        'categoryRef': 'category',
        'names': names(),
        'specifications': names(),
        'priceCents': 1999,
        'revision': 2,
        'available': 3,
        'soldOut': false,
      },
    ],
  },
};
Map<String, String> names() => {
  'zh-CN': '测试',
  'zh-TW': '測試',
  'en': 'Test',
  'th': 'ทดสอบ',
};
Matcher failure(String code) =>
    isA<AuthFailure>().having((e) => e.code, 'code', code);

void main() {
  test(
    'reads scoped server catalog preserving cents and four languages',
    () async {
      final repo = OrderingCatalogRepository(
        readSession: () async => credentials(),
        request: (id, params, session) async {
          expect(id, 'K260919000809');
          expect(params, {
            'tableId': 'table',
            'tableSessionRef': scope.tableSessionRef,
          });
          return payload();
        },
      );
      final result = await repo.read(scope);
      expect(result.products.single.priceText, '19.99');
      expect(result.products.single.revision, 2);
      expect(result.products.single.names['th'], 'ทดสอบ');
      expect(result.products.single.available, 3);
      expect(() => result.products.clear(), throwsUnsupportedError);
    },
  );
  test('rejects logged out before request', () async {
    final repo = OrderingCatalogRepository(
      readSession: () async => null,
      request: (_, _, _) async => throw StateError('must not call'),
    );
    await expectLater(repo.read(scope), throwsA(failure('SESSION_EXPIRED')));
  });
  test('discards result after in-flight credential mutation', () async {
    final current = credentials();
    final repo = OrderingCatalogRepository(
      readSession: () async => current,
      request: (_, _, _) async {
        current['sessionId'] = 'changed';
        return payload();
      },
    );
    await expectLater(repo.read(scope), throwsA(failure('SESSION_CHANGED')));
  });
  for (final field in [
    'memberRef',
    'storeRef',
    'tenantRef',
    'brandRef',
    'cityId',
    'tableSessionRef',
    'businessDate',
    'paymentTiming',
  ]) {
    test('rejects wrong $field', () async {
      final p = payload();
      p['result']['context'][field] = 'other';
      final repo = OrderingCatalogRepository(
        readSession: () async => credentials(),
        request: (_, _, _) async => p,
      );
      await expectLater(
        repo.read(scope),
        throwsA(failure('ORDERING_SESSION_CHANGED')),
      );
    });
  }
  for (final mutation in [
    'fraction',
    'negative',
    'soldOut',
    'duplicate',
    'orphan',
    'locale',
  ]) {
    test('rejects malformed product $mutation', () async {
      final p = payload(), product = p['result']['products'][0];
      switch (mutation) {
        case 'fraction':
          product['priceCents'] = 19.99;
        case 'negative':
          product['available'] = -1;
        case 'soldOut':
          product['soldOut'] = true;
        case 'duplicate':
          p['result']['products'].add(
            product,
          );
        case 'orphan':
          product['categoryRef'] = 'missing';
        case 'locale':
          product['names'].remove('th');
      }
      final repo = OrderingCatalogRepository(
        readSession: () async => credentials(),
        request: (_, _, _) async => p,
      );
      await expectLater(
        repo.read(scope),
        throwsA(failure('CATALOG_RESPONSE_INVALID')),
      );
    });
  }
  test('empty catalog remains empty', () async {
    final p = payload();
    p['result']['categories'] = [];
    p['result']['products'] = [];
    final repo = OrderingCatalogRepository(
      readSession: () async => credentials(),
      request: (_, _, _) async => p,
    );
    expect((await repo.read(scope)).products, isEmpty);
  });
}
