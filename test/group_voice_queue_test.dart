import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox;
import 'group_chat_controller_test.dart' show history;

const asset = '12345678-1234-1234-1234-123456789012';
GroupChatRepository repository(
  Future<Map<String, dynamic>> Function(Map<String, dynamic>) send,
) => GroupChatRepository(
  MessagingRepository(
    account: 'me',
    call: (id, params) async {
      if (id == 'K260913000621') return history([]);
      if (id == 'K260913000619') return {'members': <dynamic>[]};
      expect(id, 'K260913000639');
      return send(params);
    },
  ),
);
void main() {
  test(
    'group voice retry retains identity across controller recreation',
    () async {
      final queue = MemoryOutbox(), requests = <Map<String, dynamic>>[];
      final repo = repository((params) async {
        requests.add(params);
        if (requests.length == 1) {
          throw const AuthFailure('NETWORK_ERROR', 'offline');
        }
        return {
          'message': {
            'messageId': 'm',
            'groupId': 'g',
            'sequence': 1,
            'sender': 'me',
            'clientMessageId': params['clientMessageId'],
            'messageType': 'voice',
            'voiceAssetId': params['assetId'],
            'voiceDurationMs': 2000,
            'text': '[语音]',
          },
        };
      });
      final first = GroupChatController(
        repository: repo,
        groupId: 'g',
        outbox: queue,
      );
      await first.initialize();
      await first.sendVoice(asset, 2000);
      expect(queue.items.length, 1);
      expect(first.messages.single['status'], 'queued');
      first.dispose();
      final restored = GroupChatController(
        repository: repo,
        groupId: 'g',
        outbox: queue,
      );
      await restored.initialize();
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
      expect(queue.items, isEmpty);
      expect(restored.messages.single['voiceAssetId'], asset);
      restored.dispose();
    },
  );
  test(
    'wrong group voice acknowledgement cannot remove durable queue item',
    () async {
      final queue = MemoryOutbox();
      final controller = GroupChatController(
        groupId: 'g',
        outbox: queue,
        repository: repository(
          (params) async => {
            'message': {
              'messageId': 'wrong',
              'groupId': 'g',
              'sender': 'me',
              'clientMessageId': params['clientMessageId'],
              'messageType': 'voice',
              'voiceAssetId': 'different',
            },
          },
        ),
      );
      await controller.initialize();
      await controller.sendVoice(asset, 2000);
      expect(queue.items.length, 1);
      expect(controller.messages.single['status'], 'failed');
      controller.dispose();
    },
  );
  test('revoked group access prevents new voice from entering queue', () async {
    final queue = MemoryOutbox();
    var sent = 0;
    final controller = GroupChatController(
      groupId: 'g',
      outbox: queue,
      repository: repository((_) async {
        sent++;
        return {};
      }),
    );
    await controller.initialize();
    controller.clearVisibleHistory();
    await expectLater(controller.sendVoice(asset, 2000), throwsStateError);
    expect(sent, 0);
    expect(queue.items, isEmpty);
    controller.dispose();
  });
}
