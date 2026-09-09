import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fakeCommerceRepositoryProvider = Provider<FakeCommerceRepository>((ref) {
  final repository = FakeCommerceRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

enum CommerceOrderStatus {
  awaitingPayment,
  paymentPending,
  confirmed,
  cancelled,
}

@immutable
class CommerceLine {
  const CommerceLine({
    required this.name,
    required this.detail,
    required this.asset,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final String detail;
  final String asset;
  final int quantity;
  final int unitPrice;
  int get subtotal => quantity * unitPrice;
}

@immutable
class CommerceOrder {
  CommerceOrder({
    required this.id,
    required this.paymentIntentId,
    required this.title,
    required this.table,
    required this.createdAt,
    required List<CommerceLine> items,
    required this.discount,
    this.priceAdjustment = 0,
    this.type = '扫码点单',
    this.status = CommerceOrderStatus.awaitingPayment,
    this.listed = true,
  }) : items = List.unmodifiable(items);

  final String id;
  final String paymentIntentId;
  final String title;
  final String table;
  final String type;
  final DateTime createdAt;
  final List<CommerceLine> items;
  final int discount;
  final int priceAdjustment;
  final CommerceOrderStatus status;
  final bool listed;
  int get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  int get amountDue => subtotal - discount + priceAdjustment;
  String get summary => '$table · ${items.map((item) => item.name).join('、')}';

  CommerceOrder withStatus(CommerceOrderStatus value) => CommerceOrder(
    id: id,
    paymentIntentId: paymentIntentId,
    title: title,
    table: table,
    createdAt: createdAt,
    items: items,
    discount: discount,
    priceAdjustment: priceAdjustment,
    type: type,
    status: value,
  );
}

/// Offline fixtures only. A real adapter must reprice from product/quote IDs;
/// it must never trust these client-side prices or states for actual payment.
class FakeCommerceRepository extends ChangeNotifier {
  FakeCommerceRepository({bool seed = true}) {
    if (seed) _seed();
  }

  final _orders = <String, CommerceOrder>{};
  final _intentOrders = <String, String>{};
  final _requests = <String, String>{};
  int _sequence = 0;
  int _generation = 0;

  int get generation => _generation;
  List<CommerceOrder> get orders => List.unmodifiable(
    _orders.values.where((order) => order.listed).toList().reversed,
  );
  CommerceOrder? order(String id) => _orders[id];
  CommerceOrder? payment(String intentId) => _orders[_intentOrders[intentId]];

  String newRequestKey() => 'request-$_generation-${++_sequence}';

  static int discountFor(List<CommerceLine> items) =>
      items.fold(0, (sum, item) => sum + item.subtotal) >= 500 ? 30 : 0;

  CommerceOrder createScanOrder({
    required String requestKey,
    required int expectedGeneration,
    required List<CommerceLine> items,
    int priceAdjustment = 0,
  }) {
    if (expectedGeneration != _generation) {
      throw StateError('Mock session changed');
    }
    final existing = _orders[_requests[requestKey]];
    if (existing != null) return existing;
    if (items.isEmpty ||
        items.any((item) => item.quantity <= 0 || item.unitPrice < 0) ||
        (priceAdjustment != 0 && priceAdjustment != 20)) {
      throw ArgumentError('Invalid Fake quote');
    }
    final id = 'order-scan-$_generation-${++_sequence}';
    final result = CommerceOrder(
      id: id,
      paymentIntentId: 'payment-intent-$id',
      title: 'KINGBAR 湖南工大店',
      table: '888号桌',
      createdAt: DateTime.now(),
      items: items,
      discount: discountFor(items),
      priceAdjustment: priceAdjustment,
    );
    _put(result);
    _requests[requestKey] = id;
    notifyListeners();
    return result;
  }

  bool confirmPayment(String intentId, {required int expectedGeneration}) {
    if (expectedGeneration != _generation) return false;
    final current = payment(intentId);
    if (current == null || current.status == CommerceOrderStatus.cancelled) {
      return false;
    }
    if (current.status == CommerceOrderStatus.confirmed) return true;
    _put(current.withStatus(CommerceOrderStatus.confirmed));
    notifyListeners();
    return true;
  }

  CommerceOrder createAaOrder({
    required String requestKey,
    required int expectedGeneration,
    required String packageName,
    required String asset,
    required String serviceDate,
    required int priceMinor,
    required int deductionMinor,
  }) {
    if (expectedGeneration != _generation) {
      throw StateError('Mock session changed');
    }
    final existing = _orders[_requests[requestKey]];
    if (existing != null) return existing;
    if (priceMinor < 0 ||
        deductionMinor < 0 ||
        deductionMinor > priceMinor ||
        priceMinor % 100 != 0 ||
        deductionMinor % 100 != 0) {
      throw ArgumentError('Unsupported Fake AA money');
    }
    final id = 'order-aa-$_generation-${++_sequence}';
    final date = serviceDate.split('.');
    final displayDate = date.length == 2
        ? '${date[0]}月${date[1]}日'
        : serviceDate;
    final result = CommerceOrder(
      id: id,
      paymentIntentId: 'payment-intent-$id',
      type: '一起玩AA',
      title: 'KING CLUB AA预订',
      table: '卡座待揭晓 · $displayDate 20:30',
      createdAt: DateTime.now(),
      items: [
        CommerceLine(
          name: packageName,
          detail: 'AA 预订 · 本人 1 席',
          asset: asset,
          quantity: 1,
          unitPrice: priceMinor ~/ 100,
        ),
      ],
      discount: deductionMinor ~/ 100,
    );
    _put(result);
    _requests[requestKey] = id;
    notifyListeners();
    return result;
  }

  bool cancelOrder(String id, {required int expectedGeneration}) {
    if (expectedGeneration != _generation) return false;
    final current = order(id);
    if (current == null ||
        current.status == CommerceOrderStatus.confirmed ||
        current.status == CommerceOrderStatus.paymentPending) {
      return false;
    }
    if (current.status == CommerceOrderStatus.cancelled) return true;
    _put(current.withStatus(CommerceOrderStatus.cancelled));
    notifyListeners();
    return true;
  }

  bool markPaymentPending(String intentId, {required int expectedGeneration}) {
    if (expectedGeneration != _generation) return false;
    final current = payment(intentId);
    if (current == null ||
        current.status == CommerceOrderStatus.cancelled ||
        current.status == CommerceOrderStatus.confirmed) {
      return false;
    }
    _put(current.withStatus(CommerceOrderStatus.paymentPending));
    notifyListeners();
    return true;
  }

  void clear() {
    _generation++;
    _orders.clear();
    _intentOrders.clear();
    _requests.clear();
    notifyListeners();
  }

  bool beginPayment(String intentId, {required int expectedGeneration}) {
    if (payment(intentId)?.status != CommerceOrderStatus.awaitingPayment) {
      return false;
    }
    return markPaymentPending(intentId, expectedGeneration: expectedGeneration);
  }

  void releasePayment(String intentId, {required int expectedGeneration}) {
    if (expectedGeneration != _generation) return;
    final current = payment(intentId);
    if (current == null ||
        current.status != CommerceOrderStatus.paymentPending) {
      return;
    }
    _put(current.withStatus(CommerceOrderStatus.awaitingPayment));
    notifyListeners();
  }

  void _put(CommerceOrder value) {
    _orders[value.id] = value;
    _intentOrders[value.paymentIntentId] = value.id;
  }

  void _seed() {
    _put(
      CommerceOrder(
        id: 'order-scan-v8-0827',
        paymentIntentId: 'payment-intent-order-scan-v8-0827',
        title: 'KINGBAR V8 桌点单',
        table: 'V8 卡座',
        createdAt: DateTime(2026, 8, 27, 20, 18),
        items: const [
          CommerceLine(
            name: '星光香槟',
            detail: '750ml · 冰桶与香槟杯',
            asset: 'assets/legacy/ordering/product_champagne_v1.png',
            quantity: 1,
            unitPrice: 688,
          ),
          CommerceLine(
            name: '金标威士忌',
            detail: '700ml · 经典调饮套装',
            asset: 'assets/legacy/ordering/product_whisky_v1.png',
            quantity: 1,
            unitPrice: 498,
          ),
        ],
        discount: 30,
      ),
    );
    // Explicit legacy AA scenario references, never a catch-all for unknown IDs.
    for (var mask = 0; mask < 8; mask++) {
      _put(
        CommerceOrder(
          id: 'order-aa-v5-pending-r$mask-0829',
          paymentIntentId: 'payment-intent-aa-v5-r$mask',
          type: '一起玩AA',
          title: 'KING CLUB AA预订',
          table: '卡座待揭晓 · 08月29日 20:30',
          createdAt: DateTime(2026, 8, 29, 21, 54),
          items: const [
            CommerceLine(
              name: '3880卡座套餐',
              detail: 'AA 预订 · 本人 1 席',
              asset: 'assets/legacy/aa/package_3880_v1.png',
              quantity: 1,
              unitPrice: 268,
            ),
          ],
          discount:
              (mask & 1 != 0 ? 20 : 0) +
              (mask & 2 != 0 ? 8 : 0) +
              (mask & 4 != 0 ? 20 : 0),
          listed: false,
        ),
      );
    }
  }
}
