import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import 'ordering_catalog_repository.dart';
import 'ordering_context.dart';
import 'ordering_table_repository.dart';

enum OrderingPaymentProvider { wechat, alipay }

class OrderingOrderLine {
  const OrderingOrderLine({required this.product, required this.quantity});

  final OrderingCatalogProduct product;
  final int quantity;
}

class OrderingOrderReceipt {
  const OrderingOrderReceipt({
    required this.orderRef,
    required this.storeRef,
    required this.tableId,
    required this.tableSessionRef,
    required this.status,
    required this.totalCents,
    required this.currency,
    required this.expiresAt,
    this.payment,
    this.paymentTiming = 'prepay',
    this.cancellationRequested = false,
    this.canCancel = false,
  });

  final String orderRef;
  final String storeRef;
  final String tableId;
  final String tableSessionRef;
  final String status;
  final int totalCents;
  final String currency;
  final DateTime? expiresAt;
  final String paymentTiming;
  final Map<String, String>? payment;
  final bool cancellationRequested;
  final bool canCancel;
}

typedef OrderingOrderSessionReader = OrderingSessionReader;
typedef OrderingOrderRequest = OrderingContextRequest;

/// Submits a server-priced order. The client never sends a total or payment state.
class OrderingOrderRepository {
  OrderingOrderRepository({required this.readSession, required this.request});

