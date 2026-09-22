import '../../auth/domain/auth_repository.dart';
import 'ordering_catalog_repository.dart';
import 'ordering_context.dart';
import 'ordering_table_repository.dart';

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
  });

  final String orderRef;
  final String storeRef;
  final String tableId;
  final String tableSessionRef;
  final String status;
  final int totalCents;
  final String currency;
  final DateTime expiresAt;
}

typedef OrderingOrderSessionReader = OrderingSessionReader;
typedef OrderingOrderRequest = OrderingContextRequest;

/// Submits a server-priced order. The client never sends a total or payment state.
class OrderingOrderRepository {
  OrderingOrderRepository({required this.readSession, required this.request});

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
  }) async {
    if (context.tableId == null ||
        !_ref.hasMatch(context.tableId!) ||
        !_sessionReference.hasMatch(context.tableSessionRef) ||
        context.paymentTiming != 'prepay' ||
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
    }, session!);
    final current = await readSession();
    if (!_sameIdentity(_identity(current), identity)) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变更，请重试');
    }
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
    final expiresAt = DateTime.tryParse(text('expiresAt'));
    if (!RegExp(
          r'^(?:D[0-9]{11}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$',
        ).hasMatch(orderRef) ||
        storeRef != context.storeRef ||
        tableId != context.tableId ||
        tableSessionRef != context.tableSessionRef ||
        !{'awaitingPayment', 'paid', 'paymentPending'}.contains(status) ||
        currency != context.currency ||
        totalCents is! int ||
        totalCents < 0 ||
        expiresAt == null) {
      _invalid();
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
