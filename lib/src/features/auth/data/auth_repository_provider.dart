import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/mock/mock_runtime.dart';
import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../domain/auth_repository.dart';

const kingclubApiBaseUrl = String.fromEnvironment('KINGCLUB_API_BASE_URL');

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (kingclubApiBaseUrl.isEmpty) {
    return MockAuthRepository(ref.read(mockRuntimeProvider));
  }
  return RealAuthRepository(
    KingclubSecureClient(kingclubApiBaseUrl),
    SecureSessionStore(),
  );
});

class RealAuthRepository implements AuthRepository {
  RealAuthRepository(this._client, this._sessionStore);
  final KingclubSecureClient _client;
  final SecureSessionStore _sessionStore;
  List<Map<String, String>>? _consents;

  @override
  Future<AuthSmsChallenge> requestSms(String mobile) async {
    final catalog = await _client.call('K260824000107', {
      'clientAppCode': 'kingclub',
      'clientType': 'android',
      'locale': 'zh-CN',
    });
    final agreements = (catalog['agreements'] as List).cast<Map>();
    _consents = agreements
        .map(
          (item) => {
            'agreementCode': '${item['agreementCode']}',
            'version': '${item['version']}',
          },
        )
        .toList(growable: false);
    final deviceId = await _sessionStore.deviceId();
    final result = await _client.call('K260824000101', {
      'mobile': mobile,
      'scene': 'login',
      'idempotencyKey': 'sms_${const Uuid().v4()}',
      'clientAppCode': 'kingclub',
      'clientType': 'android',
      'deviceId': deviceId,
    });
    return AuthSmsChallenge(
      id: result['challengeId'] as String,
      retryAfterSeconds: (result['retryAfterSeconds'] as num?)?.toInt() ?? 60,
    );
  }

  @override
  Future<AuthLoginResult> login({
    required String mobile,
    required String challengeId,
    required String code,
  }) async {
    final consents = _consents;
    if (consents == null || consents.length != 2) {
      throw const AuthFailure('AUTH_CONSENT_REQUIRED', '请重新获取验证码');
    }
    final result = await _client.call('K260824000102', {
      'challengeId': challengeId,
      'mobile': mobile,
      'code': code,
      'consents': consents,
      'clientAppCode': 'kingclub',
      'clientType': 'android',
      'deviceId': await _sessionStore.deviceId(),
    });
    await _sessionStore.saveSession(result);
    final membership = Map<String, dynamic>.from(result['membership'] as Map);
    return AuthLoginResult(
      isNewMembership: result['isNewMembership'] == true,
      membershipStatus: '${membership['status']}',
    );
  }
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._runtime);
  final MockRuntime _runtime;

  @override
  Future<AuthSmsChallenge> requestSms(String mobile) async {
    try {
      final flow = await _runtime.requestSms(mobile);
      return AuthSmsChallenge(id: flow.id, retryAfterSeconds: 60);
    } on MockSmsRequestException catch (error) {
      throw AuthFailure(error.failure.name, '短信请求失败');
    }
  }

  @override
  Future<AuthLoginResult> login({
    required String mobile,
    required String challengeId,
    required String code,
  }) async {
    final outcome = await _runtime.verifyCode(flowId: challengeId, code: code);
    if (outcome != CodeVerificationOutcome.verified) {
      throw AuthFailure(outcome.name, '验证码不正确，请重新输入');
    }
    final id = _runtime.startOnboarding(loginFlowId: challengeId);
    return AuthLoginResult(
      isNewMembership: !_runtime.canEnterApp(id),
      membershipStatus: _runtime.canEnterApp(id) ? 'active' : 'applicant',
    );
  }
}
