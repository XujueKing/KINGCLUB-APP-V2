import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_session_controller.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox;

void main() {
  for (final group in [false, true]) {
    for (final reverse in [false, true]) {
      test(
        '${group ? 'group' : 'direct'} failed concurrent reads retry ($reverse)',
        () async {
          final calls = <int>[];
          final pending = <Completer<Map<String, dynamic>>>[];
          final repository = MessagingRepository(
            account: 'me',
            call: (_, params) {
              calls.add(params['sequence'] as int);
              final result = Completer<Map<String, dynamic>>();
              pending.add(result);
              return result.future;
            },
          );
          final ChatSessionController chat = group
              ? GroupChatController(
                  groupId: 'group',
                  outbox: MemoryOutbox(),
                  repository: GroupChatRepository(repository),
                )
              : DirectChatController(
                  peer: 'peer',
                  outbox: MemoryOutbox(),
                  repository: repository,
                );
          addTearDown(chat.dispose);
          final first = chat.markVisibleRead(5);
          final second = chat.markVisibleRead(10);
          await chat.markVisibleRead(5);
          expect(calls, [5, 10]);
          pending[reverse ? 1 : 0].completeError(StateError('offline'));
          await (reverse ? second : first);
          pending[reverse ? 0 : 1].completeError(StateError('offline'));
          await (reverse ? first : second);
          final retry = chat.markVisibleRead(5);
          expect(calls, [5, 10, 5]);
          pending.last.complete({
            'readSequence': 5,
            if (group) 'groupId': 'group',
          });
          await retry;
          await chat.markVisibleRead(5);
          expect(calls, [5, 10, 5]);
          final retryNewer = chat.markVisibleRead(10);
          pending.last.complete({
            'readSequence': 10,
            if (group) 'groupId': 'group',
          });
          await retryNewer;
          await chat.markVisibleRead(9);
          expect(calls, [5, 10, 5, 10]);
        },
      );
    }
  }
}
