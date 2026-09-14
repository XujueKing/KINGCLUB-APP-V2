import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, history;

const asset = '12345678-1234-1234-1234-123456789012';
void main() {
  test('file network retry survives controller recreation and uses file endpoint only', () async {
    final queue = MemoryOutbox(), requests = <Map<String, dynamic>>[];
    final repo = MessagingRepository(
      account: 'me',
      call: (id, params) async {
        if (id == 'K260913000604') return history([]);
        expect(id, 'K260914000651');
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
            'messageType': 'file',
            'fileAssetId': params['assetId'],
            'fileName': 'fixture.bin',
            'fileSize': 2000,
            'fileSha256': 'a' * 64,
            'text': '[文件]',
          },
        };
      },
    );
    final first = DirectChatController(
      repository: repo,
      peer: 'peer',
      outbox: queue,
    );
    await first.sendFile(
      asset,
      'fixture.bin',
      2000,
      'a' * 64,
      clientMessageId: '22345678-1234-1234-1234-123456789012',
    );
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
    expect(restored.messages.single['messageType'], 'file');
    await restored.sendFile(
      asset,
      'fixture.bin',
      2000,
      'a' * 64,
      clientMessageId: '22345678-1234-1234-1234-123456789012',
    );
    expect(requests.length, 3);
    expect(requests[2], requests[1]);
    restored.dispose();
  });
  test('invalid acknowledgement cannot discard a queued file', () async {
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
            'messageType': 'file',
            'fileAssetId': 'different',
          },
        },
      ),
    );
    await controller.sendFile(asset, 'fixture.bin', 2000, 'a' * 64);
    expect(queue.items.length, 1);
    expect(controller.messages.single['status'], 'failed');
    controller.dispose();
  });
  test('queue write failure prevents file send', () async {
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
    await expectLater(
      controller.sendFile(asset, 'fixture.bin', 2000, 'a' * 64),
      throwsStateError,
    );
    expect(calls, 0);
    expect(controller.messages, isEmpty);
    controller.dispose();
  });
}
