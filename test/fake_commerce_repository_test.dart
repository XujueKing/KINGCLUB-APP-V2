import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/fake_commerce_repository.dart';

const fruit = CommerceLine(
  name: '鲜果盘',
  detail: '大份',
  asset: 'assets/legacy/ordering/product_fruit_platter_v1.png',
  quantity: 1,
  unitPrice: 88,
);

void main() {
  late FakeCommerceRepository repository;
  setUp(() => repository = FakeCommerceRepository(seed: false));
  tearDown(() => repository.dispose());

  test(
    'AA creation uses selected package/date and refuses fractional truncation',
    () {
      final order = repository.createAaOrder(
        requestKey: repository.newRequestKey(),
        expectedGeneration: 0,
        packageName: '经典派对套餐',
        asset: 'fixture',
        serviceDate: '08.26',
        priceMinor: 28800,
        deductionMinor: 2000,
      );
      expect(order.amountDue, 268);
      expect(order.items.single.name, '经典派对套餐');
      expect(order.table, contains('08月26日'));
      expect(
        () => repository.createAaOrder(
          requestKey: repository.newRequestKey(),
          expectedGeneration: 0,
          packageName: '非整元样例',
          asset: 'fixture',
          serviceDate: '08.26',
          priceMinor: 28801,
          deductionMinor: 0,
        ),
        throwsArgumentError,
      );
    },
  );

  CommerceOrder create({
    String? key,
    List<CommerceLine> items = const [fruit],
    int adjustment = 0,
  }) => repository.createScanOrder(
    requestKey: key ?? repository.newRequestKey(),
    expectedGeneration: repository.generation,
    items: items,
    priceAdjustment: adjustment,
  );

  test('same request is idempotent, different requests retain independent snapshots', () {
    final key = repository.newRequestKey();
    final mutableItems = <CommerceLine>[fruit];
    final first = create(key: key, items: mutableItems);
    mutableItems.clear();
    final retried = create(key: key, adjustment: 20);
    final second = create(adjustment: 20);
    expect(retried, same(first));
    expect(first.items, hasLength(1));
    expect(() => first.items.clear(), throwsUnsupportedError);
    expect(first.amountDue, 88);
    expect(second.amountDue, 108);
    expect(first.id, isNot(second.id));
    expect(repository.payment(first.paymentIntentId), same(first));
    expect(repository.orders, hasLength(2));
  });

  test('discount and accepted quote adjustment reconcile line totals', () {
    final order = create(
      items: const [
        CommerceLine(
          name: '套餐',
          detail: '2份',
          asset: 'fixture',
          quantity: 2,
          unitPrice: 300,
        ),
      ],
      adjustment: 20,
    );
    expect(order.subtotal, 600);
    expect(order.discount, 30);
    expect(order.amountDue, 590);
  });

  test('invalid quotes and arbitrary references fail closed', () {
    expect(() => create(items: []), throwsArgumentError);
    expect(() => create(adjustment: -999), throwsArgumentError);
    expect(
      () => create(
        items: const [
          CommerceLine(
            name: 'invalid',
            detail: '',
            asset: '',
            quantity: -1,
            unitPrice: 88,
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(repository.order('unknown'), isNull);
    expect(repository.payment('unknown'), isNull);
    expect(
      repository.confirmPayment('unknown', expectedGeneration: 0),
      isFalse,
    );
  });

  test('confirmed order keeps identity and cannot be cancelled', () {
    final order = create();
    expect(
      repository.confirmPayment(order.paymentIntentId, expectedGeneration: 0),
      isTrue,
    );
    expect(
      repository.confirmPayment(order.paymentIntentId, expectedGeneration: 0),
      isTrue,
    );
    expect(repository.cancelOrder(order.id, expectedGeneration: 0), isFalse);
    expect(repository.payment(order.paymentIntentId)?.id, order.id);
    expect(repository.order(order.id)?.amountDue, 88);
    expect(repository.order(order.id)?.status, CommerceOrderStatus.confirmed);
  });

  test('cancelled business order cannot be paid', () {
    final order = create();
    expect(repository.cancelOrder(order.id, expectedGeneration: 0), isTrue);
    expect(
      repository.confirmPayment(order.paymentIntentId, expectedGeneration: 0),
      isFalse,
    );
    expect(repository.order(order.id)?.status, CommerceOrderStatus.cancelled);
  });

  test('pending payment blocks duplicate attempts and cancellation; failure releases it', () {
    final order = create();
    expect(
      repository.beginPayment(order.paymentIntentId, expectedGeneration: 0),
      isTrue,
    );
    expect(
      repository.beginPayment(order.paymentIntentId, expectedGeneration: 0),
      isFalse,
    );
    expect(repository.cancelOrder(order.id, expectedGeneration: 0), isFalse);
    repository.releasePayment(order.paymentIntentId, expectedGeneration: 0);
    expect(
      repository.order(order.id)?.status,
      CommerceOrderStatus.awaitingPayment,
    );
    expect(
      repository.beginPayment(order.paymentIntentId, expectedGeneration: 0),
      isTrue,
    );
  });

  test(
    'clear invalidates old requests and results without reviving another order',
    () {
      final old = create(key: 'old-request');
      repository.clear();
      final current = create();
      expect(current.id, isNot(old.id));
      expect(
        repository.confirmPayment(old.paymentIntentId, expectedGeneration: 0),
        isFalse,
      );
      expect(
        () => repository.createScanOrder(
          requestKey: 'old-request',
          expectedGeneration: 0,
          items: [fruit],
        ),
        throwsStateError,
      );
      expect(repository.order(old.id), isNull);
      expect(repository.orders.single.id, current.id);
    },
  );

  test(
    'AA fixtures are explicit and retain the same order after confirmation',
    () {
      final seeded = FakeCommerceRepository();
      addTearDown(seeded.dispose);
      for (var mask = 0; mask < 8; mask++) {
        final order = seeded.payment('payment-intent-aa-v5-r$mask')!;
        final discount =
            (mask & 1 != 0 ? 20 : 0) +
            (mask & 2 != 0 ? 8 : 0) +
            (mask & 4 != 0 ? 20 : 0);
        expect(order.amountDue, 268 - discount);
        seeded.confirmPayment(order.paymentIntentId, expectedGeneration: 0);
        expect(seeded.payment(order.paymentIntentId)?.id, order.id);
      }
      expect(seeded.payment('payment-intent-aa-v5-r8'), isNull);
      expect(seeded.payment('payment-intent-nonexistent'), isNull);
    },
  );
}
