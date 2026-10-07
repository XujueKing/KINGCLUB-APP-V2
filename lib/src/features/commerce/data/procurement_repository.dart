import 'package:flutter/foundation.dart';

import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import 'ordering_table_repository.dart';

typedef ProcurementCall = Future<Map<String, dynamic>> Function(
  Map<String, dynamic>,
);

class ProcurementRepository {
  const ProcurementRepository({
    required this.readSession,
    required this.request,
  });
  factory ProcurementRepository.secure() {
    final client = KingclubSecureClient(kingclubApiBaseUrl);
    return ProcurementRepository(
      readSession: SecureSessionStore().readSession,
      request: (id, p, s) => client.call(id, p, session: s),
    );
  }
  final OrderingSessionReader readSession;
  final OrderingContextRequest request;
  List<String>? _identity(Map<String, dynamic>? s) {
    final a = s?['account'];
    final parts = [
      s?['sessionId'],
      s?['apiKeyId'],
      s?['apiKey'],
      a is Map ? a['userAccount'] : null,
    ];
    return parts.any((v) => v is! String || v.isEmpty)
        ? null
        : parts.cast<String>();
  }

  Future<Map<String, dynamic>> call(Map<String, dynamic> p) async {
    final session = await readSession(), identity = _identity(session);
    if (identity == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    final response = await request('K261007002032', p, session!);
    if (!listEquals(identity, _identity(await readSession()))) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    }
    final result = response['result'];
    if (result is! Map ||
        (p['storeRef'] != null && result['storeRef'] != p['storeRef'])) {
      throw const AuthFailure('PROCUREMENT_RESPONSE_INVALID', '采购信息异常');
    }
    return Map<String, dynamic>.from(result);
  }
}
