import 'chat_coin.dart';

/// A catalog quote is consent to a price, not authority to debit an account.
class ChatGiftQuote {
  const ChatGiftQuote._(this.giftId, this.name, this.assetKey, this.unitPrice);
  final String giftId, name, assetKey, unitPrice;

  static ChatGiftQuote? tryParse(Object? value) {
    if (value is! Map) return null;
    final id = value['giftId'], name = value['name'];
    final asset = value['assetKey'], price = value['unitPrice'];
    final identifier = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
    if (id is! String ||
        !identifier.hasMatch(id) ||
        asset is! String ||
        !identifier.hasMatch(asset) ||
        name is! String ||
        name.isEmpty ||
        name.runes.length > 100 ||
        !ChatCoin.validAmount(price)) {
      return null;
    }
    return ChatGiftQuote._(id, name, asset, price as String);
  }

  String totalFor(int quantity) {
    if (quantity < 1 || quantity > 4294967295) {
      throw const FormatException('请输入有效的礼物数量');
    }
    final total = (BigInt.parse(unitPrice) * BigInt.from(quantity)).toString();
    if (!ChatCoin.validAmount(total)) {
      throw const FormatException('礼物总额超过上限');
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
    'giftId': giftId,
    'name': name,
    'assetKey': assetKey,
    'unitPrice': unitPrice,
  };
}

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
