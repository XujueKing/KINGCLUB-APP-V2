import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/member_orders_repository.dart';
import 'package:kingclub/src/features/commerce/data/ordering_context.dart';
import 'package:kingclub/src/features/commerce/presentation/table_bill_page.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';

import 'member_orders_repository_test.dart' as data;

void main() {
  testWidgets('table receipt opens scoped live detail and returns to list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <Map<String, dynamic>>[];
    final pending = Completer<Map<String, dynamic>>();
    final repository = MemberOrdersRepository(
      readSession: () async => data.sessionFixture,
      request: (id, params, session) async {
        expect(id, 'K261001001955');
        calls.add(Map<String, dynamic>.from(params));
        if (calls.length == 3) return pending.future;
        return {
          'result': {
            ...data.pageFixture(),
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
    await tester.tap(find.byKey(const ValueKey('member-order-D00000000001')));
    await tester.pumpAndSettle();
    expect(find.text('Order details'), findsOneWidget);
    expect(calls.last, {
      'tableRef': 'test-table',
      'sessionRef': 'H00000000001',
      'orderRef': 'D00000000001',
    });
    expect(find.text('D00000000001'), findsOneWidget);
    expect(find.text('Test product'), findsOneWidget);
    expect(find.textContaining('Unit price'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Detail's periodic refresh retains its receipt while the request is pending.
    await tester.pump(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('D00000000001'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    pending.complete({
      'result': {
        ...data.pageFixture(),
        'tableScope': {
          'storeRef': 'test-store',
          'tableRef': 'test-table',
          'sessionRef': 'H00000000001',
        },
      },
    });
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Order details'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('T1 · Table bill'), findsOneWidget);
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
          final result = data.pageFixture(orders: cancelled ? [] : null);
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
