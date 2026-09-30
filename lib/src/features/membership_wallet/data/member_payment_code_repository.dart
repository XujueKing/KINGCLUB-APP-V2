import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';

/// A consent action must not adopt a session selected during an async read.
class MemberPaymentCodeRepository {
  MemberPaymentCodeRepository({
    Future<Map<String, dynamic>?> Function()? readSession,
    Future<Map<String, dynamic>> Function(
      Map<String, dynamic> params,
      Map<String, dynamic> session,
    )?
    send,
    int Function()? generation,
  }) : _readSession = readSession ?? SecureSessionStore().readSession,
       _send = send ?? _sendCode,
       _generation = generation ?? (() => MemberQrMemory.generation);

  final Future<Map<String, dynamic>?> Function() _readSession;
  final Future<Map<String, dynamic>> Function(
    Map<String, dynamic>,
    Map<String, dynamic>,
  )
  _send;
  final int Function() _generation;

  static Future<Map<String, dynamic>> _sendCode(
    Map<String, dynamic> params,
    Map<String, dynamic> session,
  ) =>
      KingclubSecureClient(kingclubApiBaseUrl)
          .call('K260930000509', params, session: session);

  Future<Map<String, dynamic>> issue(
    Map<String, dynamic> params, {
    required bool Function() stillCurrent,
  }) async {
    final epoch = _generation();
    void check() {
      if (epoch != _generation() || !stillCurrent()) {
        throw StateError('PAYMENT_CODE_SESSION_CHANGED');
      }
    }

    check();
    final session = await _readSession();
    check();
    if (session == null) throw StateError('PAYMENT_CODE_SESSION_REQUIRED');
    final envelope = await _send(params, session);
    check();
    if (envelope['result'] is! Map) {
      throw const FormatException('Invalid payment code result');
    }
    return Map<String, dynamic>.from(envelope['result'] as Map);
  }
}
