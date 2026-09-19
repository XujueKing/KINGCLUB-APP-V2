import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import 'ordering_context.dart';

typedef OrderingSessionReader = Future<Map<String, dynamic>?> Function();
typedef OrderingContextRequest = Future<Map<String, dynamic>> Function(
  String interfaceId,
  Map<String, dynamic> params,
  Map<String, dynamic> session,
);

/// Reads verified table scope only; never authorizes seating or payment.
class OrderingTableRepository {
  OrderingTableRepository({
    required this.readSession,
    required this.request,
  });

  factory OrderingTableRepository.secure(String baseUrl) {
    final client = KingclubSecureClient(baseUrl);
    final sessions = SecureSessionStore();
    return OrderingTableRepository(
      readSession: sessions.readSession,
      request: (id, params, session) =>
          client.call(id, params, session: session),
    );
  }

  final OrderingSessionReader readSession;
  final OrderingContextRequest request;
  static final _reference = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  Future<OrderingContext> resolve(String tableId, {String? shopId}) async {
    if (!_reference.hasMatch(tableId) ||
        (shopId != null && !_reference.hasMatch(shopId))) {
      throw const AuthFailure('ORDERING_CODE_INVALID', '桌卡信息无效');
    }
    final session = await readSession();
    final account = session?['account'];
    final member = account is Map ? account['userAccount'] : null;
    if (session == null ||
        member is! String ||
        member.isEmpty ||
        ['sessionId', 'apiKeyId', 'apiKey'].any(
          (key) => session[key] is! String || (session[key] as String).isEmpty,
        )) {
      throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    }
    final response = await request('K260919000801', {
      'tableId': tableId,
      'shopId': ?shopId,
    }, session);
    final current = await readSession();
    final currentAccount = current?['account'];
    if (current == null ||
        currentAccount is! Map ||
        currentAccount['userAccount'] != member ||
        [
          'sessionId',
          'apiKeyId',
          'apiKey',
        ].any((key) => current[key] != session[key])) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变更，请重新扫码');
    }
    final result = response['result'];
    if (result is! Map) _invalid();
    String field(String key) {
      final value = result[key];
      if (value is! String || value.trim().isEmpty) _invalid();
      return value;
    }

    final resolvedTable = field('tableId');
    final resolvedMember = field('memberRef');
    final contextRef = field('contextRef');
    final tableSessionRef = field('tableSessionRef');
    final storeRef = field('storeRef');
    if (resolvedTable != tableId ||
        resolvedMember != member ||
        contextRef != tableSessionRef ||
        (shopId != null && shopId != '0' && shopId != storeRef)) {
      _invalid();
    }
    final businessDate = field('businessDate');
    final parsedDate = DateTime.tryParse(businessDate);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(businessDate) ||
        parsedDate == null ||
        parsedDate.toIso8601String().substring(0, 10) != businessDate) {
      _invalid();
    }
    final paymentTiming = field('paymentTiming');
    if (paymentTiming != 'prepay' && paymentTiming != 'postpay') _invalid();
    return OrderingContext(
      contextRef: contextRef,
      memberRef: resolvedMember,
      tableId: resolvedTable,
      storeRef: storeRef,
      tenantRef: field('tenantRef'),
      brandRef: field('brandRef'),
      cityId: field('cityId'),
      cityName: field('cityName'),
      storeName: field('storeName'),
      storeAddress: field('storeAddress'),
      tableName: field('tableName'),
      tableSessionRef: tableSessionRef,
      businessDate: businessDate,
      currency: field('currency'),
      timeZone: field('timeZone'),
      paymentTiming: paymentTiming,
    );
  }

  Never _invalid() =>
      throw const AuthFailure('ORDERING_CONTEXT_INVALID', '桌台信息不完整，请重试');
}
