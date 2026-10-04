import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/secure_together_play_repository.dart';

void main() {
  final session = <String, dynamic>{
    'account': {'userAccount': 'member-test'},
    'sessionId': 'session-test',
    'apiKeyId': 'key-test',
    'apiKey': 'secret-test',
  };
  Map<String, dynamic> row(String ref) => {
    'confirmedCount': 0,
    'myBookingStatus': null,
    'ref': ref,
    'theme': '活动',
    'cityCode': '430200',
    'storeRef': 'store-test',
    'storeName': '门店',
    'storeLogo': 'https://example.test/store-logo.png',
    'startsAt': '2030-01-01T16:00:00.000Z',
    'endsAt': '2030-01-01T20:00:00.000Z',
    'capacity': 10,
    'priceCents': '15000',
    'feeMode': 'aa',
    'place': '活动地点',
    'description': '说明',
    'backgroundUrl': 'https://example.test/a.jpg',
    'posterUrl': 'https://example.test/b.jpg',
  };
  test('saved participation rules are visible without overriding server eligibility', () async {
    final repo = SecureTogetherPlayRepository(
      readSession: () async => session,
      request: (_, _, _) async => {
        'result': {
          'item': {
            ...row('rules'),
            'eligibilityRules': {
              'minAge': 18,
              'maxAge': 30,
              'overageCentsPerYear': '1000',
              'minimumMaleScore': 80,
              'minimumFemaleScore': 85.5,
              'excludedStarSigns': ['双鱼座'],
            },
            'eligibility': {
              'eligible': false,
              'reasons': ['不符合本场星座要求'],
              'payableCents': null,
            },
          },
        },
      },
    );
    final party = await repo.detail('rules');
    expect(party.storeLogo, 'https://example.test/store-logo.png');
    expect(party.rules, contains('18—30周岁'));
    expect(party.rules, contains('超龄每岁加¥10.00'));
    expect(party.rules, contains('男士颜值80分起'));
    expect(party.rules, contains('女士颜值85.5分起'));
    expect(party.rules, contains('不接受双鱼座'));
    expect(party.eligible, false);
    expect(party.personalPriceMinor, isNull);
  });
  test(
    'redeemed ticket preserves assigned table without issuing another code',
    () async {
      final repo = SecureTogetherPlayRepository(
        readSession: () async => session,
        request: (id, p, _) async {
          expect(id, 'K261004001986');
          return {
            'result': {
              'item': {
                ...row('a'),
                'myBookingStatus': 'paid',
                'ticketNumber': 'booking-a',
                'assignedTable': 'V15',
                'admissionUsed': true,
                'eligibility': {
                  'eligible': true,
                  'reasons': [],
                  'payableCents': '15000',
                },
              },
            },
          };
        },
      );
      final ticket = await repo.admission('a');
      expect(ticket.admissionUsed, true);
      expect(ticket.assignedTable, 'V15');
      expect(ticket.ticketNumber, 'booking-a');
      expect(ticket.admissionCode, isNull);
    },
  );
  test('admission requires paid booking and validates scoped unexpired server code', () async {
    for (final mode in [
      'ok',
      'pending',
      'scope',
      'expired',
      'code',
      'session',
    ]) {
      var current = session;
      var issueCalls = 0;
      final repo = SecureTogetherPlayRepository(
        readSession: () async => current,
        request: (id, p, _) async {
          if (id == 'K261004001986') {
            return {
              'result': {
                'item': {
                  ...row('a'),
                  'myBookingStatus': mode == 'pending' ? 'pending' : 'paid',
                  'eligibility': {
                    'eligible': true,
                    'reasons': [],
                    'payableCents': '15000',
                  },
                },
              },
            };
          }
          expect(id, 'K261004001989');
          issueCalls++;
          if (mode == 'session') current = {...session, 'sessionId': 'changed'};
          return {
            'result': {
              'partyRef': mode == 'scope' ? 'other' : 'a',
              'ticketNumber': 'booking-a',
              'admissionCode': mode == 'code'
                  ? 'invented'
                  : 'KCTICKET1:${List.filled(43, 'a').join()}',
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(Duration(minutes: mode == 'expired' ? -1 : 5))
                  .toIso8601String(),
            },
          };
        },
      );
      if (mode == 'ok') {
        final ticket = await repo.admission('a');
        expect(ticket.ticketNumber, 'booking-a');
        expect(ticket.admissionCode, startsWith('KCTICKET1:'));
        expect(ticket.admissionExpiresAt, isNotNull);
        expect(ticket.storeName, '门店');
      } else {
        await expectLater(repo.admission('a'), throwsA(anything));
      }
      expect(issueCalls, mode == 'pending' ? 0 : 1);
    }
  });
  test(
    'booking uses stable request and validates authoritative amount and scope',
    () async {
      for (final mode in ['ok', 'amount', 'scope']) {
        final calls = <Map<String, dynamic>>[];
        final repo = SecureTogetherPlayRepository(
          readSession: () async => session,
          request: (id, p, _) async {
            expect(id, 'K261004001988');
            calls.add(p);
            return {
              'result': {
                'bookingRef': 'booking-test',
                'partyRef': mode == 'scope' ? 'other' : 'a',
                'status': 'pending',
                'quote': {
                  'currency': 'CNY',
                  'basePriceCents': '15000',
                  'ageSurchargeCents': '1000',
                  'payableCents': mode == 'amount' ? '1' : '16000',
                },
              },
            };
          },
        );
        if (mode == 'ok') {
          final booking = await repo.prepareBooking('a', requestRef: 'stable');
          final retry = await repo.prepareBooking('a', requestRef: 'stable');
          expect(booking.status, 'pending');
          expect(booking.payableMinor, 16000);
          expect(retry.ref, booking.ref);
          expect(calls[0], calls[1]);
        } else {
          await expectLater(
            repo.prepareBooking('a', requestRef: 'stable'),
            throwsA(anything),
          );
        }
      }
    },
  );
  test(
    'booking state and paid count control action without fabricated QR',
    () async {
      for (final state in [null, 'pending', 'paying', 'paid', 'refunded']) {
        final repo = SecureTogetherPlayRepository(
          readSession: () async => session,
          request: (_, p, _) async => {
            'result': {
              'item': {
                ...row('a'),
                'myBookingStatus': state,
                'confirmedCount': 10,
                'eligibility': {
                  'eligible': true,
                  'reasons': [],
                  'payableCents': '15000',
                },
              },
            },
          },
        );
        final party = await repo.detail('a');
        expect(party.participantCount, 10);
        expect(
          party.actionLabel,
          state == null
              ? '已满员'
              : state == 'pending' || state == 'paying'
              ? '继续支付'
              : state == 'paid'
              ? '入场码'
              : '已取消',
        );
        expect(party.admissionCode, isNull);
        expect(party.participants, isEmpty);
      }
    },
  );
  test(
    'pages by venue date at midnight and never invents paid tickets',
    () async {
      final calls = <Map<String, dynamic>>[];
      final repo = SecureTogetherPlayRepository(
        readSession: () async => session,
        request: (id, p, _) async {
          expect(id, 'K261004001985');
          calls.add(p);
          return {
            'result': {
              'cityCode': p['cityCode'],
              'startsFrom': p['startsFrom'],
              'startsBefore': p['startsBefore'],
              'items': [row(p['after'] == null ? 'a' : 'b')],
              'next': p['after'] == null ? 'a' : null,
            },
          };
        },
      );
      final items = await repo.list(
        cityCode: '430200',
        date: DateTime(2030, 1, 2),
      );
      expect(calls.first['startsFrom'], '2030-01-01T16:00:00.000Z');
      expect(calls.last['after'], 'a');
      expect(items.map((p) => p.ref), ['a', 'b']);
      expect(items.first.startsAt, DateTime(2030, 1, 2));
      expect(items.first.hasAdmissionTicket, false);
      expect(items.first.admissionCode, isNull);
    },
  );
  test('rejects foreign date or city and repeated pagination', () async {
    for (final mode in ['date', 'city', 'cursor']) {
      final repo = SecureTogetherPlayRepository(
        readSession: () async => session,
        request: (_, p, _) async {
          final r = row('a');
          if (mode == 'date') r['startsAt'] = '2030-01-01T15:59:00.000Z';
          if (mode == 'city') r['cityCode'] = '430100';
          return {
            'result': {
              'cityCode': p['cityCode'],
              'startsFrom': p['startsFrom'],
              'startsBefore': p['startsBefore'],
              'items': [r],
              'next': mode == 'cursor' ? 'a' : null,
            },
          };
        },
      );
      await expectLater(
        repo.list(cityCode: '430200', date: DateTime(2030, 1, 2)),
        throwsA(anything),
      );
    }
  });
  test(
    'detail maps personal price and rejects changed session or wrong activity',
    () async {
      for (final mode in ['ok', 'session', 'ref', 'missing']) {
        var current = session;
        final repo = SecureTogetherPlayRepository(
          readSession: () async => current,
          request: (id, p, _) async {
            expect(id, 'K261004001986');
            if (mode == 'session') {
              current = {...session, 'sessionId': 'changed'};
            }
            return {
              'result': {
                'item': {
                  ...row(mode == 'ref' ? 'other' : 'a'),
                  if (mode != 'missing')
                    'eligibility': {
                      'eligible': true,
                      'reasons': [],
                      'payableCents': '5000',
                    },
                },
              },
            };
          },
        );
        if (mode == 'ok') {
          final party = await repo.detail('a');
          expect(party.personalPriceMinor, 5000);
          expect(party.eligible, true);
        } else {
          await expectLater(repo.detail('a'), throwsA(anything));
        }
      }
    },
  );
}
