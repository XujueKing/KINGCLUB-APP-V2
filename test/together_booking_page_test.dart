import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/secure_together_play_repository.dart';
import 'package:kingclub/src/features/club/presentation/together_booking_page.dart';

import 'together_play_test.dart' show fixture;

void main() {
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
