import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, history;

const asset = '12345678-1234-1234-1234-123456789012';
void main() {
  test('image network retry survives controller recreation and uses image endpoint only', () async {
    final queue = MemoryOutbox(), requests = <Map<String, dynamic>>[];
    final repo = MessagingRepository(
      account: 'me',
      call: (id, params) async {
        if (id == 'K260913000604') return history([]);
        expect(id, 'K260913000632');
        requests.add(params);
        if (requests.length == 1) {
          throw const AuthFailure('NETWORK_ERROR', 'offline');
        }
        return {
          'message': {
            'messageId': 'm',
            'conversationId': 'c',
            'sequence': 1,
            'sender': 'me',
            'recipient': 'peer',
            'clientMessageId': params['clientMessageId'],
            'messageType': 'image',
            'imageAssetId': params['assetId'],
            'text': '[图片]',
          },
        };
      },
    );
    final first = DirectChatController(
      repository: repo,
      peer: 'peer',
      outbox: queue,
    );
    await first.sendImage(asset);
    expect(queue.items.length, 1);
    expect(first.messages.single['status'], 'queued');
    first.dispose();
    final restored = DirectChatController(
      repository: repo,
      peer: 'peer',
      outbox: queue,
    );
    await restored.initialize();
    expect(requests.length, 2);
    expect(requests[0], requests[1]);
    expect(requests[1]['assetId'], asset);
    expect(queue.items, isEmpty);
    expect(restored.messages.single['messageType'], 'image');
    restored.dispose();
  });
  test('invalid acknowledgement cannot discard a queued image', () async {
    final queue = MemoryOutbox();
    final controller = DirectChatController(
      peer: 'peer',
      outbox: queue,
      repository: MessagingRepository(
        account: 'me',
        call: (_, params) async => {
          'message': {
            'messageId': 'wrong',
            'sender': 'me',
            'recipient': 'peer',
            'clientMessageId': params['clientMessageId'],
            'messageType': 'image',
            'imageAssetId': 'different',
          },
        },
      ),
    );
    await controller.sendImage(asset);
    expect(queue.items.length, 1);
    expect(controller.messages.single['status'], 'failed');
    controller.dispose();
  });
  test('queue write failure prevents image send', () async {
    final queue = MemoryOutbox()..failWrite = true;
    var calls = 0;
    final controller = DirectChatController(
      peer: 'peer',
      outbox: queue,
      repository: MessagingRepository(
        account: 'me',
        call: (_, _) async {
          calls++;
          return {};
        },
      ),
    );
    await expectLater(controller.sendImage(asset), throwsStateError);
    expect(calls, 0);
    expect(controller.messages, isEmpty);
    controller.dispose();
  });
}
