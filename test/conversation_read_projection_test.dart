import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/chat_read_outbox.dart';
import 'package:kingclub/src/features/messaging/data/conversation_read_projection.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'read projection keeps relay unread and newer or unknown server heads',
    () {
      final rows = [
        {
          'peer': 'p',
          'lastSequence': 5,
          'unreadCount': 4,
          'relayUnreadCount': 1,
        },
        {'peer': 'p', 'lastSequence': 6, 'unreadCount': 2},
        {'peer': 'p', 'unreadCount': 3},
        {'kind': 'group', 'groupId': 'p', 'lastSequence': 5, 'unreadCount': 2},
      ];
      final projected = const ConversationReadProjection({
        'p': 5,
      }, {}).apply(rows);
      expect(projected.map((r) => r['unreadCount']), [1, 2, 3, 2]);
      expect(rows.first['unreadCount'], 4);
    },
  );

  for (final group in [false, true]) {
    test(
      'offline read survives reopening and isolates accounts (group=$group)',
      () async {
        final queue = ChatReadOutbox('me', group: group);
        final events = <String>[];
        final sub = MessagingRepository.readChanges('me').listen(events.add);
        addTearDown(sub.cancel);
        final repo = MessagingRepository(
          account: 'me',
          readOutbox: group ? null : queue,
          groupReadOutbox: group ? queue : null,
          call: (_, _) async => throw StateError('offline'),
        );
        for (var i = 0; i < 2; i++) {
          await expectLater(
            group ? repo.markGroupRead('p', 5) : repo.markRead('p', 5),
            throwsStateError,
          );
        }
        await Future<void>.delayed(Duration.zero);
        expect(events, ['me']);
        final reopened = MessagingRepository(
          account: 'me',
          readOutbox: group ? null : ChatReadOutbox('me'),
          groupReadOutbox: group ? ChatReadOutbox('me', group: true) : null,
          call: (_, _) async => {},
        );
        final row = {
          'kind': group ? 'group' : 'direct',
          group ? 'groupId' : 'peer': 'p',
          'lastSequence': 5,
          'unreadCount': 3,
        };
        expect(
          (await reopened.pendingReadProjection()).apply([
            row,
          ]).single['unreadCount'],
          0,
        );
        final other = MessagingRepository(
          account: 'other',
          readOutbox: ChatReadOutbox('other'),
          groupReadOutbox: ChatReadOutbox('other', group: true),
          call: (_, _) async => {},
        );
        expect(
          (await other.pendingReadProjection()).apply([
            row,
          ]).single['unreadCount'],
          3,
        );
      },
    );
  }

  test(
    'read acknowledgement during list request cannot revive old badge',
    () async {
      final queue = ChatReadOutbox('me');
      await queue.put('p', 5);
      final requested = Completer<void>();
      final response = Completer<Map<String, dynamic>>();
      final repo = MessagingRepository(
        account: 'me',
        readOutbox: queue,
        call: (_, _) {
          requested.complete();
          return response.future;
        },
      );
      final load = repo.conversations();
      await requested.future;
      await queue.acknowledge('p', 5);
      response.complete({
        'items': [
          {'peer': 'p', 'lastSequence': 5, 'unreadCount': 3},
        ],
      });
      expect(((await load)['items'] as List).single['unreadCount'], 0);
    },
  );
}
