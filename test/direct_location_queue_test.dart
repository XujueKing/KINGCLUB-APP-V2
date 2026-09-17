import 'package:kingclub/src/features/messaging/data/chat_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, history;

final location = ChatLocation.fromJson({
  'latitudeE6': 28000000,
  'longitudeE6': 113000000,
  'coordinateSystem': 'wgs84',
  'name': 'Synthetic place',
  'address': '',
});
void main() {
  test('location network retry survives controller recreation and uses location endpoint only', () async {
    final queue = MemoryOutbox(), requests = <Map<String, dynamic>>[];
    final repo = MessagingRepository(
      account: 'me',
      call: (id, params) async {
        if (id == 'K260913000604') return history([]);
        expect(id, 'K260913000641');
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
            'messageType': 'location',
            'location': params['location'],
            'text': '[位置]',
          },
        };
      },
    );
    final first = DirectChatController(
      repository: repo,
      peer: 'peer',
      outbox: queue,
    );
    await first.sendLocation(
      location,
      clientMessageId: '33333333-3333-4333-8333-333333333333',
    );
    expect(
      queue.items.values.single['clientMessageId'],
      '33333333-3333-4333-8333-333333333333',
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
    expect(requests[1]['location'], location.toJson());
    expect(queue.items, isEmpty);
    expect(restored.messages.single['messageType'], 'location');
    restored.dispose();
  });
  test('invalid acknowledgement cannot discard a queued location', () async {
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
            'messageType': 'location',
            'location': 'different',
          },
        },
      ),
    );
    await controller.sendLocation(location);
    expect(queue.items.length, 1);
    expect(controller.messages.single['status'], 'failed');
    controller.dispose();
  });
  test('queue write failure prevents location send', () async {
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
    await expectLater(controller.sendLocation(location), throwsStateError);
    expect(calls, 0);
    expect(controller.messages, isEmpty);
    controller.dispose();
  });
}
