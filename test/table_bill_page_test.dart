import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/member_orders_repository.dart';
import 'package:kingclub/src/features/commerce/data/ordering_context.dart';
import 'package:kingclub/src/features/commerce/presentation/table_bill_page.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';

import 'member_orders_repository_test.dart' as data;

void main() {
  testWidgets('paid table items merge across pages and exclude unpaid orders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic> order(int n, String status) {
      final row = data.orderFixture(id: 'D${n.toString().padLeft(11, '0')}');
      row['status'] = status;
      row['totalCents'] = 10;
      final item = (row['items'] as List).single as Map;
      item['quantity'] = 1;
      item['priceCents'] = 10;
      item['servedQuantity'] = status == 'paid' ? 1 : 0;
      if (status == 'paid') {
        row['payment'] = {
          'amountCents': 10,
          'paidAt': '2030-01-01T12:30:00Z',
          'channel': 'wechat',
          'transactionId': '420000000000000000000000000001',
        };
      }
      return row;
    }

    final pending = Completer<Map<String, dynamic>>();
    final calls = <Map<String, dynamic>>[];
    final repository = MemberOrdersRepository(
      readSession: () async => data.sessionFixture,
      request: (_, params, _) async {
        calls.add(params);
        if (calls.length == 3) return pending.future;
        return {
          'result': {
            ...data.pageFixture(
              orders: params['beforeOrder'] == null
                  ? [
                      order(1, 'paid'),
                      for (var i = 2; i <= 20; i++)
                        order(i, i.isEven ? 'pending' : 'expired'),
                    ]
                  : [order(21, 'paid')],
              next: params['beforeOrder'] == null ? 'D00000000020' : null,
            ),
            'tableScope': {
              'storeRef': 'test-store',
              'tableRef': 'test-table',
              'sessionRef': 'H00000000001',
            },
          },
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TableBillPage(
          table: const OrderingContext(
            contextRef: 'H00000000001',
            memberRef: 'test-member',
            storeRef: 'test-store',
            tableId: 'test-table',
            tableSessionRef: 'H00000000001',
            storeName: 'Test store',
            storeAddress: '',
            tableName: 'T1',
            businessDate: '2030-01-01',
          ),
          onBack: () {},
          repository: repository,
          events: const Stream.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
    expect(calls.last['beforeOrder'], 'D00000000020');
    expect(find.byKey(const ValueKey('table-bill-store')), findsOneWidget);
    expect(find.byKey(const ValueKey('table-bill-products')), findsOneWidget);
    expect(find.text('Test store'), findsOneWidget);
    expect(find.text('Test product'), findsOneWidget);
    expect(find.text('Qty × 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('table-bill-served-test-product')),
      findsOneWidget,
    );
    expect(find.textContaining('Served '), findsNothing);
    expect(find.byKey(const ValueKey('table-bill-payments')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/legacy/ordering/WEIPAY.png',
      ),
      findsNWidgets(2),
    );
    expect(find.text('¥0.20'), findsNWidgets(2));
    expect(
      find.textContaining('420000000000000000000000000001'),
      findsNWidgets(2),
    );
    expect(find.byKey(const ValueKey('table-store-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-orders-refresh')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Qty × 2'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    pending.complete({
      'result': {
        ...data.pageFixture(orders: []),
        'tableScope': {
          'storeRef': 'test-store',
          'tableRef': 'test-table',
          'sessionRef': 'H00000000001',
        },
      },
    });
    await tester.pumpAndSettle();
    expect(find.text('Test product'), findsNothing);
    expect(find.byKey(const ValueKey('table-bill-store')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('payment opens scoped order detail and returns to table bill', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    final repository = MemberOrdersRepository(
      readSession: () async => data.sessionFixture,
      request: (_, params, _) async {
        requests.add(params);
        return {
          'result': {
            ...data.pageFixture(
              orders: [
                {
                  ...data.orderFixture(),
                  'status': 'paid',
                  'payment': {
                    'amountCents': 100,
                    'paidAt': '2030-01-01T12:30:00Z',
                    'channel': 'wechat',
                    'transactionId': '420000000000000000000000000001',
                  },
                },
              ],
            ),
            'tableScope': {
              'storeRef': 'test-store',
              'tableRef': 'test-table',
              'sessionRef': 'H00000000001',
            },
          },
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TableBillPage(
          table: const OrderingContext(
            contextRef: 'H00000000001',
            memberRef: 'test-member',
            storeRef: 'test-store',
            tableId: 'test-table',
            tableSessionRef: 'H00000000001',
            storeName: 'Test store',
            storeAddress: '',
            tableName: 'T1',
            businessDate: '2030-01-01',
          ),
          onBack: () {},
          repository: repository,
          events: const Stream.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final payment = find.byWidgetPredicate(
      (w) =>
          w is GestureDetector && w.key.toString().contains('table-payment-'),
    );
    final paymentContainer = tester.widget<Container>(
      find.descendant(of: payment, matching: find.byType(Container)).first,
    );
    expect((paymentContainer.decoration as BoxDecoration).border, isNull);
    await tester.ensureVisible(payment);
    await tester.tap(payment);
    await tester.pumpAndSettle();
    expect(requests.last['orderRef'], isNotNull);
    expect(requests.last['tableRef'], 'test-table');
    expect(requests.last['sessionRef'], 'H00000000001');
    expect(find.text('Order details'), findsOneWidget);
    expect(find.text('420000000000000000000000000001'), findsOneWidget);
    Navigator.of(tester.element(find.text('Order details'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('T1 · Table bill'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final locale in [
    const Locale('zh'),
    const Locale('en'),
    const Locale('zh', 'TW'),
    const Locale('th'),
  ]) {
    testWidgets('table bill button remains reachable at 320px $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 694);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ScanOrderingCartPage(
            onBack: () {},
            locale: locale,
            onOpenTableBill: () => opened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('ordering-table-bill')));
      expect(opened, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'table bill expands items and rereads authenticated table on notification',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      var reads = 0, cancelled = false, closed = false;
      final repository = MemberOrdersRepository(
        readSession: () async => data.sessionFixture,
        request: (id, params, session) async {
          reads++;
          if (closed) throw StateError('TABLE_SCOPE_CLOSED');
          expect(params, {
            'tableRef': 'test-table',
            'sessionRef': 'H00000000001',
          });
          final result = data.pageFixture(
            orders: cancelled
                ? []
                : [
                    {...data.orderFixture(), 'status': 'paid'},
                  ],
          );
          result['tableScope'] = {'storeRef': 'test-store', ...params};
          return {'result': result};
        },
      );
      const scope = OrderingContext(
        contextRef: 'H00000000001',
        memberRef: 'test-member',
        storeRef: 'test-store',
        tableId: 'test-table',
        tableSessionRef: 'H00000000001',
        storeName: 'Test store',
        storeAddress: '',
        tableName: 'T1',
        businessDate: '2030-01-01',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TableBillPage(
            table: scope,
            onBack: () {},
            repository: repository,
            events: events.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('T1 · Table bill'), findsOneWidget);
      expect(find.text('Test product'), findsOneWidget);
      expect(reads, 1);
      cancelled = true;
      events.add({
        'eventType': 'commerce.changed',
        'data': {
          'payload': {'target': 'member.orders'},
        },
      });
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(reads, 2);
      expect(find.text('Test product'), findsNothing);
      cancelled = false;
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(reads, 3);
      expect(find.text('Test product'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 40));
      expect(reads, 3);
      closed = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(reads, 4);
      expect(find.text('Test product'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );
}
