import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';

/// Retry only an explicit pre-dispatch session expiry, with the original IDs.
class AuthenticatedChatApi {
  AuthenticatedChatApi({
    required this.account,
    required this.sessionId,
    required this.client,
    required this.store,
  }) : _generation = MemberQrMemory.generation;

  final String account, sessionId;
  final KingclubSecureClient client;
  final SecureSessionStore store;
  final int _generation;

  Future<Map<String, dynamic>> _session() async {
    final current = await store.readSession();
    if (_generation != MemberQrMemory.generation ||
        current == null ||
        (current['account'] as Map?)?['userAccount'] != account ||
        current['sessionId'] != sessionId) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变化，请重新进入会话');
    }
    return current;
  }

  Future<Map<String, dynamic>> call(
    String id,
    Map<String, dynamic> params,
  ) async {
    for (var attempt = 0; ; attempt++) {
      final current = await _session();
      try {
        final data = await client.call(
          id,
          params,
          session: current,
          receiveTimeout: id == 'K260915000669'
              ? const Duration(seconds: 125)
              : (id == 'K260915000674' || id == 'K260915000675')
              ? const Duration(seconds: 65)
              : null,
        );
        await _session();
        return Map<String, dynamic>.from(data['result'] as Map);
      } on AuthFailure catch (error) {
        if (error.code != 'SESSION_EXPIRED' || attempt != 0) rethrow;
        await _session();
        final restored = await RealAuthRepository(
          client,
          store,
        ).restoreSession();
        if (restored == null) {
          throw const AuthFailure('SESSION_EXPIRED', '登录已失效，请重新登录');
        }
        await _session();
      }
    }
  }
}
