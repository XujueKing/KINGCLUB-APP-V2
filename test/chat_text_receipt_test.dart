import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';
import 'package:kingclub/src/features/messaging/data/chat_session_controller.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

class _Outbox implements ChatOutbox {
  final rows = <String, Map<String, dynamic>>{};
  @override
  Future<List<Map<String, dynamic>>> read() async => rows.values.toList();
  @override
  Future<void> put(Map<String, dynamic> row) async {
    rows[row['clientMessageId'] as String] = {...row};
  }

  @override
  Future<void> remove(String id) async {
    rows.remove(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final group in [false, true]) {
    for (final mutation in [
      'text',
      'missing',
      'type',
      'recalled',
      'hidden',
      'valid',
    ]) {
      test('${group ? "group" : "direct"} text receipt: $mutation', () async {
        final outbox = _Outbox();
        var corrected = false;
        final ids = <String>[];
        final repository = MessagingRepository(
          account: 'me',
          call: (method, params) async {
            if (method == 'K260913000621') {
              return {
                'messages': <Map<String, dynamic>>[],
                'hasMore': false,
                'lastSequence': 0,
                'readSequence': 0,
                'sendPermission': {'allowed': true},
              };
            }
            if (method == 'K260913000619') {
              return {'members': <Map<String, dynamic>>[]};
            }
            ids.add(params['clientMessageId'] as String);
            final row = <String, dynamic>{
              'messageId': 'server-message',
              'conversationId': 'conversation',
              if (group) 'groupId': 'group' else 'recipient': 'peer',
              'sender': 'me',
              'sequence': 1,
              'clientMessageId': params['clientMessageId'],
              'text': params['text'],
              'createdDate': '2026-09-17T00:00:00Z',
            };
            if (!corrected) {
              if (mutation == 'text') row['text'] = 'different payload';
              if (mutation == 'missing') row.remove('text');
              if (mutation == 'type') row['messageType'] = 'image';
              if (mutation == 'recalled' || mutation == 'hidden') {
                row['messageType'] = mutation;
                row.remove('text');
              }
            }
            return {'message': row};
          },
        );
        final ChatSessionController controller = group
            ? GroupChatController(
                repository: GroupChatRepository(repository),
                groupId: 'group',
                outbox: outbox,
              )
            : DirectChatController(
                repository: repository,
                peer: 'peer',
                outbox: outbox,
              );
        addTearDown(controller.dispose);
        if (group) await controller.initialize();
        await controller.send('original message');
        if (['text', 'missing', 'type'].contains(mutation)) {
          expect(outbox.rows.values.single['text'], 'original message');
          expect(outbox.rows.values.single['status'], 'failed');
          expect(controller.messages.single['text'], 'original message');
          expect(controller.messages.single['sequence'], isNull);
          corrected = true;
          await controller.retry(ids.single);
          expect(ids, [ids.first, ids.first]);
        }
        expect(outbox.rows, isEmpty);
        if (mutation == 'hidden') {
          expect(controller.messages, isEmpty);
        } else {
          expect(controller.messages, hasLength(1));
          expect(controller.messages.single['sequence'], 1);
        }
      });
    }
  }
}
