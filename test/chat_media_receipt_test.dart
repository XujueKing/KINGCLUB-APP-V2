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
    for (final payload in <Map<String, dynamic>>[
      {'messageType': 'image', 'imageAssetId': 'image'},
      {
        'messageType': 'voice',
        'voiceAssetId': 'voice',
        'voiceDurationMs': 3000,
      },
      {
        'messageType': 'video',
        'videoAssetId': 'video',
        'videoDurationMs': 3000,
        'videoWidth': 640,
        'videoHeight': 480,
        'videoHasAudio': true,
      },
      {
        'messageType': 'file',
        'fileAssetId': 'file',
        'fileName': 'hello.txt',
        'fileSize': 42,
        'fileSha256': 'a' * 64,
      },
      {
        'messageType': 'location',
        'location': {
          'latitudeE6': 30000000,
          'longitudeE6': 110000000,
          'coordinateSystem': 'wgs84',
          'name': 'meeting',
          'address': '',
        },
      },
      {
        'messageType': 'text',
        'text': 'original message',
        'replyToMessageId': 'original-id',
      },
    ]) {
      for (final mutation in [
        'payload',
        'missing',
        'type',
        'recalled',
        'hidden',
        'valid',
        'incoming',
      ]) {
        test(
          '${group ? "group" : "direct"} ${payload['messageType']} history reconciliation: $mutation',
          () async {
            final outbox = _Outbox();
            const id = 'pending-id';
            await outbox.put({
              'clientMessageId': id,
              'sender': 'me',
              if (group) 'groupId': 'group' else 'recipient': 'peer',
              'text': 'original message',
              ...payload,
              'status': 'failed',
              'createdDate': '2026-09-17T00:00:00Z',
            });
            var corrected = false;
            final repository = MessagingRepository(
              account: 'me',
              call: (method, _) async {
                if (method == 'K260913000619') {
                  return {'members': <Map<String, dynamic>>[]};
                }
                expect(method, group ? 'K260913000621' : 'K260913000604');
                final row = <String, dynamic>{
                  'messageId': 'server-message',
                  'conversationId': 'conversation',
                  if (group) 'groupId': 'group' else 'recipient': 'peer',
                  'sender': 'me',
                  'sequence': 1,
                  'clientMessageId': id,
                  'text': 'original message',
                  ...payload,
                  if (payload.containsKey('replyToMessageId'))
                    'reply': {'messageId': payload['replyToMessageId']},
                  'createdDate': '2026-09-17T00:00:00Z',
                };
                if (!corrected) {
                  final field = payload.containsKey('replyToMessageId')
                      ? 'reply'
                      : payload.keys.last;
                  if (mutation == 'payload') {
                    final value = row[field];
                    row[field] = value is int
                        ? value + 1
                        : value is bool
                        ? !value
                        : value is Map
                        ? {
                            ...value,
                            if (field == 'location')
                              'name': 'elsewhere'
                            else
                              'messageId': 'wrong-id',
                          }
                        : 'different';
                  }
                  if (mutation == 'missing') row.remove(field);
                  if (mutation == 'type') row['messageType'] = 'unknown';
                  if (mutation == 'incoming') {
                    row['sender'] = 'peer';
                    if (!group) row['recipient'] = 'me';
                    row['text'] = 'incoming message';
                  }
                  if (mutation == 'recalled' || mutation == 'hidden') {
                    row['messageType'] = mutation;
                    row.remove('text');
                  }
                }
                return {
                  'conversationId': 'conversation',
                  'messages': [row],
                  'hasMore': false,
                  'lastSequence': 1,
                  'readSequence': 0,
                  'peerReadSequence': 0,
                  'settings': <String, dynamic>{},
                  'sendPermission': {'allowed': true},
                };
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
            await controller.initialize();
            if (mutation == 'incoming') {
              expect(outbox.rows[id]?['text'], 'original message');
              expect(controller.messages, hasLength(2));
              return;
            }
            if (['payload', 'missing', 'type'].contains(mutation)) {
              expect(outbox.rows[id]?['text'], 'original message');
              expect(controller.messages.single['text'], 'original message');
              expect(controller.messages.single['sequence'], isNull);
              expect(controller.error, isNotNull);
              corrected = true;
              await controller.synchronize();
            }
            expect(outbox.rows, isEmpty);
            if (mutation == 'hidden') {
              expect(controller.messages, isEmpty);
            } else {
              expect(controller.messages, hasLength(1));
              expect(controller.messages.single['sequence'], 1);
            }
          },
        );
      }
    }
  }
}
