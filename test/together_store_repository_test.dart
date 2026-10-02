import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/secure_together_store_repository.dart';

void main() {
  final session = <String, dynamic>{
    'account': {'userAccount': 'member-test'},
    'sessionId': 'session-test',
    'apiKeyId': 'key-test',
    'apiKey': 'secret-test',
  };
  Map<String, dynamic> store(String ref, {String city = '430200'}) => {
    'storeRef': ref,
    'cityCode': city,
    'name': ref,
    'address': 'Test address',
  };
  test('loads all pages with exact city and cursor', () async {
    final requests = <Map<String, dynamic>>[];
    final repo = SecureTogetherStoreRepository(
      readSession: () async => session,
      request: (id, params, _) async {
        expect(id, 'K261002001980');
        requests.add(params);
        return {
          'result': {
            'cityCode': '430200',
            'items': [store(params['after'] == null ? 'a' : 'b')],
            'next': params['after'] == null ? 'a' : null,
          },
        };
      },
    );
    expect((await repo.list(cityCode: '430200')).map((s) => s.ref), ['a', 'b']);
    expect(requests.last['after'], 'a');
  });
  test('rejects foreign city, duplicate pages and invalid cursors', () async {
    for (final mode in ['foreign', 'duplicate', 'cursor']) {
      final repo = SecureTogetherStoreRepository(
        readSession: () async => session,
        request: (_, params, _) async => {
          'result': {
            'cityCode': '430200',
            'items': [
              store('a', city: mode == 'foreign' ? '430100' : '430200'),
            ],
            'next': mode == 'cursor' ? 'not-last' : 'a',
          },
        },
      );
      await expectLater(repo.list(cityCode: '430200'), throwsA(anything));
    }
  });
  test('rejects identity change during request', () async {
    var current = session;
    final repo = SecureTogetherStoreRepository(
      readSession: () async => current,
      request: (_, _, _) async {
        current = {...session, 'sessionId': 'new-session'};
        return {
          'result': {'cityCode': '430200', 'items': [], 'next': null},
        };
      },
    );
    await expectLater(repo.list(cityCode: '430200'), throwsA(anything));
  });
  test(
    'table response must belong to requested store with integer capacity',
    () async {
      for (final seats in [8, 1, 8.5]) {
        final repo = SecureTogetherStoreRepository(
          readSession: () async => session,
          request: (_, _, _) async => {
            'result': {
              'storeRef': 'a',
              'items': [
                {
                  'tableRef': 't',
                  'storeRef': 'a',
                  'name': 'Table',
                  'maximumSeats': seats,
                },
              ],
              'next': null,
            },
          },
        );
        if (seats == 8) {
          expect((await repo.tables(storeRef: 'a')).single.maximumSeats, 8);
        } else {
          await expectLater(repo.tables(storeRef: 'a'), throwsA(anything));
        }
      }
    },
  );
}
