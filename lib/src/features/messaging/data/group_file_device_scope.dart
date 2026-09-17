/// A live service grant for one file, not permission to send private messages.
class GroupFileDeviceScope {
  GroupFileDeviceScope._(
    this.messageId,
    this.groupId,
    this.sender,
    this.recipient,
    this.senderVersion,
    this.recipientVersion,
  );
  final String messageId, groupId, sender, recipient;
  final int senderVersion, recipientVersion;
  static final _uuid = RegExp(r'^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$');

  static GroupFileDeviceScope parse(
    Object? raw, {
    required String messageId,
    required String groupId,
    required String account,
    required String peer,
  }) {
    bool version(Object? value) =>
        value is int && value >= 0 && value <= 4294967295;
    if (raw is! Map ||
        !_uuid.hasMatch(messageId) ||
        !_uuid.hasMatch(groupId) ||
        account == peer ||
        raw['kind'] != 'group-file' ||
        raw['messageId'] != messageId ||
        raw['groupId'] != groupId ||
        !((raw['sender'] == account && raw['recipient'] == peer) ||
            (raw['sender'] == peer && raw['recipient'] == account)) ||
        !version(raw['senderMembershipVersion']) ||
        !version(raw['recipientMembershipVersion'])) {
      throw const FormatException('Invalid group file device scope');
    }
    return GroupFileDeviceScope._(
      messageId,
      groupId,
      raw['sender'],
      raw['recipient'],
      raw['senderMembershipVersion'],
      raw['recipientMembershipVersion'],
    );
  }

  bool samePermission(GroupFileDeviceScope other) =>
      messageId == other.messageId &&
      groupId == other.groupId &&
      sender == other.sender &&
      recipient == other.recipient &&
      senderVersion == other.senderVersion &&
      recipientVersion == other.recipientVersion;
}
