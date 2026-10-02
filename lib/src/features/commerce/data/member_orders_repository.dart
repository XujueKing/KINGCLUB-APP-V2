import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import 'ordering_table_repository.dart';

Never _invalid() =>
    throw const AuthFailure('MEMBER_ORDERS_INVALID', '订单数据暂不可用');
final _ref = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _orderRef = RegExp(
  r'^(?:D[0-9]{11}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$',
);
Map _map(dynamic value) => value is Map ? value : _invalid();
String _text(dynamic value, {RegExp? pattern}) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > 128 ||
      (pattern != null && !pattern.hasMatch(value))) {
    _invalid();
  }
  return value;
}

int _integer(dynamic value, int maximum, [int minimum = 0]) {
  if (value is! int || value < minimum || value > maximum) _invalid();
  return value;
}

DateTime _date(dynamic value) {
  if (value is! String || !value.endsWith('Z')) _invalid();
  return DateTime.tryParse(value) ?? _invalid();
}

String _enum(dynamic value, Set<String> allowed) {
  if (value is! String || !allowed.contains(value)) _invalid();
  return value;
}

Map<String, String> _localized(dynamic value) {
  final source = _map(value);
  return Map.unmodifiable({
    for (final key in ['zh-CN', 'zh-TW', 'en', 'th']) key: _text(source[key]),
  });
}

class MemberOrderItem {
  MemberOrderItem._(
    this.productRef,
    this.quantity,
    this.priceCents,
    this.servedQuantity,
    this.refundedQuantity,
    this.names,
    this.specifications,
  );
  final String productRef;
  final int quantity, priceCents, servedQuantity;
  final Map<String, String> names, specifications;
  final int? refundedQuantity;
  int get activeQuantity => quantity - (refundedQuantity ?? 0);
  int get remainingQuantity => activeQuantity - servedQuantity;
  factory MemberOrderItem.parse(dynamic raw) {
    final value = _map(raw), snapshot = _map(value['snapshot']);
    final quantity = _integer(value['quantity'], 1000, 1);
    final refunded = value['refundedQuantity'] == null
        ? null
        : _integer(value['refundedQuantity'], quantity);
    _integer(snapshot['revision'], 4294967295, 1);
    return MemberOrderItem._(
      _text(value['productRef'], pattern: _ref),
      quantity,
      _integer(value['priceCents'], 100000000, 1),
      _integer(value['servedQuantity'], quantity - (refunded ?? 0)),
      refunded,
      _localized(snapshot['names']),
      _localized(snapshot['specifications']),
    );
  }
}

/// Server display state. This object never grants debit, cancellation, or refund.
class MemberOrder {
  MemberOrder._({
    required this.orderRef,
    required this.storeRef,
    required this.storeName,
    required this.tableRef,
    required this.tableName,
    required this.sessionRef,
    required this.sessionStatus,
    required this.source,
    required this.paymentTiming,
    required this.status,
    required this.currency,
    required this.totalCents,
    required this.refundedCents,
    required this.createdAt,
    required this.expiresAt,
    required this.refundedAt,
    required this.items,
  });
  final String orderRef,
      storeRef,
      storeName,
      tableRef,
      tableName,
      sessionRef,
      sessionStatus;
  final String source, paymentTiming, status, currency;
  final int totalCents, refundedCents;
  final DateTime createdAt;
  final DateTime? expiresAt, refundedAt;
  final List<MemberOrderItem> items;
  bool get fullyRefunded => refundedCents == totalCents;
  int get netPaidCents => status == 'paid' ? totalCents - refundedCents : 0;
  factory MemberOrder.parse(dynamic raw) {
    final value = _map(raw);
    final source = _enum(value['source'], {'cashier', 'app'});
    final timing = _enum(value['paymentTiming'], {'prepay', 'postpay'});
    final status = _enum(value['status'], {'pending', 'paid', 'expired'});
    final total = _integer(value['totalCents'], 100000000, 1);
    final refunded = _integer(value['refundedCents'], total);
    final refundedAt = value['refundedAt'] == null
        ? null
        : _date(value['refundedAt']);
    final expires = value['expiresAt'] == null
        ? null
        : _date(value['expiresAt']);
    if ((refunded == 0) != (refundedAt == null) ||
        (refunded > 0 && (source != 'cashier' || status != 'paid')) ||
        (status == 'pending' && timing == 'prepay' && expires == null)) {
      _invalid();
    }
    final lines = value['items'];
    if (lines is! List || lines.isEmpty || lines.length > 50) _invalid();
    final items = List<MemberOrderItem>.unmodifiable(
      lines.map(MemberOrderItem.parse),
    );
    if (items.map((item) => item.productRef).toSet().length != items.length ||
        items.fold<int>(
              0,
              (sum, item) => sum + item.priceCents * item.quantity,
            ) !=
            total) {
      _invalid();
    }
    final hasQuantities = items.any((item) => item.refundedQuantity != null);
    if ((refunded > 0 && refunded < total && !hasQuantities) ||
        (hasQuantities &&
            (items.any((item) => item.refundedQuantity == null) ||
                items.fold<int>(
                      0,
                      (sum, item) =>
                          sum + item.priceCents * item.refundedQuantity!,
                    ) !=
                    refunded))) {
      _invalid();
    }
    return MemberOrder._(
      orderRef: _text(value['orderRef'], pattern: _orderRef),
      storeRef: _text(value['storeRef'], pattern: _ref),
      storeName: _text(value['storeName']),
      tableRef: _text(value['tableRef'], pattern: _ref),
      tableName: _text(value['tableName']),
      sessionRef: _text(value['sessionRef'], pattern: _ref),
      sessionStatus: _enum(value['sessionStatus'], {
        'open',
        'clearing',
        'closed',
      }),
      source: source,
      paymentTiming: timing,
      status: status,
      currency: _enum(value['currency'], {'CNY'}),
      totalCents: total,
      refundedCents: refunded,
      createdAt: _date(value['createdAt']),
      expiresAt: expires,
      refundedAt: refundedAt,
      items: items,
    );
  }
}

