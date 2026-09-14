import 'dart:io';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_session_controller.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final group in [false, true]) {
    test('reply cache follows history invalidation group=$group', () async {
      var revision = 0;
      const source = '11111111-1111-4111-8111-111111111111';
      final dir = await Directory.systemTemp.createTemp('reply-cache-');
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
      final repository = MessagingRepository(
        account: 'me',
        call: (id, p) async {
          if (id == 'K260913000619') return {'members': []};
          return {
            'conversationId': 'conversation',
            'historyVersion': revision,
            'canReply': true,
            'hasMore': false,
            'lastSequence': 2,
            'readSequence': 0,
            'peerReadSequence': 0,
            'settings': {'hiddenThrough': 0},
            'sendPermission': {'allowed': true},
            if (group) ...{'membershipVersion': 0, 'joinedSequence': 0},
            'messages': [
              {
                'messageId': 'reply',
                'clientMessageId': 'client',
                'sequence': 2,
                'sender': 'peer',
                'recipient': 'me',
                'text': 'Reply body',
                'createdDate': '2026-09-15T00:00:00Z',
                if (group)
                  'groupId': 'group'
                else
                  'conversationId': 'conversation',
                'reply': {
                  'messageId': source,
                  'available': revision == 0,
                  'sequence': 1,
                  'text': 'Original private content',
                  'headers': {'authorization': 'secret-token'},
                },
              },
            ],
          };
        },
      );
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
      final key = group ? 'group:group' : 'direct:peer';
      var disk = await store.read(key);
      expect(
        (disk.messages.single['reply'] as Map)['text'],
        'Original private content',
      );
      expect(jsonEncode(disk.messages), isNot(contains('secret-token')));
      revision = 1;
      await chat.synchronize();
      disk = await store.read(key);
      expect(disk.messages.single['reply'], {
        'messageId': source,
        'available': false,
      });
      expect(
        jsonEncode(disk.messages),
        isNot(contains('Original private content')),
      );
      expect((chat.messages.single['reply'] as Map)['available'], false);
      chat.dispose();
    });
  }
}
