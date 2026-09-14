import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_session_controller.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_context.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final group in [false, true]) {
    test(
      'personal hide capability, failure, reload and sticky tombstone group=$group',
      () async {
        var hidden = false,
            version = 0,
            support = false,
            fail = false,
            stale = false;
        final hides = <Map<String, dynamic>>[];
        Map<String, dynamic> message() => {
          'messageId': 'm1',
          'clientMessageId': 'c1',
          'sequence': 1,
          'sender': 'peer',
          'recipient': 'me',
          if (group) 'groupId': 'group' else 'conversationId': 'conversation',
          'createdDate': '2026-09-14T01:00:00Z',
          'messageType': hidden && !stale ? 'hidden' : 'text',
          'text': hidden && !stale ? '' : 'private text',
        };
        final repository = MessagingRepository(
          account: 'me',
          call: (id, params) async {
            if (id == 'K260913000619') return {'members': []};
            if (id == (group ? 'K260914000664' : 'K260914000663')) {
              hides.add({...params});
              if (fail) throw StateError('offline');
              hidden = true;
              version++;
              return {'messageId': 'm1', 'changed': true};
            }
            return {
              'conversationId': 'conversation',
              'messages': [message()],
              'hasMore': false,
              'lastSequence': 1,
              'peerReadSequence': 0,
              'readSequence': 0,
              'settings': {'hiddenThrough': 0},
              'sendPermission': {'allowed': true},
              'historyVersion': version,
              'canHideMessage': support,
              if (group) 'membershipVersion': 0,
              if (group) 'joinedSequence': 0,
            };
          },
        );
        final dir = await Directory.systemTemp.createTemp('chat-hide-');
        final store = await ChatHistoryStore.openDatabaseWithKey(
          factory: databaseFactoryFfi,
          file: '${dir.path}/history.db',
          key: await AesGcm.with256bits().newSecretKey(),
          account: 'me',
        );
        addTearDown(() async {
          await store.close();
          await dir.delete(recursive: true);
        });
        final ChatSessionController chat = group
            ? GroupChatController(
                groupId: 'group',
                repository: GroupChatRepository(repository),
                outbox: MemoryOutbox(),
                openHistory: () async => store,
              )
            : DirectChatController(
                peer: 'peer',
                repository: repository,
                outbox: MemoryOutbox(),
                openHistory: () async => store,
              );
        await chat.synchronize();
        expect(chat.messages.single['text'], 'private text');
        expect(chat.canHideMessage('m1'), false);
        await expectLater(chat.hideMessage('m1'), throwsStateError);
        expect(hides, isEmpty);
        support = true;
        await chat.synchronize();
        expect(chat.canHideMessage('m1'), true);
        fail = true;
        await expectLater(chat.hideMessage('m1'), throwsStateError);
        expect(chat.messages.single['text'], 'private text');
        fail = false;
        await chat.hideMessage('m1');
        expect(chat.messages, isEmpty);
        expect(hides.last, {
          'messageId': 'm1',
          if (group) ...{
            'groupId': 'group',
            'membershipVersion': 0,
          } else
            'peer': 'peer',
        });
        await chat.synchronize();
        expect(chat.messages, isEmpty);
        // Even a stale body at the same revision must not replace a known tombstone.
        stale = true;
        await chat.synchronize();
        expect(chat.messages, isEmpty);
        final disk = await store.read(group ? 'group:group' : 'direct:peer');
        expect(disk.messages.single['messageType'], 'hidden');
        expect(disk.messages.single['text'], '');
        chat.dispose();
      },
    );
  }
  test(
    'hidden context target is unavailable and hidden neighbors are omitted',
    () async {
      Future<List<Map<String, dynamic>>> read(String target, int sequence) =>
          readChatHistoryContext(
            messageId: target,
            sequence: sequence,
            read: ({before, after, required limit}) async => {
              'settings': {'hiddenThrough': 0},
              'historyVersion': 2,
              'messages': [
                {
                  'messageId': 'hidden',
                  'sequence': 1,
                  'messageType': 'hidden',
                  'text': '',
                },
                {'messageId': 'visible', 'sequence': 2, 'text': 'visible'},
              ],
            },
          );
      await expectLater(read('hidden', 1), throwsStateError);
      expect((await read('visible', 2)).map((m) => m['messageId']), [
        'visible',
      ]);
    },
  );
}
