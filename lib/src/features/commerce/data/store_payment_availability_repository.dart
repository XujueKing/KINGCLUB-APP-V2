import '../../auth/domain/auth_repository.dart';
import 'ordering_table_repository.dart';

class StorePaymentAvailabilityRepository {
  const StorePaymentAvailabilityRepository({
    required this.readSession,
    required this.request,
  });
  final OrderingSessionReader readSession;
  final OrderingContextRequest request;

  Future<bool> alipayAvailable(String storeRef) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(storeRef)) {
      throw const AuthFailure('ORDERING_STORE_INVALID', '门店信息无效');
    }
    final session = await readSession();
    final identity = _identity(session);
    if (identity == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    final response = await request('K261002001959', {
      'storeRef': storeRef,
    }, session!);
    if (_identity(await readSession()) != identity) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    }
    final result = response['result'];
    if (result is! Map ||
        result['storeRef'] != storeRef ||
        result['alipayAvailable'] is! bool) {
      throw const AuthFailure('PAYMENT_AVAILABILITY_INVALID', '支付配置状态暂不可用');
    }
    return result['alipayAvailable'] as bool;
  }

  String? _identity(Map<String, dynamic>? session) {
    final account = session?['account'];
    final values = [
      session?['sessionId'],
      session?['apiKeyId'],
      session?['apiKey'],
      account is Map ? account['userAccount'] : null,
    ];
    if (values.any((value) => value is! String || value.isEmpty)) return null;
    // Never logged or persisted; compare the exact session without delimiter collisions.
    return values.map((value) => '${(value as String).length}:$value').join();
  }
}
