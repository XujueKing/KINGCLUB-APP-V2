import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';

class CashierLoginStore {
  const CashierLoginStore({required this.ref, required this.name});
  final String ref, name;
}

class CashierLoginChallenge {
  const CashierLoginChallenge({
    required this.status,
    required this.deviceLabel,
    required this.expiresAt,
    required this.stores,
  });
  final String status, deviceLabel;
  final DateTime expiresAt;
  final List<CashierLoginStore> stores;
}

abstract class CashierLoginRepository {
  Future<CashierLoginChallenge> inspect(String challengeId);
  Future<String> approve(String challengeId, String storeRef);
  Future<String> reject(String challengeId);
}

typedef CashierLoginSessionReader = Future<Map<String, dynamic>?> Function();
typedef CashierLoginRequest = Future<Map<String, dynamic>> Function(
  String interfaceId,
  Map<String, dynamic> params,
  Map<String, dynamic> session,
);

class SecureCashierLoginRepository implements CashierLoginRepository {
  SecureCashierLoginRepository({
    required this.readSession,
    required this.request,
  });

  factory SecureCashierLoginRepository.secure(String baseUrl) {
    final client = KingclubSecureClient(baseUrl);
    final sessions = SecureSessionStore();
    return SecureCashierLoginRepository(
      readSession: sessions.readSession,
      request: (id, params, session) =>
          client.call(id, params, session: session),
    );
  }

  final CashierLoginSessionReader readSession;
  final CashierLoginRequest request;
  List<String>? _binding;
  final Map<String, CashierLoginChallenge> _inspected = {};

  static Never _invalid() =>
      throw const AuthFailure('CASHIER_LOGIN_INVALID', '收银登录信息无效，请重新扫码');
  static Never _sessionChanged() =>
      throw const AuthFailure('SESSION_EXPIRED', '登录状态已变化，请重新扫码');

  static List<String> _identity(Map<String, dynamic>? session) {
    final account = session?['account'];
    final values = [
      account is Map ? account['userAccount'] : null,
      session?['sessionId'],
      session?['apiKeyId'],
      session?['apiKey'],
    ];
    if (values.any((v) => v is! String || v.isEmpty)) _sessionChanged();
    return values.cast<String>();
  }

  static String _text(dynamic value, int max) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > max ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      _invalid();
    }
    return value;
  }

  static String _ref(dynamic value) {
    final ref = _text(value, 64);
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(ref)) _invalid();
    return ref;
  }

  void _checkBinding(Map<String, dynamic>? session) {
    final identity = _identity(session);
    final bound = _binding;
    if (bound == null) {
      _binding = identity;
    } else if (List.generate(
      4,
      (i) => bound[i] == identity[i],
    ).contains(false)) {
      _sessionChanged();
    }
  }

  Future<Map> _call(
    String action,
    String challengeId, [
    String? storeRef,
  ]) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(challengeId)) _invalid();
    if (action != 'inspect' && !_inspected.containsKey(challengeId)) _invalid();
    final session = await readSession();
    _checkBinding(session);
    late final Map<String, dynamic> response;
    try {
      response = await request('K261004002009', {
        'action': action,
        'challengeId': challengeId,
        'storeRef': ?storeRef,
      }, session!);
    } finally {
      // A late success or failure must never be applied to a different login.
      _checkBinding(await readSession());
    }
    final result = response['result'];
    if (result is! Map) _invalid();
    return result;
  }

  static String _status(dynamic value) {
    if (value is! String ||
        !const ['pending', 'approved', 'rejected', 'expired'].contains(value)) {
      _invalid();
    }
    return value;
  }

  @override
  Future<CashierLoginChallenge> inspect(String challengeId) async {
    final result = await _call('inspect', challengeId);
    final status = _status(result['status']);
    final label = _text(result['deviceLabel'], 128);
    final expires = result['expiresAtMs'];
    final stores = result['stores'];
    if (expires is! int ||
        expires <= 0 ||
        expires > 8640000000000000 ||
        stores is! List ||
        stores.length > 1000) {
      _invalid();
    }
    final seen = <String>{};
    final parsed = <CashierLoginStore>[];
    for (final row in stores) {
      if (row is! Map) _invalid();
      final ref = _ref(row['storeRef']);
      if (!seen.add(ref)) _invalid();
      parsed.add(
        CashierLoginStore(ref: ref, name: _text(row['storeName'], 128)),
      );
    }
    final challenge = CashierLoginChallenge(
      status: status,
      deviceLabel: label,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expires, isUtc: true),
      stores: List.unmodifiable(parsed),
    );
    _inspected[challengeId] = challenge;
    return challenge;
  }

  @override
  Future<String> approve(String challengeId, String storeRef) async {
    _ref(storeRef);
    final challenge = _inspected[challengeId];
    if (challenge == null ||
        challenge.status != 'pending' ||
        !challenge.stores.any((s) => s.ref == storeRef)) {
      _invalid();
    }
    final result = await _call('approve', challengeId, storeRef);
    final status = _status(result['status']);
    if (status != 'approved') _invalid();
    return status;
  }

  @override
  Future<String> reject(String challengeId) async {
    final result = await _call('reject', challengeId);
    final status = _status(result['status']);
    if (status != 'rejected') _invalid();
    return status;
  }
}