class MemberOrdersSnapshot {
  MemberOrdersSnapshot._(this.observedAt, this.orders, this.nextBeforeOrder);
  final DateTime observedAt;
  final List<MemberOrder> orders;
  final String? nextBeforeOrder;
  factory MemberOrdersSnapshot.parse(dynamic raw) {
    final value = _map(raw), rows = value['orders'];
    if (rows is! List || rows.length > 20) _invalid();
    final orders = List<MemberOrder>.unmodifiable(rows.map(MemberOrder.parse));
    if (orders.map((order) => order.orderRef).toSet().length != orders.length) {
      _invalid();
    }
    final next = value['nextBeforeOrder'] == null
        ? null
        : _text(value['nextBeforeOrder'], pattern: _orderRef);
    if (next != null && (orders.length != 20 || orders.last.orderRef != next)) {
      _invalid();
    }
    return MemberOrdersSnapshot._(_date(value['observedAt']), orders, next);
  }
}

class MemberOrdersRepository {
  MemberOrdersRepository({required this.readSession, required this.request});
  factory MemberOrdersRepository.secure(String baseUrl) {
    final client = KingclubSecureClient(baseUrl),
        sessions = SecureSessionStore();
    return MemberOrdersRepository(
      readSession: sessions.readSession,
      request: (id, params, session) =>
          client.call(id, params, session: session),
    );
  }
  final OrderingSessionReader readSession;
  final OrderingContextRequest request;
  List<String>? _identity(Map<String, dynamic>? session) {
    final account = session?['account'];
    final member = account is Map ? account['userAccount'] : null;
    final values = [
      member,
      session?['sessionId'],
      session?['apiKeyId'],
      session?['apiKey'],
    ];
    if (values.any((v) => v is! String || v.isEmpty)) return null;
    return values.cast<String>();
  }

  Future<MemberOrdersSnapshot> read({String? orderRef, String? beforeOrder}) =>
      _read(orderRef: orderRef, beforeOrder: beforeOrder);

  /// Current seated table display only; does not authorize paying others' orders.
  Future<MemberOrdersSnapshot> readTable({
    required String storeRef,
    required String tableRef,
    required String sessionRef,
    String? beforeOrder,
  }) => _read(
    storeRef: storeRef,
    tableRef: tableRef,
    sessionRef: sessionRef,
    beforeOrder: beforeOrder,
  );

  Future<MemberOrdersSnapshot> _read({
    String? orderRef,
    String? beforeOrder,
    String? storeRef,
    String? tableRef,
    String? sessionRef,
  }) async {
    if (tableRef != null &&
        [
          storeRef,
          tableRef,
          sessionRef,
        ].any((value) => value == null || !_ref.hasMatch(value))) {
      _invalid();
    }
    if ((orderRef != null && !_orderRef.hasMatch(orderRef)) ||
        (beforeOrder != null && !_orderRef.hasMatch(beforeOrder)) ||
        (orderRef != null && beforeOrder != null)) {
      _invalid();
    }
    final session = await readSession(), identity = _identity(session);
    if (identity == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    final response = await request('K261001001955', {
      'orderRef': ?orderRef,
      'beforeOrder': ?beforeOrder,
      'tableRef': ?tableRef,
      'sessionRef': ?sessionRef,
    }, session!);
    final current = _identity(await readSession());
    if (current == null ||
        List.generate(
          identity.length,
          (i) => identity[i] == current[i],
        ).contains(false)) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变更');
    }
    final result = MemberOrdersSnapshot.parse(response['result']);
    if (tableRef != null) {
      final scope = _map(_map(response['result'])['tableScope']);
      if (scope['storeRef'] != storeRef ||
          scope['tableRef'] != tableRef ||
          scope['sessionRef'] != sessionRef ||
          result.orders.any(
            (order) =>
                order.storeRef != storeRef ||
                order.tableRef != tableRef ||
                order.sessionRef != sessionRef,
          )) {
        _invalid();
      }
    } else if (_map(response['result']).containsKey('tableScope')) {
      _invalid();
    }
    if (orderRef != null &&
        (result.orders.length != 1 ||
            result.orders.single.orderRef != orderRef ||
            result.nextBeforeOrder != null)) {
      _invalid();
    }
    if (beforeOrder != null &&
        result.orders.any((order) => order.orderRef == beforeOrder)) {
      _invalid();
    }
    return result;
  }
}
