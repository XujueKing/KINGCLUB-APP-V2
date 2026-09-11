class AuthSmsChallenge {
  const AuthSmsChallenge({required this.id, required this.retryAfterSeconds});
  final String id;
  final int retryAfterSeconds;
}

class AuthLoginResult {
  const AuthLoginResult({
    required this.isNewMembership,
    required this.membershipStatus,
    this.registrationStatus = 'identity_required',
    this.accountStatus = 'active',
    this.isRealSession = false,
    this.onboardingFlowId,
    this.publicDecisionReason,
  });
  final bool isNewMembership;
  final String membershipStatus;
  final String registrationStatus;
  final String accountStatus;
  final bool isRealSession;
  final String? onboardingFlowId;
  final String? publicDecisionReason;
  bool get canEnterApp =>
      accountStatus == 'active' &&
      membershipStatus == 'active' &&
      registrationStatus == 'approved';
  bool get needsIdentity =>
      accountStatus == 'active' &&
      membershipStatus == 'active' &&
      registrationStatus == 'identity_required';
  bool get needsImages =>
      accountStatus == 'active' &&
      membershipStatus == 'active' &&
      (registrationStatus == 'photos_required' ||
          registrationStatus == 'changes_required');
  bool get needsPreferences =>
      accountStatus == 'active' &&
      membershipStatus == 'active' &&
      registrationStatus == 'preferences_required';
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  Future<AuthSmsChallenge> requestSms(String mobile);
  Future<AuthLoginResult> login({
    required String mobile,
    required String challengeId,
    required String code,
  });
}
