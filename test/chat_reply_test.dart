import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_reply.dart';

void main() {
  const id = '11111111-1111-4111-8111-111111111111';
  test('unavailable replies never display stale text or navigate', () {
    final reply = ChatReply.tryParse({
      'messageId': id,
      'available': false,
      'text': 'private',
      'sequence': 1,
    })!;
    expect(reply.available, false);
    expect(reply.text, '原消息不可用');
  });
  test('invalid or oversized references cannot navigate', () {
    expect(ChatReply.tryParse({'messageId': 'bad'}), null);
    for (final seq in [null, 0, -1, 4294967296, '1']) {
      expect(
        ChatReply.tryParse({
          'messageId': id,
          'available': true,
          'sequence': seq,
          'text': 'x',
        })!.available,
        false,
      );
    }
    expect(
      ChatReply.tryParse({
        'messageId': id,
        'available': true,
        'sequence': 1,
        'text': '😀' * 201,
      })!.available,
      false,
    );
    expect(
      ChatReply.tryParse({
        'messageId': id,
        'available': true,
        'sequence': 1,
        'text': '😀' * 200,
      })!.available,
      true,
    );
  });
}
