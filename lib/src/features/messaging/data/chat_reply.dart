class ChatReply {
  const ChatReply._(this.messageId, this.sequence, this.text);
  final String messageId;
  final int? sequence;
  final String text;
  bool get available => sequence != null;
  static ChatReply? tryParse(Object? value) {
    if (value is! Map) return null;
    final id = value['messageId'];
    if (id is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(id)) {
      return null;
    }
    if (value['available'] != true) return ChatReply._(id, null, '原消息不可用');
    final sequence = value['sequence'], text = value['text'];
    if (sequence is! int ||
        sequence < 1 ||
        sequence > 4294967295 ||
        text is! String ||
        text.runes.length > 200) {
      return ChatReply._(id, null, '原消息不可用');
    }
    return ChatReply._(id, sequence, text);
  }
}
