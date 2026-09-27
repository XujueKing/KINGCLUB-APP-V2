import 'chat_coin.dart';

/// An immutable, exact-price snapshot of a server-confirmed gift transfer.
class ChatGift {
  const ChatGift._({
    required this.transferId,
    required this.giftId,
    required this.name,
    required this.assetKey,
    required this.unitPrice,
    required this.quantity,
    required this.total,
  });

  final String transferId, giftId, name, assetKey, unitPrice, total;
  final int quantity;

  static ChatGift? tryParse(Object? value, {String? messageId}) {
    if (value is! Map) return null;
    final total = value['total'];
    final transfer = ChatCoin.tryParse({
      'transferId': value['transferId'],
      'amount': total,
    }, messageId: messageId);
    final price = value['unitPrice'];
    final quantity = value['quantity'];
    final giftId = value['giftId'];
    final name = value['name'];
    final assetKey = value['assetKey'];
    final identifier = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
    if (transfer == null ||
        !ChatCoin.validAmount(price) ||
        quantity is! int ||
        quantity < 1 ||
        quantity > 4294967295 ||
        giftId is! String ||
        !identifier.hasMatch(giftId) ||
        assetKey is! String ||
        !identifier.hasMatch(assetKey) ||
        name is! String ||
        name.isEmpty ||
        name.runes.length > 100 ||
        BigInt.parse(price as String) * BigInt.from(quantity) !=
            BigInt.parse(total as String)) {
      return null;
    }
    return ChatGift._(
      transferId: transfer.transferId,
      giftId: giftId,
      name: name,
      assetKey: assetKey,
      unitPrice: price,
      quantity: quantity,
      total: total,
    );
  }

  Map<String, dynamic> toJson() => {
    'transferId': transferId,
    'giftId': giftId,
    'name': name,
    'assetKey': assetKey,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'total': total,
  };
}
