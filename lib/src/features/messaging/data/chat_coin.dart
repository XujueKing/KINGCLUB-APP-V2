/// Exact integer coin quantities stay strings across API, queue and disk.
class ChatCoin {
  const ChatCoin._(this.transferId, this.amount);
  final String transferId;
  final String amount;
  static bool validAmount(Object? value) =>
      value is String &&
      RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(value) &&
      BigInt.parse(value) <= BigInt.parse('18446744073709551615');
  static ChatCoin? tryParse(Object? value, {String? messageId}) {
    if (value is! Map || !validAmount(value['amount'])) return null;
    final id = value['transferId'];
    if (id is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(id) ||
        (messageId != null && id != messageId)) {
      return null;
    }
    return ChatCoin._(id, value['amount'] as String);
  }

  Map<String, dynamic> toJson() => {'transferId': transferId, 'amount': amount};
}
