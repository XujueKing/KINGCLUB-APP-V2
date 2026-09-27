import 'chat_coin.dart';
import 'chat_gift.dart';

/// History labels describe committed transfers; they never initiate a transfer.
String chatHistoryLabel(Map<String, dynamic> message) {
  final id = message['messageId'];
  switch (message['messageType']) {
    case 'gift':
      final gift = id is String
          ? ChatGift.tryParse(message['gift'], messageId: id)
          : null;
      return gift == null
          ? '[礼物]'
          : '[礼物] ${gift.name} × ${gift.quantity} · ${gift.total} 金币';
    case 'gold':
      final coin = id is String
          ? ChatCoin.tryParse(message['coin'], messageId: id)
          : null;
      return coin == null ? '[金币]' : '[金币] ${coin.amount} 枚';
    case 'hidden':
      return '消息已删除';
    case 'recalled':
      return '消息已撤回';
    case 'file':
      return message['fileName'] as String? ??
          message['text'] as String? ??
          '[文件]';
    default:
      return message['text'] as String? ?? '';
  }
}
