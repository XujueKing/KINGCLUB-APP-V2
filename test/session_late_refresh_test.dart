import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/networking/kingclub_secure_client.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/data/auth_repository_provider.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

class _DelayedClient extends KingclubSecureClient {
  _DelayedClient() : super('https://example.invalid');
  final started = Completer<void>();
  final result = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> call(
    String id,
    Map<String, dynamic> params, {
    Map<String, dynamic>? session,
    Duration? receiveTimeout,
  }) {
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final first = <String, dynamic>{
    'sessionId': 'session-a',
    'apiKeyId': 'key-a',
    'apiKey': 'secret-a',
    'account': {'userAccount': 'member-a', 'accountStatus': 'active'},
    'membership': {'status': 'active', 'registrationStatus': 'approved'},
  };
  final second = <String, dynamic>{
    ...first,
    'sessionId': 'session-b',
    'apiKeyId': 'key-b',
    'apiKey': 'secret-b',
    'account': {'userAccount': 'member-b', 'accountStatus': 'active'},
  };
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'late membership response preserves rotated refresh credentials',
    () async {
      final store = SecureSessionStore();
      final original = {
        ...first,
        'refreshToken': 'old-token',
        'refreshTokenVersion': 1,
        'expiresAt': '2026-01-01T00:00:00Z',
      };
      await store.saveSession(original);
      await Future<void>.delayed(Duration.zero);
      final client = _DelayedClient();
      final pending = RealAuthRepository(client, store).refreshMembership();
      await client.started.future;
      var changes = 0;
      final subscription = SecureSessionStore.changes.stream.listen(
        (_) => changes++,
      );
      addTearDown(subscription.cancel);
      final rotated = {
        ...original,
        'refreshToken': 'new-token',
        'refreshTokenVersion': 2,
        'expiresAt': '2026-02-01T00:00:00Z',
      };
      await store.saveSessionIfCurrent(original, rotated);
      client.result.complete({
        'account': {...first['account'] as Map, 'nickname': 'Updated name'},
        'membership': first['membership'],
      });
      await pending;
      await Future<void>.delayed(Duration.zero);
      final saved = (await store.readSession())!;
      expect(saved['refreshToken'], 'new-token');
      expect(saved['refreshTokenVersion'], 2);
      expect(saved['expiresAt'], rotated['expiresAt']);
      expect(saved['account']['nickname'], 'Updated name');
      expect(changes, 0);
    },
  );
  for (final logout in [true, false]) {
    test(
      'late membership refresh after ${logout ? 'logout' : 'account switch'} is discarded',
      () async {
        final store = SecureSessionStore();
        await store.saveSession(first);
        final client = _DelayedClient();
        var authenticated = 0;
        final repo = RealAuthRepository(
          client,
          store,
          onAuthenticated: (_) => authenticated++,
        );
        final pending = repo.refreshMembership();
        final rejected = expectLater(
          pending,
          throwsA(
            isA<AuthFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
          ),
        );
        await client.started.future;
        if (logout) {
          await store.clearSession();
        } else {
          await SecureSessionStore().saveSession(second);
        }
        client.result.complete({
          'account': first['account'],
          'membership': first['membership'],
        });
        await rejected;
        expect(authenticated, 0);
        expect(await store.readSession(), logout ? isNull : equals(second));
      },
    );
  }
  test(
    'concurrent logout followed by stale save cannot restore credentials',
    () async {
      final store = SecureSessionStore();
      await store.saveSession(first);
      final logout = store.clearSession();
      final stale = SecureSessionStore().saveSessionIfCurrent(first, first);
      await logout;
      expect(await stale, isFalse);
      expect(await store.readSession(), isNull);
    },
  );
  test('late resume rejection cannot redirect the new login to SMS', () async {
    final store = SecureSessionStore();
    await store.saveSession(first);
    final client = _DelayedClient();
    final pending = RealAuthRepository(client, store).canResumeWithoutSms();
    await client.started.future;
    await store.saveSession(second);
    client.result.completeError(
      const AuthFailure('AUTH_SESSION_REVOKED', 'old login revoked'),
    );
    expect(await pending, isTrue);
    expect(await store.readSession(), second);
  });
  test('late auth failure cannot delete a newer login', () async {
    final store = SecureSessionStore();
    await store.saveSession(first);
    await store.saveSession(second);
    expect(await store.clearSessionIfCurrent(first), isFalse);
    expect(await store.readSession(), second);
  });
  test(
    'same-login profile updates can race without invalidating each other',
    () async {
      final store = SecureSessionStore();
      await store.saveSession(first);
      final results = await Future.wait([
        store.saveSessionIfCurrent(first, {...first, 'maskedMobile': 'first'}),
        SecureSessionStore().saveSessionIfCurrent(first, {
          ...first,
          'maskedMobile': 'second',
        }),
      ]);
      expect(results, [true, true]);
      expect((await store.readSession())!['maskedMobile'], 'second');
    },
  );
}
