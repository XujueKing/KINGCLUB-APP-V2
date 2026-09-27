import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_gift.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, history;

void main() {
  final quote = ChatGiftQuote.tryParse({
    'giftId': 'rose',
    'name': '玫瑰',
    'assetKey': 'rose',
    'unitPrice': '9007199254740993',
  })!;
  test('gift network retry survives controller recreation and uses gift endpoint only', () async {
    final queue = MemoryOutbox(), requests = <Map<String, dynamic>>[];
    final repo = MessagingRepository(
      account: 'me',
      call: (id, params) async {
        if (id == 'K260913000604') return history([]);
        expect(id, 'K260927000803');
        requests.add(params);
        if (requests.length == 1) {
          throw const AuthFailure('NETWORK_ERROR', 'offline');
        }
        return {
          'message': {
            'messageId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            'conversationId': 'c',
            'sequence': 1,
            'sender': 'me',
            'recipient': 'peer',
            'clientMessageId': params['clientMessageId'],
            'messageType': 'gift',
            'gift': {
              'transferId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              'giftId': params['giftId'],
              'name': '玫瑰',
              'assetKey': 'rose',
              'unitPrice': params['expectedUnitPrice'],
              'quantity': params['quantity'],
              'total':
                  (BigInt.parse(params['expectedUnitPrice'] as String) *
                          BigInt.from(params['quantity'] as int))
                      .toString(),
            },
            'text': '[礼物]',
          },
        };
      },
    );
    final first = DirectChatController(
      repository: repo,
      peer: 'peer',
      outbox: queue,
    );
    await first.sendGift(quote, quantity: 2);
    final originalId = requests.single['clientMessageId'];
    expect(queue.items.values.single['clientMessageId'], originalId);
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
    expect(requests[1]['expectedUnitPrice'], '9007199254740993');
    expect(requests[1]['quantity'], 2);
    expect(queue.items, isEmpty);
    expect(restored.messages.single['messageType'], 'gift');
    restored.dispose();
  });
  test(
    'price change stops automatic retries without silently accepting new price',
    () async {
      final queue = MemoryOutbox();
      var calls = 0, peerCalls = 0;
      final controller = DirectChatController(
        peer: 'peer',
        outbox: queue,
        preferRelayText: () => true,
        sendRelayText: (_, _) async {
          peerCalls++;
          return true;
        },
        repository: MessagingRepository(
          account: 'me',
          call: (_, params) async {
            calls++;
            expect(params['expectedUnitPrice'], quote.unitPrice);
            throw const AuthFailure('CHAT_GIFT_PRICE_CHANGED', '礼物价格已变化，请重新确认');
          },
        ),
      );
      await controller.sendGift(quote);
      await controller.retryQueued();
      expect(calls, 1);
      expect(peerCalls, 0);
      expect(controller.messages.single['status'], 'failed');
      expect(queue.items.values.single['expectedUnitPrice'], quote.unitPrice);
      controller.dispose();
    },
  );
  test(
    'invalid quantity or overflowing total never reaches queue or service',
    () async {
      final queue = MemoryOutbox();
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
      for (final quantity in [0, -1, 4294967296, 4294967295]) {
        await expectLater(
          controller.sendGift(quote, quantity: quantity),
          throwsFormatException,
        );
      }
      expect(queue.items, isEmpty);
      expect(calls, 0);
      controller.dispose();
    },
  );
  test(
    'invalid acknowledgement cannot discard a queued gift transfer',
    () async {
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
              'messageType': 'gift',
              'gift': {
                'transferId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                'amount': '999',
              },
            },
          },
        ),
      );
      await controller.sendGift(quote);
      expect(queue.items.length, 1);
      expect(controller.messages.single['status'], 'failed');
      controller.dispose();
    },
  );
  test('queue write failure prevents gift send', () async {
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
    await expectLater(controller.sendGift(quote), throwsStateError);
    expect(calls, 0);
    expect(controller.messages, isEmpty);
    controller.dispose();
  });
}
