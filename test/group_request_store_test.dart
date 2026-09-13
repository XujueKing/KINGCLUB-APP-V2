import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/group_request_store.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('independent store instances serialize identity creation and isolate accounts', () async {
    final ids = await Future.wait(
      List.generate(12, (_) => GroupRequestStore('a').identity('transfer')),
    );
    expect(ids.toSet().length, 1);
    expect(await GroupRequestStore('a').identity('transfer'), ids.first);
    expect(await GroupRequestStore('b').identity('transfer'), isNot(ids.first));
    await GroupRequestStore('a').acknowledge('transfer', 'old');
    expect(await GroupRequestStore('a').identity('transfer'), ids.first);
    await GroupRequestStore('a').acknowledge('transfer', ids.first);
    expect(await GroupRequestStore('a').identity('transfer'), isNot(ids.first));
  });
  test('recreated repository retries unacknowledged transfer using persisted identity', () async {
    final requests = <Map<String, dynamic>>[];
    final messaging = MessagingRepository(
      account: 'a',
      call: (id, params) async {
        expect(id, 'K260913000626');
        requests.add(params);
        if (requests.length == 1) throw StateError('lost acknowledgement');
        return {'groupId': 'group', 'ownerAccount': 'b', 'metadataVersion': 4};
      },
    );
    await expectLater(
      GroupChatRepository(messaging).transfer('group', 'b', 3),
      throwsStateError,
    );
    await GroupChatRepository(messaging).transfer('group', 'b', 3);
    expect(requests[0]['requestId'], requests[1]['requestId']);
    expect(requests[1]['expectedVersion'], 3);
    expect(requests[1]['target'], 'b');
  });
  test(
    'invitation retries retain identity across repository recreation',
    () async {
      final requests = <Map<String, dynamic>>[];
      final messaging = MessagingRepository(
        account: 'a',
        call: (id, params) async {
          expect(id, 'K260913000628');
          requests.add(params);
          if (requests.length == 1) throw StateError('lost acknowledgement');
          return {
            'groupId': 'group',
            'target': 'b',
            'invitationId': 'invite',
            'status': 'pending',
          };
        },
      );
      await expectLater(
        GroupChatRepository(messaging).invite('group', 'b'),
        throwsStateError,
      );
      await GroupChatRepository(messaging).invite('group', 'b');
      expect(requests[0]['requestId'], requests[1]['requestId']);
      await GroupChatRepository(messaging).invite('group', 'b');
      expect(requests[2]['requestId'], isNot(requests[1]['requestId']));
    },
  );
}
