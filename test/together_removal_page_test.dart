import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/secure_together_play_repository.dart';
import 'package:kingclub/src/features/club/presentation/together_removal_page.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

void main() {
  for (final insufficient in [false, true]) {
    testWidgets(
      insufficient
          ? 'insufficient balance keeps participant and allows return'
          : 'lost removal payment response retries identical request before showing success',
      (tester) async {
        final payments = <Map<String, dynamic>>[];
        var removed = false;
        final repo = SecureTogetherPlayRepository(
          readSession: () async => {
            'account': {'userAccount': 'requester'},
            'sessionId': 's',
            'apiKeyId': 'k',
            'apiKey': 'test-only',
          },
          request: (id, p, _) async {
            expect(id, 'K261004001993');
            expect(p['partyRef'], 'party');
            switch (p['action']) {
              case 'list':
                return {
                  'result': {
                    'partyRef': 'party',
                    'canManage': true,
                    'items': removed
                        ? []
                        : [
                            {
                              'bookingRef': 'booking',
                              'name': 'Guest',
                              'admitted': false,
                            },
                          ],
                    'next': null,
                  },
                };
              case 'quote':
                return {
                  'result': {
                    'partyRef': 'party',
                    'bookingRef': 'booking',
                    'currency': 'CNY',
                    'refundCents': '1000',
                    'participantCompensationCents': '1000',
                    'merchantCompensationCents': '200',
                    'totalCents': '2200',
                    'methods': ['platform_cash'],
                  },
                };
              case 'pay':
                payments.add(Map.from(p));
                if (insufficient) {
                  throw const AuthFailure('MEMBER_ASSETS_INSUFFICIENT', '余额不足');
                }
                if (payments.length == 1) {
                  throw StateError('response lost');
                }
                removed = true;
                return {
                  'result': {
                    'partyRef': 'party',
                    'bookingRef': 'booking',
                    'refundRef': p['requestRef'],
                    'replayed': true,
                    'removal': {
                      'payerCents': '2200',
                      'participantCompensationCents': '1000',
                      'merchantCompensationCents': '200',
                    },
                  },
                };
              default:
                throw StateError('unexpected action');
            }
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: TogetherRemovalPage(partyRef: 'party', repository: repo),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('移除'));
        await tester.pumpAndSettle();
        expect(find.text('本次需支付 ¥22.00'), findsOneWidget);
        expect(payments, isEmpty);
        await tester.ensureVisible(find.text('确认付费并移除'));
        await tester.tap(find.text('确认付费并移除'));
        await tester.pumpAndSettle();
        expect(removed, isFalse);
        if (insufficient) {
          expect(find.text('余额不足'), findsOneWidget);
          await tester.tap(find.text('返回参加者'));
          await tester.pumpAndSettle();
          expect(find.text('Guest'), findsOneWidget);
        } else {
          expect(find.text('核对原付款结果'), findsOneWidget);
          expect(
            tester
                .widget<DropdownButton<String>>(
                  find.byType(DropdownButton<String>),
                )
                .onChanged,
            isNull,
          );
          await tester.tap(find.text('核对原付款结果'));
          await tester.pumpAndSettle();
          expect(payments.length, 2);
          expect(payments.first, payments.last);
          expect(payments.first['expectedCents'], '2200');
          expect(removed, isTrue);
          expect(find.text('暂无其他参加者'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
