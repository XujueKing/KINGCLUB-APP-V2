import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_session_controller.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, history;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final group in [false, true]) {
    test(
      'reply queue survives $group controller recreation with same identity',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final queue = MemoryOutbox();
        final calls = <Map<String, dynamic>>[];
        var enabled = false;
        final repository = MessagingRepository(
          account: 'me',
          call: (id, p) async {
            if (id == 'K260913000619') return {'members': []};
            if (id == 'K260913000604' || id == 'K260913000621') {
              return {
                ...history([]),
                'canReply': enabled,
                'membershipVersion': 0,
                'joinedSequence': 0,
                'readSequence': 0,
                'settings': {'hiddenThrough': 0},
              };
            }
            if (id == (group ? 'K260913000620' : 'K260913000601')) {
              calls.add({...p});
              throw const AuthFailure('NETWORK_ERROR', 'offline');
            }
            return {};
          },
        );
        ChatSessionController open() => group
            ? GroupChatController(
                groupId: 'group',
                outbox: queue,
                repository: GroupChatRepository(repository),
              )
            : DirectChatController(
                repository: repository,
                peer: 'peer',
                outbox: queue,
              );
        const source = '11111111-1111-4111-8111-111111111111';
        final first = open();
        await first.initialize();
        await expectLater(
          first.send('reply', replyToMessageId: source),
          throwsStateError,
        );
        expect(queue.items, isEmpty);
        enabled = true;
        await first.synchronize();
        await first.send('reply', replyToMessageId: source);
        expect(queue.items.values.single['replyToMessageId'], source);
        final id = queue.items.keys.single;
        first.dispose();
        final second = open();
        await second.initialize();
        await second.retryQueued();
        expect(calls.length, greaterThanOrEqualTo(2));
        expect(
          calls.every(
            (c) =>
                c['replyToMessageId'] == source && c['clientMessageId'] == id,
          ),
          isTrue,
        );
        second.dispose();
      },
    );
  }
}
