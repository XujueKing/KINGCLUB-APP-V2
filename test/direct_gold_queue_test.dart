import 'package:kingclub/src/features/messaging/data/chat_coin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, history;

void main() {
  test(
    'coin amount and receipt reject numeric rounding and mismatched identity',
    () {
      expect(ChatCoin.validAmount('18446744073709551615'), isTrue);
      for (final value in [
        0,
        1,
        '0',
        '-1',
        '01',
        '1.5',
        '18446744073709551616',
      ]) {
        expect(ChatCoin.validAmount(value), isFalse);
      }
      expect(
        ChatCoin.tryParse({
          'transferId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          'amount': '1',
        }, messageId: 'other'),
        isNull,
      );
    },
  );
  test('gold network retry survives controller recreation and uses gold endpoint only', () async {
    final queue = MemoryOutbox(), requests = <Map<String, dynamic>>[];
    final repo = MessagingRepository(
      account: 'me',
      call: (id, params) async {
        if (id == 'K260913000604') return history([]);
        expect(id, 'K260927000801');
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
            'messageType': 'gold',
            'coin': {
              'transferId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              'amount': params['amount'],
            },
            'text': '[金币]',
          },
        };
      },
    );
    final first = DirectChatController(
      repository: repo,
      peer: 'peer',
      outbox: queue,
    );
    await first.sendGold('9007199254740993');
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
    expect(requests[1]['amount'], '9007199254740993');
    expect(queue.items, isEmpty);
    expect(restored.messages.single['messageType'], 'gold');
    restored.dispose();
  });
  test(
    'invalid acknowledgement cannot discard a queued gold transfer',
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
              'messageType': 'gold',
              'coin': {
                'transferId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                'amount': '999',
              },
            },
          },
        ),
      );
      await controller.sendGold('20');
      expect(queue.items.length, 1);
      expect(controller.messages.single['status'], 'failed');
      controller.dispose();
    },
  );
  test('queue write failure prevents gold send', () async {
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
    await expectLater(controller.sendGold('20'), throwsStateError);
    expect(calls, 0);
    expect(controller.messages, isEmpty);
    controller.dispose();
  });
}
