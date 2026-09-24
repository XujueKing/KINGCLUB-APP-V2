import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/commerce/data/ordering_table_repository.dart';

Map<String, dynamic> session() => {
  'sessionId': 'session-a',
  'apiKeyId': 'key-a',
  'apiKey': 'synthetic-key',
  'account': {'userAccount': 'member-a'},
};
Map<String, dynamic> result() => {
  'paymentTiming': 'prepay',
  'contextRef': 'session-table-a',
  'tableSessionRef': 'session-table-a',
  'tableId': 'table-a',
  'memberRef': 'member-a',
  'storeRef': 'store-a',
  'tenantRef': 'tenant-a',
  'brandRef': 'brand-a',
  'cityId': 'city-a',
  'cityName': 'Test city',
  'storeName': 'Test store',
  'storeAddress': 'Test address',
  'tableName': 'T1',
  'businessDate': '2026-09-19',
  'currency': 'CNY',
  'timeZone': 'Asia/Shanghai',
};
Matcher failure(String code) =>
    isA<AuthFailure>().having((error) => error.code, 'code', code);

void main() {
  test('an empty display address does not invalidate verified table scope', () async {
    final repository = OrderingTableRepository(
      readSession: () async => session(),
      request: (_, _, _) async => {'result': {...result(), 'storeAddress': ''}},
    );
    final context = await repository.resolve('table-a');
    expect(context.storeAddress, '');
    expect(context.tableId, 'table-a');
  });

  test('missing or non-text address remains an invalid response', () async {
    for (final value in [null, 42]) {
      final repository = OrderingTableRepository(
        readSession: () async => session(),
        request: (_, _, _) async => {'result': {...result(), 'storeAddress': value}},
      );
      await expectLater(repository.resolve('table-a'), throwsA(failure('ORDERING_CONTEXT_INVALID')));
    }
  });
  test(
    'sends normalized locator and uses only verified server scope',
    () async {
      final repository = OrderingTableRepository(
        readSession: () async => session(),
        request: (id, params, credentials) async {
          expect(id, 'K260919000801');
          expect(params, {'tableId': 'table-a', 'shopId': '0'});
          expect(credentials['sessionId'], 'session-a');
          return {'result': result()};
        },
      );
      final context = await repository.resolve('table-a', shopId: '0');
      expect(context.storeRef, 'store-a');
      expect(context.tenantRef, 'tenant-a');
      expect(context.cityId, 'city-a');
      expect(context.tableName, 'T1');
    expect(context.tableId, 'table-a');
    expect(context.paymentTiming, 'prepay');
    },
  );

  test(
    'rejects invalid locator and signed-out calls without requests',
    () async {
      var calls = 0;
      final repository = OrderingTableRepository(
        readSession: () async => null,
        request: (_, _, _) async {
          calls++;
          return {};
        },
      );
      await expectLater(
        repository.resolve('../table-a'),
        throwsA(failure('ORDERING_CODE_INVALID')),
      );
      await expectLater(
        repository.resolve('table-a'),
        throwsA(failure('SESSION_EXPIRED')),
      );
      expect(calls, 0);
    },
  );

  for (final replacement in [
    null,
    {...session(), 'sessionId': 'session-b'},
    {
      ...session(),
      'account': {'userAccount': 'member-b'},
    },
  ]) {
    test(
      'discards inflight result after session changes: $replacement',
      () async {
        Map<String, dynamic>? current = session();
        final started = Completer<void>();
        final response = Completer<Map<String, dynamic>>();
        final repository = OrderingTableRepository(
          readSession: () async => current,
          request: (_, _, _) {
            started.complete();
            return response.future;
          },
        );
        final pending = repository.resolve('table-a');
        final assertion = expectLater(
          pending,
          throwsA(failure('SESSION_CHANGED')),
        );
        await started.future;
        current = replacement;
        response.complete({'result': result()});
        await assertion;
      },
    );
  }

  test('rejects mismatched, incomplete and invalid-date responses', () async {
    for (final entry in {
      'memberRef': 'other-member',
      'tableId': 'other-table',
      'contextRef': 'other-session',
      'tenantRef': '',
      'cityId': null,
      'businessDate': '2026-02-30',
      'paymentTiming': 'unknown',
    }.entries) {
      final repository = OrderingTableRepository(
        readSession: () async => session(),
        request: (_, _, _) async => {
          'result': {...result(), entry.key: entry.value},
        },
      );
      await expectLater(
        repository.resolve('table-a'),
        throwsA(failure('ORDERING_CONTEXT_INVALID')),
      );
    }
  });

  test('does not swallow service errors or return demo data', () async {
    final repository = OrderingTableRepository(
      readSession: () async => session(),
      request: (_, _, _) async =>
          throw const AuthFailure('ORDERING_TABLE_NOT_OPEN', 'not open'),
    );
    await expectLater(
      repository.resolve('table-a'),
      throwsA(failure('ORDERING_TABLE_NOT_OPEN')),
    );
  });
}
