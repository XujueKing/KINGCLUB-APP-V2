import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  test(
    'legacy calls omit local receipt fields and requested IDs are deduplicated',
    () async {
      final requests = <Map<String, dynamic>>[];
      final repository = MessagingRepository(
        account: 'me',
        call: (method, params) async {
          expect(method, 'K260913000607');
          requests.add(params);
          return {
            'items': [
              {
                'kind': 'direct',
                'peer': 'friend',
                if (params.containsKey('knownLocalMessageIds'))
                  'confirmedLocalMessageIds': [id],
              },
            ],
          };
        },
      );
      await repository.conversations();
      expect(requests.single, {'offset': 0, 'limit': 50});
      await repository.conversations(knownLocalMessageIds: [id, id]);
      expect(requests.last['knownLocalMessageIds'], [id]);
      await expectLater(
        repository.conversations(knownLocalMessageIds: ['wrong']),
        throwsArgumentError,
      );
      await expectLater(
        repository.conversations(knownLocalMessageIds: List.filled(201, id)),
        throwsArgumentError,
      );
      expect(requests, hasLength(2));
    },
  );
  test(
    'unknown matching IDs, group matches and unsupported replies are rejected',
    () async {
      for (final item in [
        {'kind': 'direct'},
        {
          'kind': 'group',
          'confirmedLocalMessageIds': [id],
        },
        {
          'kind': 'direct',
          'confirmedLocalMessageIds': ['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'],
        },
        {
          'kind': 'direct',
          'confirmedLocalMessageIds': [42],
        },
      ]) {
        final repository = MessagingRepository(
          account: 'me',
          call: (_, _) async => {
            'items': [item],
          },
        );
        await expectLater(
          repository.conversations(knownLocalMessageIds: [id]),
          throwsFormatException,
        );
      }
    },
  );
}
