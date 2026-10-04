import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/scanner/data/cashier_login_repository.dart';

void main() {
  final id = 'a' * 64;
  Map<String, dynamic> session([String account = 'member']) => {
    'account': {'userAccount': account},
    'sessionId': 'session',
    'apiKeyId': 'key',
    'apiKey': 'secret',
  };
  Map<String, dynamic> challenge() => {
    'status': 'pending',
    'deviceLabel': '收银机一',
    'expiresAtMs': 1900000000000,
    'stores': [
      {'storeRef': 'store-1', 'storeName': 'KING'},
    ],
  };
  test(
    'exact member interface parameters and immutable store results',
    () async {
      final calls = <Map<String, dynamic>>[];
      final repo = SecureCashierLoginRepository(
        readSession: () async => session(),
        request: (interface, params, auth) async {
          expect(interface, 'K261004002009');
          expect(auth['account'], {'userAccount': 'member'});
          calls.add(params);
          return {
            'result': params['action'] == 'inspect'
                ? challenge()
                : {
                    'status': params['action'] == 'approve'
                        ? 'approved'
                        : 'rejected',
                  },
          };
        },
      );
      final inspected = await repo.inspect(id);
      expect(inspected.stores.single.name, 'KING');
      expect(() => inspected.stores.clear(), throwsUnsupportedError);
      expect(await repo.approve(id, 'store-1'), 'approved');
      expect(await repo.reject(id), 'rejected');
      expect(calls, [
        {'action': 'inspect', 'challengeId': id},
        {'action': 'approve', 'challengeId': id, 'storeRef': 'store-1'},
        {'action': 'reject', 'challengeId': id},
      ]);
    },
  );
  test('changed identity blocks approval before request', () async {
    var current = session();
    var requests = 0;
    final repo = SecureCashierLoginRepository(
      readSession: () async => current,
      request: (_, _, _) async {
        requests++;
        return {'result': challenge()};
      },
    );
    await repo.inspect(id);
    current = session('other');
    await expectLater(repo.approve(id, 'store-1'), throwsA(isA<AuthFailure>()));
    expect(requests, 1);
  });
  test('late result is rejected after session credentials change', () async {
    var current = session();
    final pending = Completer<Map<String, dynamic>>();
    final started = Completer<void>();
    final repo = SecureCashierLoginRepository(
      readSession: () async => current,
      request: (_, _, _) {
        started.complete();
        return pending.future;
      },
    );
    final result = repo.inspect(id);
    final assertion = expectLater(result, throwsA(isA<AuthFailure>()));
    await started.future;
    current = {...current, 'sessionId': 'replacement'};
    pending.complete({'result': challenge()});
    await assertion;
  });
  test('missing login sends no request', () async {
    final repo = SecureCashierLoginRepository(
      readSession: () async => null,
      request: (_, _, _) async => throw StateError('must not request'),
    );
    await expectLater(repo.inspect(id), throwsA(isA<AuthFailure>()));
  });
  test('uninspected or unlisted store is never approved', () async {
    var calls = 0;
    final repo = SecureCashierLoginRepository(
      readSession: () async => session(),
      request: (_, _, _) async {
        calls++;
        return {'result': challenge()};
      },
    );
    await expectLater(repo.approve(id, 'store-1'), throwsA(isA<AuthFailure>()));
    await repo.inspect(id);
    await expectLater(repo.approve(id, 'other'), throwsA(isA<AuthFailure>()));
    expect(calls, 1);
  });
  test('invalid challenge rejected without network', () async {
    final repo = SecureCashierLoginRepository(
      readSession: () async => session(),
      request: (_, _, _) async => throw StateError('must not request'),
    );
    for (final invalid in ['$id\n', id.toUpperCase(), 'a' * 63]) {
      await expectLater(repo.inspect(invalid), throwsA(isA<AuthFailure>()));
    }
  });
  test(
    'malformed server responses do not produce an approvable challenge',
    () async {
      for (final malformed in [
        {...challenge(), 'status': 'unknown'},
        {...challenge(), 'deviceLabel': ''},
        {...challenge(), 'deviceLabel': 'x' * 129},
        {...challenge(), 'expiresAtMs': '1900000000000'},
        {...challenge(), 'expiresAtMs': -1},
        {
          ...challenge(),
          'stores': [
            {'storeRef': 'store-1', 'storeName': 'A'},
            {'storeRef': 'store-1', 'storeName': 'B'},
          ],
        },
        {
          ...challenge(),
          'stores': [
            {'storeRef': 'bad/ref', 'storeName': 'A'},
          ],
        },
        {
          ...challenge(),
          'stores': [
            {'storeRef': 'ok', 'storeName': null},
          ],
        },
      ]) {
        final repo = SecureCashierLoginRepository(
          readSession: () async => session(),
          request: (_, _, _) async => {'result': malformed},
        );
        await expectLater(repo.inspect(id), throwsA(isA<AuthFailure>()));
        await expectLater(
          repo.approve(id, 'store-1'),
          throwsA(isA<AuthFailure>()),
        );
      }
    },
  );
  test('unexpected approval status is not success', () async {
    final repo = SecureCashierLoginRepository(
      readSession: () async => session(),
      request: (_, params, _) async => {
        'result': params['action'] == 'inspect'
            ? challenge()
            : {'status': 'pending'},
      },
    );
    await repo.inspect(id);
    await expectLater(repo.approve(id, 'store-1'), throwsA(isA<AuthFailure>()));
  });

  test('approval arriving after logout cannot report success', () async {
    Map<String, dynamic>? current = session();
    final pending = Completer<Map<String, dynamic>>();
    final started = Completer<void>();
    final repo = SecureCashierLoginRepository(
      readSession: () async => current,
      request: (_, params, _) async {
        if (params['action'] == 'inspect') return {'result': challenge()};
        started.complete();
        return pending.future;
      },
    );
    await repo.inspect(id);
    final assertion = expectLater(
      repo.approve(id, 'store-1'),
      throwsA(isA<AuthFailure>()),
    );
    await started.future;
    current = null;
    pending.complete({
      'result': {'status': 'approved'},
    });
    await assertion;
  });

  test(
    'server denial is preserved without fallback or session mutation',
    () async {
      final repo = SecureCashierLoginRepository(
        readSession: () async => session(),
        request: (_, _, _) async =>
            throw const AuthFailure('CASHIER_LOGIN_DENIED', '当前账号没有收银授权'),
      );
      await expectLater(
        repo.inspect(id),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            'CASHIER_LOGIN_DENIED',
          ),
        ),
      );
    },
  );
}
