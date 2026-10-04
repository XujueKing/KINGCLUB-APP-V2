import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/secure_together_play_repository.dart';
import 'package:kingclub/src/features/club/presentation/together_booking_page.dart';

import 'together_play_test.dart' show fixture;

void main() {
  final session = <String, dynamic>{
    'account': {'userAccount': 'member'},
    'sessionId': 's',
    'apiKeyId': 'k',
    'apiKey': 'secret',
  };
  const booking = TogetherBooking(
    ref: 'booking',
    partyRef: 'party',
    status: 'paying',
    basePriceMinor: 1000,
    ageSurchargeMinor: 0,
    payableMinor: 1000,
  );

  test(
    'query sends only original booking and rejects mismatched paid receipt',
    () async {
      final repo = SecureTogetherPlayRepository(
        readSession: () async => session,
        request: (id, params, _) async {
          expect(id, 'K261004001995');
          expect(params, {'action': 'query', 'bookingRef': 'booking'});
          return {
            'result': {
              'bookingRef': 'booking',
              'status': 'paid',
              'receipt': {
                'bookingRef': 'booking',
                'partyRef': 'party',
                'storeRef': 'another-store',
                'method': 'wechat',
                'currency': 'CNY',
                'totalCents': '1000',
              },
            },
          };
        },
      );
      await expectLater(
        repo.wechatBooking(booking, action: 'query', storeRef: 'store'),
        throwsA(anything),
      );
    },
  );

  test(
    'prepare preserves coupon and coins and does not treat SDK payload as paid',
    () async {
      final repo = SecureTogetherPlayRepository(
        readSession: () async => session,
        request: (_, params, _) async {
          expect(params['expectedCents'], '1000');
          expect(params['coins'], '10');
          expect(params['coupon'], {
            'itemRef': 'coupon',
            'expectedDiscountCents': '200',
          });
          return {
            'result': {
              'bookingRef': 'booking',
              'status': 'paying',
              'payment': {
                'appId': 'app',
                'partnerId': 'merchant',
                'prepayId': 'prepay',
                'packageValue': 'Sign=WXPay',
                'nonceStr': 'nonce',
                'timeStamp': '123',
                'sign': 'signature',
              },
            },
          };
        },
      );
      final result = await repo.wechatBooking(
        booking,
        action: 'prepare',
        storeRef: 'store',
        coins: 10,
        coupon: const TogetherCoupon(
          ref: 'coupon',
          name: '券',
          discountMinor: 200,
        ),
      );
      expect(result.status, 'paying');
      expect(result.payment?['prepayId'], 'prepay');
    },
  );

  testWidgets(
    'reopening paying booking locks methods until server confirms cancellation',
    (tester) async {
      final party = fixture();
      var status = 'paying';
      final actions = <String>[];
      final repo = SecureTogetherPlayRepository(
        readSession: () async => session,
        request: (id, params, _) async {
          if (id == 'K261004001988') {
            return {
              'result': {
                'bookingRef': 'booking',
                'partyRef': party.ref,
                'status': status,
                'quote': {
                  'currency': 'CNY',
                  'basePriceCents': '1000',
                  'ageSurchargeCents': '0',
                  'payableCents': '1000',
                },
              },
            };
          }
          if (id == 'K261004001992') {
            return {
              'result': {
                'bookingRef': 'booking',
                'storeRef': party.storeRef,
                'items': [],
              },
            };
          }
          expect(id, 'K261004001995');
          actions.add(params['action'] as String);
          if (params['action'] == 'cancel') status = 'pending';
          return {
            'result': {'bookingRef': 'booking', 'status': status},
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TogetherBookingPage(party: party, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButton<String>), findsNothing);
      await tester.tap(find.text('查询付款结果'));
      await tester.pumpAndSettle();
      expect(find.text('查看入场券'), findsNothing);
      expect(find.byType(DropdownButton<String>), findsNothing);
      await tester.tap(find.text('取消本次微信付款'));
      await tester.pumpAndSettle();
      expect(actions, ['query', 'cancel']);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.textContaining('尚未扣款或占位'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
