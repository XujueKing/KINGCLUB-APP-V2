import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/aa_order_confirmation_page.dart';
import 'package:kingclub/src/features/commerce/data/fake_commerce_repository.dart';
import 'package:kingclub/src/features/commerce/presentation/order_center_page.dart';
import 'package:kingclub/src/features/commerce/presentation/order_detail_page.dart';
import 'package:kingclub/src/features/commerce/presentation/payment_result_page.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/settings_page.dart';
import 'package:kingclub/src/navigation/app_router.dart';

void main() {
  Future<ProviderContainer> routed(
    WidgetTester tester,
    String path, {
    Object? extra,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    router.go(path, extra: extra);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: KingTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  FakeOrderingQuote quote(int price, int count) => FakeOrderingQuote(
    // These redundant cart totals must not override the Fake line snapshot.
    itemCount: count,
    total: 999999,
    items: [
      FakeOrderingQuoteItem(
        name: '回归鲜果盘',
        detail: '大份',
        asset: 'assets/legacy/ordering/product_fruit_platter_v1.png',
        quantity: count,
        unitPrice: price,
      ),
    ],
  );

  Future<void> finishPayment(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'AA nested payment shares application orders after a session clear',
    (tester) async {
      final container = await routed(tester, '/club/aa');
      final repository = container.read(fakeCommerceRepositoryProvider);
      repository.clear();
      await tester.tap(find.text('加入').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('抢订'));
      await tester.pumpAndSettle();
      expect(find.byType(AaOrderConfirmationPage), findsOneWidget);
      final terms = find.byKey(const ValueKey('aa-terms-checkbox'));
      await tester.ensureVisible(terms);
      tester.widget<Checkbox>(terms).onChanged!(true);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('aa-pay-button')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final order = repository.orders.single;
      expect(order.type, '一起玩AA');
      expect(find.text('¥268.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('payment-confirm')));
      await finishPayment(tester);
      await tester.tap(find.byKey(const ValueKey('payment-view-order')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OrderDetailPage>(find.byType(OrderDetailPage))
            .orderRef
            .opaqueId,
        order.id,
      );
      expect(repository.order(order.id)?.status, CommerceOrderStatus.confirmed);
      expect(find.byKey(const ValueKey('order-pay')), findsNothing);
    },
  );

  for (final scenario in ['providerFailed', 'providerCancelled']) {
    testWidgets('late $scenario cannot overwrite confirmed order', (
      tester,
    ) async {
      const intent = 'payment-intent-order-scan-v8-0827';
      final container = await routed(
        tester,
        '/commerce/payment',
        extra: const FakePaymentIntentRef(intent),
      );
      final repository = container.read(fakeCommerceRepositoryProvider);
      await tester.longPress(find.byKey(const ValueKey('legacy-club-title')));
      await tester.pumpAndSettle();
      final scenarioTile = find.byKey(ValueKey('payment-scenario-$scenario'));
      await tester.ensureVisible(scenarioTile);
      await tester.tap(scenarioTile);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payment-confirm')));
      await tester.pump();
      repository.confirmPayment(
        intent,
        expectedGeneration: repository.generation,
      );
      await finishPayment(tester);
      expect(find.text('支付已确认'), findsOneWidget);
      expect(repository.payment(intent)?.status, CommerceOrderStatus.confirmed);
      expect(find.byKey(const ValueKey('payment-safe-retry')), findsNothing);
    });
  }

  for (final sample in [
    (88, 1, false, 88),
    (300, 2, false, 570),
    (88, 1, true, 108),
  ]) {
    testWidgets(
      'same order through confirmation/payment/detail/list: ${sample.$4}',
      (tester) async {
        final container = await routed(
          tester,
          '/commerce/ordering/confirm',
          extra: quote(sample.$1, sample.$2),
        );
        final repository = container.read(fakeCommerceRepositoryProvider);
        if (sample.$3) {
          await tester.longPress(
            find.byKey(const ValueKey('legacy-club-title')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('价格变化'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('accept-quote-change')),
          );
          await tester.tap(find.byKey(const ValueKey('accept-quote-change')));
          await tester.pump();
        }
        await tester.tap(find.byKey(const ValueKey('order-submit')));
        await tester.tap(
          find.byKey(const ValueKey('order-submit')),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();
        final order = repository.orders.first;
        expect(
          repository.orders.where(
            (value) => value.id.startsWith('order-scan-0-'),
          ),
          hasLength(1),
        );
        expect(order.amountDue, sample.$4);
        expect(find.text('¥${sample.$4}.00'), findsOneWidget);
        expect(find.textContaining('回归鲜果盘'), findsOneWidget);
        expect(find.textContaining('轩尼诗XO'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('payment-confirm')));
        await finishPayment(tester);
        expect(
          repository.order(order.id)?.status,
          CommerceOrderStatus.confirmed,
        );
        await tester.tap(find.byKey(const ValueKey('payment-view-order')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OrderDetailPage>(find.byType(OrderDetailPage))
              .orderRef
              .opaqueId,
          order.id,
        );
        expect(find.text('回归鲜果盘'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('order-detail-status')),
            matching: find.text('已支付'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('order-pay')), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('order-detail-amounts')),
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('order-detail-amounts')),
            matching: find.text('¥${sample.$4}'),
          ),
          findsWidgets,
        );
        container.read(appRouterProvider).go('/commerce/orders');
        await tester.pumpAndSettle();
        final card = find.byKey(ValueKey('order-card-${order.id}'));
        expect(card, findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.text('¥${sample.$4}')),
          findsOneWidget,
        );
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OrderDetailPage>(find.byType(OrderDetailPage))
              .orderRef
              .opaqueId,
          order.id,
        );
        container
            .read(appRouterProvider)
            .go(
              '/commerce/payment',
              extra: FakePaymentIntentRef(order.paymentIntentId),
            );
        await tester.pumpAndSettle();
        expect(find.text('支付已确认'), findsOneWidget);
        expect(find.byKey(const ValueKey('payment-confirm')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final extra in [null, const FakePaymentIntentRef('does-not-exist')]) {
    testWidgets('missing/invalid payment context fails closed: $extra', (
      tester,
    ) async {
      await routed(tester, '/commerce/payment', extra: extra);
      expect(find.text('无法继续支付'), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-confirm')), findsNothing);
      expect(find.text('¥3680.00'), findsNothing);
      await tester.tap(find.text('返回订单中心'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderCenterPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final extra in [null, const FakeOrderRef('forged-scan-888-paid')]) {
    testWidgets('missing/forged order context fails closed: $extra', (
      tester,
    ) async {
      await routed(tester, '/commerce/orders/detail', extra: extra);
      expect(find.text('无法查看此订单'), findsOneWidget);
      expect(find.byKey(const ValueKey('order-pay')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'business cancellation persists after reopening and blocks payment',
    (tester) async {
      final container = await routed(
        tester,
        '/commerce/orders/detail',
        extra: const FakeOrderRef('order-scan-v8-0827'),
      );
      await tester.tap(find.byKey(const ValueKey('order-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('order-cancel-confirm')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/commerce/orders');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('order-card-order-scan-v8-0827')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('order-detail-status')),
          matching: find.text('已取消'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('order-pay')), findsNothing);
      container
          .read(appRouterProvider)
          .go(
            '/commerce/payment',
            extra: const FakePaymentIntentRef(
              'payment-intent-order-scan-v8-0827',
            ),
          );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('payment-confirm')), findsNothing);
      expect(
        find.byKey(const ValueKey('payment-result-orderStateChanged')),
        findsOneWidget,
      );
    },
  );

  testWidgets('payment cancellation preserves the original pending order', (
    tester,
  ) async {
    final container = await routed(
      tester,
      '/commerce/payment',
      extra: const FakePaymentIntentRef('payment-intent-order-scan-v8-0827'),
    );
    await tester.longPress(find.byKey(const ValueKey('legacy-club-title')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('payment-scenario-providerCancelled')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payment-confirm')));
    await finishPayment(tester);
    expect(
      container
          .read(fakeCommerceRepositoryProvider)
          .order('order-scan-v8-0827')
          ?.status,
      CommerceOrderStatus.awaitingPayment,
    );
    await tester.tap(find.text('稍后支付'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OrderDetailPage>(find.byType(OrderDetailPage))
          .orderRef
          .opaqueId,
      'order-scan-v8-0827',
    );
    expect(find.byKey(const ValueKey('order-pay')), findsOneWidget);
  });

  testWidgets(
    'leaving during payment preserves pending status and blocks another attempt',
    (tester) async {
      final container = await routed(
        tester,
        '/commerce/payment',
        extra: const FakePaymentIntentRef('payment-intent-order-scan-v8-0827'),
      );
      await tester.tap(find.byKey(const ValueKey('payment-confirm')));
      await tester.pump();
      container.read(appRouterProvider).go('/commerce/orders');
      await tester.pumpAndSettle();
      container
          .read(appRouterProvider)
          .go(
            '/commerce/payment',
            extra: const FakePaymentIntentRef(
              'payment-intent-order-scan-v8-0827',
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('支付结果待确认'), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-confirm')), findsNothing);
      expect(find.byKey(const ValueKey('payment-reconcile')), findsOneWidget);
    },
  );

  testWidgets(
    'logout clears the repository; late payment result cannot revive it',
    (tester) async {
      final container = await routed(
        tester,
        '/commerce/payment',
        extra: const FakePaymentIntentRef('payment-intent-order-scan-v8-0827'),
      );
      final repository = container.read(fakeCommerceRepositoryProvider);
      await tester.tap(find.byKey(const ValueKey('payment-confirm')));
      await tester.pump();
      repository.clear();
      await finishPayment(tester);
      expect(repository.orders, isEmpty);
      expect(find.text('无法继续支付'), findsOneWidget);
      container.read(appRouterProvider).go('/me/settings');
      await tester.pumpAndSettle();
      final generation = repository.generation;
      tester
          .widget<SettingsPage>(find.byType(SettingsPage))
          .onLogoutCompleted
          ?.call();
      await tester.pumpAndSettle();
      expect(repository.generation, generation + 1);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/auth/mobile',
      );
    },
  );
}
