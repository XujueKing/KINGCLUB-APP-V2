
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/networking/kingclub_secure_client.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/authenticated_chat_api.dart';

class ExpiringClient extends KingclubSecureClient {
  ExpiringClient() : super('https://example.invalid');
  int rotations = 0, sends = 0;
  String failure = 'SESSION_EXPIRED';
  bool renewed = false;
  Future<void> Function()? beforeRotation;
  final messageIds = <Object?>[];
  @override
  Future<Map<String, dynamic>> call(
    String id,
    Map<String, dynamic> params, {
    Map<String, dynamic>? session,
    Duration? receiveTimeout,
  }) async {
    if (id == 'K260824000103') {
      rotations++;
      await beforeRotation?.call();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      renewed = true;
      return {
        'refreshToken': 'new',
        'refreshTokenVersion': 2,
        'expiresAt': '2100-01-01T00:00:00Z',
      };
    }
    if (id == 'K260824000104') {
      if (!renewed) {
        throw const AuthFailure('SESSION_EXPIRED', 'Session expired');
      }
      return {
        'account': session!['account'],
        'membership': session['membership'],
      };
    }
    sends++;
    messageIds.add(params['clientMessageId']);
    if (!renewed) throw AuthFailure(failure, 'failure');
    return {
      'result': {'ok': true},
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SecureSessionStore store;
  late ExpiringClient client;
  late Map<String, dynamic> saved;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    store = SecureSessionStore();
    client = ExpiringClient();
    saved = {
      'sessionId': 'a',
      'apiKeyId': 'key',
      'apiKey': 'secret',
      'refreshToken': 'old',
      'refreshTokenVersion': 1,
      'refreshExpiresAt': '2100-01-01T00:00:00Z',
      'expiresAt': '2020-01-01T00:00:00Z',
      'account': {'userAccount': 'member', 'accountStatus': 'active'},
      'membership': {'status': 'active', 'registrationStatus': 'approved'},
    };
    await store.saveSession(saved);
  });
  AuthenticatedChatApi api() => AuthenticatedChatApi(
    account: 'member',
    sessionId: 'a',
    client: client,
    store: store,
  );

  test(
    'concurrent expiry renews once and retries the same message IDs',
    () async {
      final results = await Future.wait(
        List.generate(
          8,
          (i) => api().call('send', {'clientMessageId': 'id-$i'}),
        ),
      );
      expect(results.every((row) => row['ok'] == true), isTrue);
      expect(client.rotations, 1);
      expect(client.sends, 16);
      for (var i = 0; i < 8; i++) {
        expect(client.messageIds.where((id) => id == 'id-$i').length, 2);
      }
    },
  );
  test('network failure is not retried as a session expiry', () async {
    client.failure = 'NETWORK_ERROR';
    await expectLater(api().call('send', {}), throwsA(isA<AuthFailure>()));
    expect(client.sends, 1);
    expect(client.rotations, 0);
  });
  test(
    'account change during rotation never retries under the new account',
    () async {
      client.beforeRotation = () => store.saveSession({
        ...saved,
        'sessionId': 'other',
        'account': {'userAccount': 'other', 'accountStatus': 'active'},
      });
      await expectLater(api().call('send', {}), throwsA(isA<AuthFailure>()));
      expect(client.sends, 1);
      expect((await store.readSession())!['sessionId'], 'other');
    },
  );
}
