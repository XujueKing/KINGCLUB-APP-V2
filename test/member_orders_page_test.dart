import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/member_orders_repository.dart';
import 'package:kingclub/src/features/commerce/presentation/member_orders_page.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';

import 'member_orders_repository_test.dart' as data;

MemberOrdersSnapshot snapshot() =>
    MemberOrdersSnapshot.parse(data.pageFixture());
void main() {
  testWidgets('session change invalidates an older response before rereading', (
    tester,
  ) async {
    final old = Completer<MemberOrdersSnapshot>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MemberOrdersPage(
          onBack: () {},
          events: const Stream.empty(),
          load: ({orderRef, beforeOrder}) {
            calls++;
            return calls == 1
                ? old.future
                : Future.value(
                    MemberOrdersSnapshot.parse(data.pageFixture(orders: [])),
                  );
          },
        ),
      ),
    );
    SecureSessionStore.changes.add(null);
    await tester.pumpAndSettle();
    old.complete(snapshot());
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Test store'), findsNothing);
    expect(find.text('No orders yet'), findsOneWidget);
  });
  testWidgets(
    'loads the next page using its server cursor and opens only the selected reference',
    (tester) async {
      final first = List.generate(
        20,
        (i) => data.orderFixture(id: 'D${(i + 1).toString().padLeft(11, '0')}'),
      );
      final cursors = <String?>[];
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: MemberOrdersPage(
            onBack: () {},
            events: const Stream.empty(),
            onOpenOrder: (id) => opened = id,
            load: ({orderRef, beforeOrder}) async {
              cursors.add(beforeOrder);
              return MemberOrdersSnapshot.parse(
                beforeOrder == null
                    ? data.pageFixture(orders: first, next: 'D00000000020')
                    : data.pageFixture(
                        orders: [data.orderFixture(id: 'D00000000021')],
                      ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member-order-D00000000001')));
      expect(opened, 'D00000000001');
      await tester.scrollUntilVisible(find.text('Load more'), 500);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(cursors, [null, 'D00000000020']);
      expect(find.text('Load more'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('member-order-D00000000021')),
        300,
      );
      expect(
        find.byKey(const ValueKey('member-order-D00000000021')),
        findsOneWidget,
      );
    },
  );
  testWidgets('shows server postpay state and detail with served quantities', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberOrdersPage(
          onBack: () {},
          orderRef: 'D00000000001',
          events: const Stream.empty(),
          load: ({orderRef, beforeOrder}) async => snapshot(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Awaiting checkout'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF101010),
    );
    expect(find.text('Order time'), findsOneWidget);
    expect(find.text('Order number'), findsOneWidget);
    expect(find.text('Served 1/2'), findsOneWidget);
    expect(find.textContaining('¥20.00'), findsWidgets);
    expect(
      find.textContaining('Please check and settle at the cashier.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'coalesces notifications, ignores pushed money, rereads after reconnect',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MemberOrdersPage(
            onBack: () {},
            events: events.stream,
            load: ({orderRef, beforeOrder}) async {
              calls++;
              return snapshot();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        events.add({'eventType': 'commerce.changed', 'totalCents': 999999});
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 351));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.textContaining('999999'), findsNothing);
      events.add({'eventType': 'connection.ready'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 351));
      await tester.pumpAndSettle();
      expect(calls, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      await events.close();
    },
  );
  testWidgets(
    'inflight notification schedules a follow-up without overlapping requests',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      final first = Completer<MemberOrdersSnapshot>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MemberOrdersPage(
            onBack: () {},
            events: events.stream,
            load: ({orderRef, beforeOrder}) {
              calls++;
              return calls == 1 ? first.future : Future.value(snapshot());
            },
          ),
        ),
      );
      events.add({'eventType': 'commerce.changed'});
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      first.complete(snapshot());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 351));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await events.close();
    },
  );
  testWidgets('hides private orders in background and rejects late response', (
    tester,
  ) async {
    final first = Completer<MemberOrdersSnapshot>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MemberOrdersPage(
          onBack: () {},
          events: const Stream.empty(),
          load: ({orderRef, beforeOrder}) {
            calls++;
            return calls == 1 ? first.future : Future.value(snapshot());
          },
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    first.complete(snapshot());
    await tester.pump();
    expect(find.text('Test store'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Test store'), findsOneWidget);
    expect(calls, 2);
  });
  testWidgets('errors never fall back to sample orders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberOrdersPage(
          onBack: () {},
          events: const Stream.empty(),
          load: ({orderRef, beforeOrder}) async =>
              throw Exception('unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Orders are unavailable'), findsOneWidget);
    expect(find.text('Test store'), findsNothing);
  });
  testWidgets('four languages remain readable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in [
      const Locale('zh'),
      const Locale('en'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      const Locale('th'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: [locale],
          home: MemberOrdersPage(
            key: ValueKey(locale),
            onBack: () {},
            orderRef: 'D00000000001',
            events: const Stream.empty(),
            load: ({orderRef, beforeOrder}) async => snapshot(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
