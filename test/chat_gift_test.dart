import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_gift.dart';
import 'package:kingclub/src/features/messaging/data/chat_message_receipt.dart';

void main() {
  const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  final gift = <String, dynamic>{
    'transferId': id,
    'giftId': 'rose',
    'name': '玫瑰',
    'assetKey': 'rose',
    'unitPrice': '9007199254740993',
    'quantity': 2,
    'total': '18014398509481986',
  };
  test('snapshot preserves exact large amounts and discards extra fields', () {
    expect(
      ChatGift.tryParse({...gift, 'url': 'untrusted'}, messageId: id)!.toJson(),
      gift,
    );
    expect(ChatGift.tryParse(gift, messageId: 'another'), isNull);
  });
  test(
    'rejects inconsistent totals, types, quantity and unsafe asset paths',
    () {
      for (final mutation in <Map<String, dynamic>>[
        {'total': '18014398509481985'},
        {'unitPrice': 50},
        {'quantity': 0},
        {'quantity': 4294967296},
        {'quantity': 1.5},
        {'assetKey': '../rose'},
        {'name': ''},
        {'unitPrice': '18446744073709551615', 'total': '36893488147419103230'},
      ]) {
        expect(
          ChatGift.tryParse({...gift, ...mutation}),
          isNull,
          reason: '$mutation',
        );
      }
    },
  );
  test(
    'receipt requires confirmed gift, quantity and price before dequeue',
    () {
      final pending = <String, dynamic>{
        'messageType': 'gift',
        'giftId': 'rose',
        'quantity': 2,
        'expectedUnitPrice': '9007199254740993',
      };
      final received = <String, dynamic>{
        'messageType': 'gift',
        'messageId': id,
        'gift': gift,
      };
      expect(
        () => validateQueuedMessageReceipt(pending, received),
        returnsNormally,
      );
      for (final mutation in <Map<String, dynamic>>[
        {'giftId': 'another'},
        {'quantity': 1},
        {'expectedUnitPrice': '50'},
      ]) {
        expect(
          () =>
              validateQueuedMessageReceipt({...pending, ...mutation}, received),
          throwsFormatException,
        );
      }
      expect(
        () =>
            validateQueuedMessageReceipt(pending, {...received, 'gift': null}),
        throwsFormatException,
      );
      expect(
        () => validateQueuedMessageReceipt(pending, {'messageType': 'hidden'}),
        returnsNormally,
      );
    },
  );
}
