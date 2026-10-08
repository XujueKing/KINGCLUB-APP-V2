import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_localizations.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/data/reservation_products.dart';
import 'package:kingclub/src/features/club/presentation/reservation_discovery_page.dart';
import 'package:kingclub/src/features/club/presentation/reservation_products_page.dart';

Map<String, dynamic> product({int deposit = 0}) => {
  'ref': '00000000-0000-4000-8000-000000000001',
  'storeRef': 'store-a',
  'storeName': 'Test store',
  'title': 'Test booth',
  'description': 'Test rules',
  'type': 'booth',
  'image': null,
  'version': 2,
  'startsAt': '2030-01-01T12:00:00.000Z',
  'endsAt': '2030-01-01T16:00:00.000Z',
  'minimumSeats': 1,
  'maximumSeats': 10,
  'depositCents': '$deposit',
  'minimumSpendCents': '0',
  'currency': 'CNY',
  'canBook': deposit == 0,
  'tables': [
    {'ref': 'v1', 'name': 'V1', 'capacity': 10, 'available': true},
  ],
};
Future<void> pumpPage(WidgetTester t, Widget page) async {
  await t.pumpWidget(
    MaterialApp(
      locale: kingSupportedLocales.first,
      supportedLocales: kingSupportedLocales,
      localizationsDelegates: kingLocalizationDelegates,
      theme: KingTheme.dark,
      home: page,
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('amount input keeps exact cents and refuses excess precision', () {
    expect(reservationAmountInput('1000.25'), 100025);
    expect(reservationAmountInput('0.01'), 1);
    expect(reservationAmountInput('0'), 0);
    for (final s in ['1,000.00', '-1', '0.001', '99999999', '1.2.3']) {
      expect(reservationAmountInput(s), null);
    }
  });
  testWidgets('catalog is one page request and has no personal create entry', (
    t,
  ) async {
    final calls = <Map<String, dynamic>>[];
    await pumpPage(
      t,
      ReservationDiscoveryPage(
        cityCode: '430200',
        call: (p) async {
          calls.add(p);
          return {
            'items': [product()],
            'hasMore': false,
          };
        },
      ),
    );
    expect(calls, [
      {'action': 'catalog', 'cityCode': '430200', 'type': 'all', 'page': 0},
    ]);
    expect(find.text('Test booth'), findsOneWidget);
    expect(find.text('创建派对'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });
  testWidgets('deposit products cannot use the free booking action', (t) async {
    final calls = <Map<String, dynamic>>[];
    await pumpPage(
      t,
      ReservationProductDetailPage(
        productRef: '00000000-0000-4000-8000-000000000001',
        call: (p) async {
          calls.add(p);
          return {
            'items': [product(deposit: 10000)],
          };
        },
      ),
    );
    final action = t.widget<FilledButton>(find.byType(FilledButton));
    expect(action.onPressed, null);
    expect(calls.length, 1);
  });
  testWidgets(
    'failed free booking retains its request id and success uses the server receipt',
    (t) async {
      final requests = <String>[];
      int attempts = 0;
      await pumpPage(
        t,
        ReservationProductDetailPage(
          productRef: '00000000-0000-4000-8000-000000000001',
          call: (p) async {
            if (p['action'] == 'detail')
              return {
                'items': [product()],
              };
            requests.add(p['requestId']);
            attempts++;
            if (attempts == 1) throw StateError('temporary failure');
            return {
              'reservation': {
                'ref': p['requestId'],
                'status': 'reserved',
                'partySize': p['partySize'],
                'startsAt': product()['startsAt'],
                'snapshot': {
                  'title': 'Test booth',
                  'storeName': 'Test store',
                  'tableName': 'V1',
                  'description': 'Confirmed server snapshot',
                  'depositCents': '0',
                  'currency': 'CNY',
                },
              },
            };
          },
        ),
      );
      final scrollable = find
          .descendant(
            of: find.byType(ReservationProductDetailPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.scrollUntilVisible(find.text('V1 · 10'), 250, scrollable: scrollable);
      await t.tap(find.text('V1 · 10'));
      await t.pump();
      await t.scrollUntilVisible(
        find.byType(TextField),
        250,
        scrollable: scrollable,
      );
      await t.enterText(find.byType(TextField), 'Test customer');
      await t.scrollUntilVisible(
        find.byType(CheckboxListTile),
        250,
        scrollable: scrollable,
      );
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
      expect(find.byType(ReservationReceiptPage), findsNothing);
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
      expect(find.byType(ReservationReceiptPage), findsOneWidget);
      expect(find.text('Confirmed server snapshot'), findsOneWidget);
    },
  );
  testWidgets(
    'merchant product editor uses aggregated tables and does not request each component',
    (t) async {
      final calls = <Map<String, dynamic>>[];
      await pumpPage(
        t,
        ReservationProductsPage(
          storeRef: 'store-a',
          call: (p) async {
            calls.add(p);
            return {
              'store': {
                'ref': 'store-a',
                'name': 'Test store',
                'currency': 'CNY',
              },
              'products': [],
              'tables': [
                {'ref': 'v1', 'name': 'V1', 'capacity': 10},
              ],
              'artworks': [],
            };
          },
        ),
      );
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
      expect(find.byType(ReservationProductEditorPage), findsOneWidget);
      expect(calls.length, 1);
      await t.scrollUntilVisible(
        find.text('V1 · 10'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ReservationProductEditorPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('V1 · 10'), findsOneWidget);
    },
  );
  testWidgets(
    'cancellation displays the returned state and never invents a refund',
    (t) async {
      final receipt = {
        'ref': '00000000-0000-4000-8000-000000000005',
        'status': 'reserved',
        'partySize': 3,
        'startsAt': product()['startsAt'],
        'snapshot': {
          'storeName': 'Test store',
          'tableName': 'V1',
          'description': 'Rules',
          'depositCents': '0',
          'currency': 'CNY',
        },
      };
      final calls = <Map<String, dynamic>>[];
      await pumpPage(
        t,
        ReservationReceiptPage(
          reservation: receipt,
          call: (p) async {
            calls.add(p);
            return {
              'reservation': {...receipt, 'status': 'cancelled'},
            };
          },
        ),
      );
      await t.ensureVisible(find.byType(OutlinedButton));
      await t.tap(find.byType(OutlinedButton));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, '取消预约'));
      await t.pumpAndSettle();
      expect(calls.single['action'], 'cancel');
      expect(find.text('已取消'), findsOneWidget);
      expect(find.text('退款成功'), findsNothing);
    },
  );
}
