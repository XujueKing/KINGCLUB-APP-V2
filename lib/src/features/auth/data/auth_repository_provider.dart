import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/mock/mock_runtime.dart';
import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../domain/auth_repository.dart';

const kingclubApiBaseUrl = String.fromEnvironment('KINGCLUB_API_BASE_URL');

final authenticatedMemberProvider =
    NotifierProvider<AuthenticatedMember, AuthLoginResult?>(
      AuthenticatedMember.new,
    );

class AuthenticatedMember extends Notifier<AuthLoginResult?> {
  @override
  AuthLoginResult? build() => null;
  void update(AuthLoginResult result) => state = result;
  void clear() => state = null;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (kingclubApiBaseUrl.isEmpty) {
    return MockAuthRepository(ref.read(mockRuntimeProvider));
  }
  return RealAuthRepository(
    KingclubSecureClient(kingclubApiBaseUrl),
    SecureSessionStore(),
    onAuthenticated: ref.read(authenticatedMemberProvider.notifier).update,
  );
});

class RealAuthRepository implements AuthRepository {
  RealAuthRepository(
    this._client,
    this._sessionStore, {
    this.onAuthenticated,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  DateTime? _mobileVerifiedAt;
  static const mobileLoginWindow = Duration(minutes: 15);
  bool _withinMobileWindow(DateTime? verifiedAt) {
    if (verifiedAt == null) return false;
    final age = _now().difference(verifiedAt);
    return !age.isNegative && age < mobileLoginWindow;
  }

  Future<bool> canResumeWithoutSms() async {
    if (_mobileVerifiedAt == null) {
      final saved = await _sessionStore.readSession();
      _mobileVerifiedAt = DateTime.tryParse('${saved?['mobileVerifiedAt']}');
    }
    if (_withinMobileWindow(_mobileVerifiedAt)) return true;
    await clearLocalSession();
    return false;
  }

  Future<void> clearLocalSession() async {
    _mobileVerifiedAt = null;
    _consents = null;
    await _sessionStore.clearSession();
  }

  final KingclubSecureClient _client;
  final SecureSessionStore _sessionStore;
  final void Function(AuthLoginResult)? onAuthenticated;
  List<Map<String, String>>? _consents;
  Future<AuthLoginResult?>? _restoring;

  Future<AuthLoginResult?> restoreSession() =>
      _restoring ??= _restoreSession().whenComplete(() => _restoring = null);

  Future<AuthLoginResult?> _restoreSession() async {
    final saved = await _sessionStore.readSession();
    if (saved == null) return null;
    _mobileVerifiedAt = DateTime.tryParse('${saved['mobileVerifiedAt']}');
    if (!_withinMobileWindow(_mobileVerifiedAt)) {
      await clearLocalSession();
      throw const AuthFailure('MOBILE_REVERIFICATION_REQUIRED', '请重新验证手机号');
    }
    try {
      try {
        return await refreshMembership();
      } on AuthFailure catch (error) {
        if (error.code != 'SESSION_EXPIRED') rethrow;
      }
      final deadline = DateTime.tryParse('${saved['refreshExpiresAt']}');
      if (deadline == null || !deadline.isAfter(DateTime.now())) {
        await _sessionStore.clearSession();
        return null;
      }
      final rotated = await _client.call('K260824000103', {
        'sessionId': saved['sessionId'],
        'refreshToken': saved['refreshToken'],
        'refreshTokenVersion': saved['refreshTokenVersion'],
        'clientAppCode': 'kingclub',
        'clientType': 'android',
        'deviceId': await _sessionStore.deviceId(),
      });
      await _sessionStore.saveSession({...saved, ...rotated});
      return await refreshMembership();
    } on AuthFailure catch (error) {
      if ({
        'SESSION_EXPIRED',
        'AUTH_SESSION_REVOKED',
        'AUTH_REFRESH_TOKEN_INVALID',
        'AUTH_REFRESH_REUSE_DETECTED',
      }.contains(error.code)) {
        await _sessionStore.clearSession();
        return null;
      }
      rethrow;
    }
  }

  Future<void> _loadConsents() async {
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
  }

  @override
  Future<AuthSmsChallenge> requestSms(String mobile) async {
    await _loadConsents();
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
    if (_consents == null) await _loadConsents();
    final consents = _consents;
    if (consents == null || consents.length != 2) {
      throw const AuthFailure('AUTH_CONSENT_REQUIRED', '请重新获取验证码');
    }
    final result = await _client.call('K260824000102', {
      if (challengeId.isNotEmpty) 'challengeId': challengeId,
      'mobile': mobile,
      'code': code,
      'consents': consents,
      'clientAppCode': 'kingclub',
      'clientType': 'android',
      'deviceId': await _sessionStore.deviceId(),
    });
    final snapshot = parseMembership(result);
    _mobileVerifiedAt = _now();
    await _sessionStore.saveSession({
      ...result,
      'mobileVerifiedAt': _mobileVerifiedAt!.toIso8601String(),
    });
    onAuthenticated?.call(snapshot);
    return snapshot;
  }

  Future<AuthLoginResult> refreshMembership() async {
    final session = await _sessionStore.readSession();
    if (session == null) {
      throw const AuthFailure('SESSION_EXPIRED', '登录已失效，请重新登录');
    }
    final result = await _client.call('K260824000104', {}, session: session);
    final snapshot = parseMembership(result);
    onAuthenticated?.call(snapshot);
    return snapshot;
  }

  static AuthLoginResult parseMembership(Map<String, dynamic> result) {
    if (result['membership'] is! Map || result['account'] is! Map) {
      throw const AuthFailure('MEMBERSHIP_INVALID', '会员状态暂时无法确认，请稍后重试');
    }
    final membership = Map<String, dynamic>.from(result['membership'] as Map);
    return AuthLoginResult(
      isNewMembership: result['isNewMembership'] == true,
      membershipStatus: '${membership['status']}',
      registrationStatus: '${membership['registrationStatus'] ?? 'unknown'}',
      accountStatus: '${(result['account'] as Map)['accountStatus']}',
      isRealSession: true,
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
      registrationStatus: _runtime.canEnterApp(id)
          ? 'approved'
          : 'identity_required',
      onboardingFlowId: id,
    );
  }
}
