import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/secure_together_publication.dart';
import 'package:kingclub/src/features/club/data/together_party_draft.dart';
import 'package:kingclub/src/features/club/data/together_play.dart';
import 'package:kingclub/src/features/club/data/together_store.dart';

void main() {
  final session = <String, dynamic>{
    'account': {'userAccount': 'publisher-test'},
    'sessionId': 's',
    'apiKeyId': 'k',
    'apiKey': 'test-secret',
  };
  Map<String, dynamic> projection(String kind) => {
    'publisherType': kind,
    'contractRef': kind == 'collaborator' ? 'contract-test' : null,
    'store': {
      'ref': 'store-test',
      'name': 'Test store',
      'cityCode': '430200',
      'cityName': 'Test city',
      'address': 'Test address',
      'logo': null,
    },
    'tables': [
      {'ref': 'v1', 'name': 'V1', 'capacity': 10},
    ],
    'packages': [
      {
        'ref': 'package',
        'names': {'zh-CN': 'Test package'},
        'baseTotalCents': '80000',
      },
    ],
    'artwork': [
      {
        'ref': 'art',
        'name': 'Test artwork',
        'url': 'https://example.test/art.webp',
        'status': 'approved',
      },
    ],
    'memberLevels': [
      {'name': 'Test level', 'minimumExperience': 751},
    ],
    if (kind == 'collaborator')
      'contract': {
        'ref': 'contract-test',
        'tableRef': 'v1',
        'startsAt': '2030-01-01T00:00:00Z',
        'endsAt': '2030-02-01T00:00:00Z',
      },
  };
  test('one workspace supplies all publication pickers and trusted publisher payload', () async {
    for (final kind in ['official', 'collaborator']) {
      final calls = <String>[];
      final repo = SecureTogetherPublication(
        readSession: () async => session,
        request: (id, p, _) async {
          calls.add(id);
          if (id == 'K261008002052') return {'result': projection(kind)};
          expect(id, 'K261002001984');
          final draft = p['draft'] as Map;
          expect(draft['publisherType'], kind);
          expect(draft['tableRef'], kind == 'official' ? null : 'v1');
          expect(
            draft['contractRef'],
            kind == 'collaborator' ? 'contract-test' : null,
          );
          expect(draft['tablePoolRefs'], kind == 'official' ? ['v1'] : null);
          return {
            'result': {
              'quoteRef': 'q',
              'totalCents': '80000',
              'depositCents': '0',
              'priceCents': '8000',
              'expiresAt': DateTime.now()
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
              'policyVersion': 'test',
            },
          };
        },
      );
      final data = await repo.workspace(
        storeRef: 'store-test',
        publisherType: kind,
        contractRef: kind == 'collaborator' ? 'contract-test' : null,
      );
      expect((await data.list(cityCode: '430200')).single.ref, 'store-test');
      expect(await data.tables(storeRef: 'other-store'), isEmpty);
      expect((await data.tables(storeRef: 'store-test')).single.name, 'V1');
      expect(calls, ['K261008002052']);
      final quote = await repo.quote(
        TogetherPartyDraft(
          theme: 'Test activity',
          cityCode: '430200',
          store: data.store,
          table: data.tablesList.single,
          package: data.packages.single,
          place: 'Test address',
          startsAt: DateTime(2030, 1, 2),
          endsAt: DateTime(2030, 1, 2, 3),
          capacity: 10,
          feeMode: TogetherFeeMode.aa,
          priceMinor: 8000,
          totalCostMinor: 80000,
          description: 'Test',
          background: data.artwork.single,
          poster: data.artwork.single,
          official: kind == 'official',
          contractRef: kind == 'collaborator' ? 'contract-test' : null,
        ),
        requestRef: 'request-test',
      );
      expect(quote.depositCents, '0');
      expect(calls.length, 2);
    }
  });
  test('workspace rejects cross-store, cross-contract, unapproved artwork and changed login', () async {
    for (final fault in ['store', 'contract', 'artwork', 'session']) {
      var current = session;
      final repo = SecureTogetherPublication(
        readSession: () async => current,
        request: (_, _, _) async {
          final data = projection('collaborator');
          if (fault == 'store') (data['store'] as Map)['ref'] = 'other';
          if (fault == 'contract') {
            (data['contract'] as Map)['tableRef'] = 'other';
          }
          if (fault == 'artwork') {
            (data['artwork'] as List).first['status'] = 'pending';
          }
          if (fault == 'session') {
            current = {...session, 'sessionId': 'changed'};
          }
          return {'result': data};
        },
      );
      await expectLater(
        repo.workspace(
          storeRef: 'store-test',
          publisherType: 'collaborator',
          contractRef: 'contract-test',
        ),
        throwsA(anything),
      );
    }
  });
  test('merchant multi-table payload and per-table package total stay aligned, excluding duplicate and foreign tables', () async {
    final source = projection('official');
    (source['tables'] as List).add({'ref': 'v2', 'name': 'V2', 'capacity': 4});
    final repo = SecureTogetherPublication(
      readSession: () async => session,
      request: (id, p, _) async {
        if (id == 'K261008002052') return {'result': source};
        final draft = p['draft'] as Map;
        expect(draft['tablePoolRefs'], ['v1', 'v2']);
        expect(draft['tableRef'], isNull);
        expect(draft['totalCents'], '160000');
        return {
          'result': {
            'quoteRef': 'q',
            'totalCents': '160000',
            'depositCents': '0',
            'priceCents': '40000',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 15))
                .toIso8601String(),
            'policyVersion': 'test',
          },
        };
      },
    );
    final data = await repo.workspace(
      storeRef: 'store-test',
      publisherType: 'official',
    );
    TogetherPartyDraft draft(List<TogetherTable> tables, {int capacity = 14}) =>
        TogetherPartyDraft(
          theme: 'Test activity',
          cityCode: '430200',
          store: data.store,
          table: tables.first,
          tablePool: tables,
          package: data.packages.single,
          place: 'Test address',
          startsAt: DateTime(2030, 1, 2),
          endsAt: DateTime(2030, 1, 2, 3),
          capacity: capacity,
          feeMode: TogetherFeeMode.aa,
          priceMinor: 40000,
          totalCostMinor: 160000,
          description: 'Test',
          background: data.artwork.single,
          poster: data.artwork.single,
          official: true,
        );
    expect(draft(data.tablesList).validate(now: DateTime.now()), isNull);
    await repo.quote(draft(data.tablesList), requestRef: 'multi-request');
    expect(
      draft([data.tablesList.first, data.tablesList.first])
          .validate(now: DateTime.now()),
      isNotNull,
    );
    expect(
      draft([
        ...data.tablesList.take(1),
        const TogetherTable(
          ref: 'foreign',
          storeRef: 'other',
          name: 'V3',
          maximumSeats: 4,
        ),
      ]).validate(now: DateTime.now()),
      isNotNull,
    );
    expect(
      draft(data.tablesList, capacity: 15).validate(now: DateTime.now()),
      isNotNull,
    );
  });
}
