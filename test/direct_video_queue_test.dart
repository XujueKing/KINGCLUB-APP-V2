import 'package:kingclub/src/features/messaging/data/chat_video.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, history;

const asset = '12345678-1234-1234-1234-123456789012';
void main() {
  test('video network retry survives controller recreation and uses video endpoint only', () async {
    final queue = MemoryOutbox(), requests = <Map<String, dynamic>>[];
    final repo = MessagingRepository(
      account: 'me',
      call: (id, params) async {
        if (id == 'K260913000604') return history([]);
        expect(id, 'K260915000665');
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
            'messageType': 'video',
            'videoAssetId': params['assetId'],
            'videoDurationMs': 2000,
            'videoWidth': 320,
            'videoHeight': 240,
            'videoHasAudio': true,
            'text': '[视频]',
          },
        };
      },
    );
    final first = DirectChatController(
      repository: repo,
      peer: 'peer',
      outbox: queue,
    );
    await first.sendVideo(
      ChatVideo(
        assetId: asset,
        durationMs: 2000,
        width: 320,
        height: 240,
        hasAudio: true,
      ),
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
    expect(restored.messages.single['messageType'], 'video');
    restored.dispose();
  });
  test('invalid acknowledgement cannot discard a queued video', () async {
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
            'messageType': 'video',
            'videoAssetId': 'different',
          },
        },
      ),
    );
    await controller.sendVideo(
      ChatVideo(
        assetId: asset,
        durationMs: 2000,
        width: 320,
        height: 240,
        hasAudio: true,
      ),
    );
    expect(queue.items.length, 1);
    expect(controller.messages.single['status'], 'failed');
    controller.dispose();
  });
  test('queue write failure prevents video send', () async {
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
      controller.sendVideo(
        ChatVideo(
          assetId: asset,
          durationMs: 2000,
          width: 320,
          height: 240,
          hasAudio: true,
        ),
      ),
      throwsStateError,
    );
    expect(calls, 0);
    expect(controller.messages, isEmpty);
    controller.dispose();
  });
}
