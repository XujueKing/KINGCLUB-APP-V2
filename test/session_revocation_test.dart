import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  const old = <String, dynamic>{
    'sessionId': 'old-session',
    'account': {'userAccount': 'member'},
  };
  const fresh = <String, dynamic>{
    'sessionId': 'new-session',
    'account': {'userAccount': 'member'},
  };

  test('queued old revocation preserves a newly saved login', () async {
    final store = SecureSessionStore();
    await store.saveSession(old);
    final login = store.saveSession(fresh);
    final revocation = SecureSessionStore().clearRevokedSession('old-session');
    await login;
    expect(await revocation, false);
    expect(await store.readSession(), fresh);
  });

  test(
    'current session revocation survives token rotation and is idempotent',
    () async {
      final store = SecureSessionStore();
      await store.saveSession({...old, 'refreshTokenVersion': 2});
      expect(await store.clearRevokedSession('old-session'), true);
      expect(await store.readSession(), isNull);
      expect(await store.clearRevokedSession('old-session'), false);
    },
  );

  test('empty or unrelated session never clears current login', () async {
    final store = SecureSessionStore();
    await store.saveSession(fresh);
    expect(await store.clearRevokedSession(''), false);
    expect(await store.clearRevokedSession('another-session'), false);
    expect(await store.readSession(), fresh);
  });
}
