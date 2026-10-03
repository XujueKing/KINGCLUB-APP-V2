import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/secure_together_play_repository.dart';
import 'package:kingclub/src/features/club/presentation/together_booking_page.dart';

import 'together_play_test.dart' show fixture;

void main() {
  testWidgets(
    'lost payment response retries unchanged payment and returns after confirmation',
    (tester) async {
      final party = fixture();
      final payments = <Map<String, dynamic>>[];
      final repo = SecureTogetherPlayRepository(
        readSession: () async => {
          'account': {'userAccount': 'member'},
          'sessionId': 's',
          'apiKeyId': 'k',
          'apiKey': 'secret',
        },
        request: (id, params, _) async {
          if (id == 'K261004001992') {
            return {
              'result': {
                'bookingRef': params['bookingRef'],
                'storeRef': party.storeRef,
                'items': [
                  {'itemRef': 'coupon', 'name': '门店券', 'discountCents': '500'},
                ],
              },
            };
          }
          if (id == 'K261004001988') {
            return {
              'result': {
                'bookingRef': 'booking',
                'partyRef': party.ref,
                'status': 'pending',
                'quote': {
                  'currency': 'CNY',
                  'basePriceCents': '1000',
                  'ageSurchargeCents': '0',
                  'payableCents': '1000',
                },
              },
            };
          }
          expect(id, 'K261004001991');
          payments.add(Map.from(params));
          if (payments.length == 1) throw StateError('response lost');
          return {
            'result': {
              'bookingRef': 'booking',
              'paymentRef': 'booking',
              'partyRef': party.ref,
              'storeRef': party.storeRef,
              'currency': 'CNY',
              'method': 'store_balance',
              'totalCents': '1000',
              'coinsUsed': '0',
              'couponDiscountCents': '500',
              'coupon': {'itemRef': 'coupon'},
              'replayed': true,
            },
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TogetherBookingPage(party: party, repository: repo),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('不使用商家券'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('门店券 · 抵¥5.00').last);
      await tester.pumpAndSettle();
      expect(find.text('抵扣后应付 ¥5.00'), findsOneWidget);
      await tester.ensureVisible(find.text('确认付款'));
      await tester.tap(find.text('确认付款'));
      await tester.pumpAndSettle();
      expect(find.text('核对原付款结果'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byType(DropdownButton<String>).first,
            )
            .onChanged,
        isNull,
      );
      await tester.ensureVisible(find.text('核对原付款结果'));
      await tester.tap(find.text('核对原付款结果'));
      await tester.pumpAndSettle();
      expect(payments.length, 2);
      expect(payments.first, payments.last);
      expect(payments.first['coupon'], {
        'itemRef': 'coupon',
        'expectedDiscountCents': '500',
      });
      expect(find.text('open'), findsOneWidget);
      expect(find.byType(TogetherBookingPage), findsNothing);
    },
  );

  testWidgets(
    'lost preparation response retries the same request and stays unpaid',
    (tester) async {
      final party = fixture();
      final requests = <String>[];
      final repository = SecureTogetherPlayRepository(
        readSession: () async => {
          'account': {'userAccount': 'test-member'},
          'sessionId': 'test-session',
          'apiKeyId': 'test-key',
          'apiKey': 'test-only',
        },
        request: (id, params, _) async {
          if (id == 'K261004001992') {
            return {
              'result': {
                'bookingRef': params['bookingRef'],
                'storeRef': party.storeRef,
                'items': [],
              },
            };
          }
          expect(id, 'K261004001988');
          expect(params['partyRef'], party.ref);
          requests.add(params['requestRef'] as String);
          if (requests.length == 1) throw StateError('response lost');
          return {
            'result': {
              'bookingRef': 'test-booking',
              'partyRef': party.ref,
              'status': 'pending',
              'quote': {
                'currency': 'CNY',
                'basePriceCents': '15000',
                'ageSurchargeCents': '1000',
                'payableCents': '16000',
              },
            },
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TogetherBookingPage(party: party, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('重试'));
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(requests.first, requests.last);
      expect(find.text('优惠前应付 ¥160.00'), findsOneWidget);
      expect(find.text('年龄附加费 ¥10.00'), findsOneWidget);
      expect(find.textContaining('尚未扣款或占位'), findsOneWidget);
      expect(find.text('查看入场券'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
