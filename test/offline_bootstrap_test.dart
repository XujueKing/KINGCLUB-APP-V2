import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/networking/kingclub_secure_client.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/data/auth_repository_provider.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

class _Offline extends KingclubSecureClient {
  _Offline({this.error = 'NETWORK_ERROR', this.gate})
    : super('https://example.invalid');
  final String error;
  final Future<void>? gate;
  final called = Completer<void>();
  @override
  Future<Map<String, dynamic>> call(
    String id,
    Map<String, dynamic> params, {
    Map<String, dynamic>? session,
    Duration? receiveTimeout,
  }) async {
    if (!called.isCompleted) called.complete();
    await gate;
    throw AuthFailure(error, 'test');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 9, 16);
  Map<String, dynamic> session() => {
    'sessionId': 'test-session',
    'apiKeyId': 'test-key',
    'apiKey': 'test-secret',
    'refreshExpiresAt': now.add(const Duration(days: 1)).toIso8601String(),
    'mobileVerifiedAt': now.toIso8601String(),
    'account': {'userAccount': 'me', 'accountStatus': 'active'},
    'membership': {'status': 'active', 'registrationStatus': 'approved'},
  };
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'approved local bootstrap works offline without renewing API credentials',
    () async {
      final store = SecureSessionStore();
      await store.saveSession(session());
      final snapshots = <AuthLoginResult>[];
      final repo = RealAuthRepository(
        _Offline(),
        store,
        now: () => now,
        onAuthenticated: snapshots.add,
      );
      expect((await repo.restoreForBootstrap())?.canEnterApp, isTrue);
      expect(snapshots, hasLength(1));
      expect(await store.readSession(), session());
      await expectLater(repo.restoreSession(), throwsA(isA<AuthFailure>()));
    },
  );
  for (final kind in ['unapproved', 'expired', 'suspended']) {
    test('$kind cannot enter from an offline snapshot', () async {
      final saved = session();
      if (kind == 'unapproved') {
        saved['membership'] = {
          'status': 'active',
          'registrationStatus': 'identity_required',
        };
      }
      if (kind == 'expired') saved['refreshExpiresAt'] = now.toIso8601String();
      if (kind == 'suspended') {
        saved['account'] = {'userAccount': 'me', 'accountStatus': 'suspended'};
      }
      final store = SecureSessionStore();
      await store.saveSession(saved);
      final repo = RealAuthRepository(_Offline(), store, now: () => now);
      await expectLater(
        repo.restoreForBootstrap(),
        throwsA(isA<AuthFailure>()),
      );
    });
  }
  test('explicit revocation does not fall back to local membership', () async {
    final store = SecureSessionStore();
    await store.saveSession(session());
    final repo = RealAuthRepository(
      _Offline(error: 'AUTH_SESSION_REVOKED'),
      store,
      now: () => now,
    );
    expect(await repo.restoreForBootstrap(), isNull);
    expect(await store.readSession(), isNull);
  });
  test('late offline failure cannot enter as a replacement account', () async {
    final store = SecureSessionStore();
    await store.saveSession(session());
    final gate = Completer<void>();
    final client = _Offline(gate: gate.future);
    final repo = RealAuthRepository(client, store, now: () => now);
    final pending = repo.restoreForBootstrap();
    await client.called.future;
    await store.saveSession({...session(), 'sessionId': 'other-session'});
    gate.complete();
    await expectLater(
      pending,
      throwsA(
        isA<AuthFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
      ),
    );
    expect((await store.readSession())?['sessionId'], 'other-session');
  });
}
