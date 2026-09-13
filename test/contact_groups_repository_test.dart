import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/data/contact_groups_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  test(
    'lost acknowledgement retries the same request and advances the version',
    () async {
      final requests = <Map<String, dynamic>>[];
      final repo = ContactGroupsRepository(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            if (id == 'K260913000615') return {'version': 0, 'groups': []};
            requests.add(params);
            if (requests.length == 1) throw StateError('Lost acknowledgement');
            return {'version': 1, 'groups': params['groups']};
          },
        ),
      );
      await repo.load();
      final groups = [
        ContactGroup('id', '好友', 2, {'peer'}),
      ];
      await expectLater(repo.save(groups), throwsStateError);
      await repo.save(groups);
      expect(requests[0]['requestId'], requests[1]['requestId']);
      expect(requests[1]['version'], 0);
      await repo.save([]);
      expect(requests[2]['version'], 1);
      expect(requests[2]['requestId'], isNot(requests[1]['requestId']));
    },
  );
  test('late load cannot replace the version acknowledged by save', () async {
    final late = Completer<Map<String, dynamic>>();
    var loads = 0;
    final versions = <int>[];
    final repo = ContactGroupsRepository(
      MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000615') {
            loads++;
            return loads == 1 ? {'version': 0, 'groups': []} : late.future;
          }
          versions.add(params['version'] as int);
          return {'version': versions.length, 'groups': params['groups']};
        },
      ),
    );
    await repo.load();
    final pending = repo.load();
    final rejected = expectLater(pending, throwsStateError);
    await repo.save([]);
    late.complete({'version': 0, 'groups': []});
    await rejected;
    await repo.save([]);
    expect(versions, [0, 1]);
  });
}
