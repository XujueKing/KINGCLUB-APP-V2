class AuthSmsChallenge {
  const AuthSmsChallenge({required this.id, required this.retryAfterSeconds});
  final String id;
  final int retryAfterSeconds;
}

class AuthLoginResult {
  const AuthLoginResult({
    required this.isNewMembership,
    required this.membershipStatus,
  });
  final bool isNewMembership;
  final String membershipStatus;
  bool get canEnterApp => !isNewMembership && membershipStatus == 'active';
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
