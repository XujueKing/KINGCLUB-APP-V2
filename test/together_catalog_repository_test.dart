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
      for (final state in [null, 'pending', 'paid', 'refunded']) {
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
              : state == 'pending'
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
