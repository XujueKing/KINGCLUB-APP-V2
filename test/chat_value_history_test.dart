import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_label.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_history_context_page.dart';

void main() {
  const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  final gift = <String, dynamic>{
    'messageId': id,
    'messageType': 'gift',
    'text': '[礼物]',
    'sequence': 1,
    'sender': 'peer',
    'clientMessageId': id,
    'createdDate': '2026-09-27T00:00:00.000Z',
    'gift': {
      'transferId': id,
      'giftId': 'rose',
      'name': '玫瑰',
      'assetKey': 'rose',
      'unitPrice': '9007199254740993',
      'quantity': 2,
      'total': '18014398509481986',
    },
  };
  test(
    'history labels retain exact committed amount and hide removed payloads',
    () {
      expect(chatHistoryLabel(gift), '[礼物] 玫瑰 × 2 · 18014398509481986 金币');
      expect(chatHistoryLabel({...gift, 'messageId': 'mismatch'}), '[礼物]');
      expect(chatHistoryLabel({...gift, 'messageType': 'hidden'}), '消息已删除');
      expect(chatHistoryLabel({...gift, 'messageType': 'recalled'}), '消息已撤回');
      expect(
        chatHistoryLabel({
          'messageId': id,
          'messageType': 'gold',
          'coin': {'transferId': id, 'amount': '18446744073709551615'},
        }),
        '[金币] 18446744073709551615 枚',
      );
    },
  );
  testWidgets(
    'history context renders committed gift details without a send action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatHistoryContextPage(
            account: 'me',
            messageId: id,
            sequence: 1,
            read: ({before, after, required limit}) async => {
              'messages': before != null ? [gift] : [],
              'settings': {'hiddenThrough': 0},
              'historyVersion': 0,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('[礼物] 玫瑰 × 2 · 18014398509481986 金币'), findsOneWidget);
      expect(find.text('确认赠送'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