  factory OrderingOrderRepository.secure(String baseUrl) {
    final client = KingclubSecureClient(baseUrl);
    final sessions = SecureSessionStore();
    return OrderingOrderRepository(
      readSession: sessions.readSession,
      request: (id, params, session) =>
          client.call(id, params, session: session),
    );
  }
  final OrderingOrderSessionReader readSession;
  final OrderingOrderRequest request;
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _sessionReference = RegExp(
    r'^(?:H[0-9]{11}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$',
  );
  static final _ref = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  Future<OrderingOrderReceipt> submit({
    required OrderingContext context,
    required String requestId,
    required List<OrderingOrderLine> lines,
    OrderingPaymentProvider paymentProvider = OrderingPaymentProvider.wechat,
    bool initiatePayment = true,
  }) async {
    if (context.tableId == null ||
        !_ref.hasMatch(context.tableId!) ||
        !_sessionReference.hasMatch(context.tableSessionRef) ||
        !{'prepay', 'postpay'}.contains(context.paymentTiming) ||
        !_uuid.hasMatch(requestId) ||
        lines.isEmpty ||
        lines.length > 50) {
      throw const AuthFailure('ORDERING_REQUEST_INVALID', '订单信息无效');
    }
    final session = await readSession();
    final identity = _identity(session);
    if (identity == null) {
      throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    }
    final seen = <String>{};
    final items = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.quantity < 1 ||
          line.quantity > 1000 ||
          !seen.add(line.product.reference) ||
          !_ref.hasMatch(line.product.reference) ||
          !_ref.hasMatch(line.product.categoryRef)) {
        throw const AuthFailure('ORDERING_REQUEST_INVALID', '商品数量或编号无效');
      }
      items.add({
        'productRef': line.product.reference,
        'quantity': line.quantity,
        'expectedRevision': line.product.revision,
        'expectedPriceCents': line.product.priceCents,
      });
    }
    final response = await request('K260919000814', {
      'tableId': context.tableId,
      'tableSessionRef': context.tableSessionRef,
      'requestId': requestId,
      'items': items,
      'paymentProvider': paymentProvider.name,
      'initiatePayment': context.paymentTiming == 'prepay' && initiatePayment,
    }, session!);
    final current = await readSession();
    if (!_sameIdentity(_identity(current), identity)) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变更，请重试');
    }
    final receipt = _parse(response, context);
    if (receipt.payment != null &&
        (receipt.payment!['provider'] ?? 'wechat') != paymentProvider.name) {
      _invalid();
    }
    return receipt;
  }

  Future<OrderingOrderReceipt> cancel({
    required OrderingContext context,
    required String orderRef,
  }) async {
    if (!_ref.hasMatch(orderRef)) _invalid();
    final session = await readSession();
    final identity = _identity(session);
    if (identity == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    final response = await request('K261001001958', {
      'orderRef': orderRef,
    }, session!);
    if (!_sameIdentity(_identity(await readSession()), identity)) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变更，请重试');
    }
    final receipt = _parse(response, context);
    if (receipt.orderRef != orderRef) _invalid();
    return receipt;
  }

  Future<OrderingOrderReceipt> owned({
    required OrderingContext context,
    required String orderRef,
  }) async {
    if (!_ref.hasMatch(orderRef)) _invalid();
    final session = await readSession();
    final identity = _identity(session);
    if (identity == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    final response = await request('K260919000815', {
      'orderRef': orderRef,
    }, session!);
    if (!_sameIdentity(_identity(await readSession()), identity)) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变更，请重试');
    }
    final receipt = _parse(response, context);
    if (receipt.orderRef != orderRef) _invalid();
    return receipt;
  }

  Future<OrderingOrderReceipt?> findByRequest({
    required OrderingContext context,
    required String requestId,
  }) async {
    if (!_uuid.hasMatch(requestId)) _invalid();
    final session = await readSession();
    final identity = _identity(session);
    if (identity == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    final response = await request('K260919000815', {
      'requestId': requestId,
    }, session!);
    if (!_sameIdentity(_identity(await readSession()), identity)) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变更，请重试');
    }
    final result = response['result'];
    if (result is Map && result['notFound'] == true) return null;
    return _parse(response, context);
  }

  OrderingOrderReceipt _parse(
    Map<String, dynamic> response,
    OrderingContext context,
  ) {
    final result = response['result'];
    if (result is! Map) _invalid();
    String text(String key) {
      final value = result[key];
      if (value is! String || value.trim().isEmpty) _invalid();
      return value;
    }

    final orderRef = text('orderRef');
    final storeRef = text('storeRef');
    final tableId = text('tableId');
    final tableSessionRef = text('tableSessionRef');
    final status = text('status');
    final currency = text('currency');
    final totalCents = result['totalCents'];
    if (result['canCancel'] != null && result['canCancel'] is! bool) {
      _invalid();
    }
    final timing = result['paymentTiming'] ?? 'prepay';
    final rawExpiry = result['expiresAt'];
    final expiresAt = rawExpiry is String ? DateTime.tryParse(rawExpiry) : null;
    if (timing != context.paymentTiming ||
        (timing == 'prepay'
            ? expiresAt == null
            : timing != 'postpay' || rawExpiry != null) ||
        (timing == 'postpay' &&
            (result['payment'] != null ||
                !{'pending', 'paid', 'expired'}.contains(status)))) {
      _invalid();
    }
    if (!RegExp(
          r'^(?:D[0-9]{11}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$',
        ).hasMatch(orderRef) ||
        storeRef != context.storeRef ||
        tableId != context.tableId ||
        tableSessionRef != context.tableSessionRef ||
        !{
          'awaitingPayment',
          'paid',
          'paymentPending',
          'pending',
          'expired',
        }.contains(status) ||
        currency != context.currency ||
        totalCents is! int ||
        totalCents < 0 ||
        (result['cancellationRequested'] != null &&
            result['cancellationRequested'] is! bool)) {
      _invalid();
    }
    Map<String, String>? payment;
    if (result['payment'] != null) {
      final raw = result['payment'];
      if (raw is! Map) _invalid();
      final provider = raw['provider'] ?? 'wechat';
      if (provider == 'alipay') {
        final orderString = raw['orderString'];
        if (orderString is! String ||
            orderString.trim().isEmpty ||
            orderString.length > 65536 ||
            orderString.contains(RegExp(r'[\x00-\x1f]'))) {
          _invalid();
        }
        payment = {'provider': 'alipay', 'orderString': orderString};
      } else if (provider == 'wechat') {
        const keys = [
          'appId',
          'partnerId',
          'prepayId',
          'packageValue',
          'nonceStr',
          'timeStamp',
          'sign',
        ];
        if (keys.any(
          (key) => raw[key] is! String || (raw[key] as String).isEmpty,
        )) {
          _invalid();
        }
        payment = {for (final key in keys) key: raw[key] as String};
        if (payment['packageValue'] != 'Sign=WXPay' ||
            !RegExp(r'^wx[a-zA-Z0-9]+$').hasMatch(payment['appId']!) ||
            int.tryParse(payment['timeStamp']!) == null) {
          _invalid();
        }
      } else {
        _invalid();
      }
    }
    return OrderingOrderReceipt(
      orderRef: orderRef,
      storeRef: storeRef,
      tableId: tableId,
      tableSessionRef: tableSessionRef,
      status: status,
      totalCents: totalCents,
      currency: currency,
      expiresAt: expiresAt,
      paymentTiming: timing as String,
      payment: payment,
      cancellationRequested: result['cancellationRequested'] == true,
      canCancel: result['canCancel'] == true,
    );
  }

  static List<String>? _identity(Map<String, dynamic>? session) {
    final account = session?['account'];
    final values = [
      session?['sessionId'],
      session?['apiKeyId'],
      session?['apiKey'],
      account is Map ? account['userAccount'] : null,
    ];
    if (values.any((value) => value is! String || value.isEmpty)) return null;
    return values.cast<String>();
  }

  static bool _sameIdentity(List<String>? left, List<String>? right) {
    if (left == null || right == null || left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  Never _invalid() =>
      throw const AuthFailure('ORDERING_RESPONSE_INVALID', '订单返回异常，请刷新');
}
