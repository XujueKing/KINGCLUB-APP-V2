import 'messaging_repository.dart';

/// Parsed exclusively from this device's authenticated service response.
class PeerFileAuthority {
  PeerFileAuthority._(
    this.messageId,
    this.sender,
    this.recipient,
    this.assetId,
    this.fileName,
    this.size,
    this.sha256,
    this.expiresAt,
    this.groupId,
    this.senderMembershipVersion,
    this.recipientMembershipVersion,
    this.media,
    this.fileId,
    this.clientMessageId,
  );
  final String messageId, sender, recipient, assetId, fileName, sha256;
  final String? groupId;
  final String? media, fileId, clientMessageId;
  static const mediaKinds = {
    'image',
    'image-thumbnail',
    'voice',
    'video',
    'video-thumbnail',
    'hevc',
  };
  final int? senderMembershipVersion, recipientMembershipVersion;
  final int size;
  final DateTime expiresAt;
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static Future<PeerFileAuthority> read(
    MessagingRepository repository,
    String peer,
    String messageId, {
    required bool sending,
    String? groupId,
    bool group = false,
    String? media,
  }) async {
    if (media != null && !mediaKinds.contains(media)) {
      throw const FormatException('Invalid peer media kind');
    }
    if (groupId != null && !_uuid.hasMatch(groupId)) {
      throw const FormatException('Invalid peer file group');
    }
    final data = await repository.peerFileAuthority(
      messageId,
      peer,
      group: group || groupId != null,
      media: media,
    );
    if (group && groupId == null) {
      final actualGroup = data['groupId'];
      if (actualGroup is! String || !_uuid.hasMatch(actualGroup)) {
        throw const FormatException('Missing peer file group');
      }
      groupId = actualGroup;
    }
    final senderVersion = data['senderMembershipVersion'];
    final recipientVersion = data['recipientMembershipVersion'];
    final validScope = groupId == null
        ? !data.containsKey('groupId') &&
              !data.containsKey('senderMembershipVersion') &&
              !data.containsKey('recipientMembershipVersion')
        : data['groupId'] == groupId &&
              _validMembershipVersion(senderVersion) &&
              _validMembershipVersion(recipientVersion);
    final expiry = DateTime.tryParse(
      data['expiresAt'] is String ? data['expiresAt'] : '',
    );
    final now = DateTime.now().toUtc();
    final validMedia = media == null
        ? !data.containsKey('media') && !data.containsKey('fileId')
        : data['media'] == media &&
              data['fileId'] is String &&
              _uuid.hasMatch(data['fileId']);
    if ((data.containsKey('clientMessageId') &&
            (media == null ||
                data['clientMessageId'] is! String ||
                !_uuid.hasMatch(data['clientMessageId']))) ||
        !validScope ||
        !validMedia ||
        !_uuid.hasMatch(messageId) ||
        data['messageId'] != messageId ||
        data['sender'] != (sending ? repository.account : peer) ||
        data['recipient'] != (sending ? peer : repository.account) ||
        peer == repository.account ||
        data['assetId'] is! String ||
        !_uuid.hasMatch(data['assetId']) ||
        data['fileName'] is! String ||
        (data['fileName'] as String).isEmpty ||
        (data['fileName'] as String).length > 180 ||
        data['size'] is! int ||
        data['size'] < 0 ||
        data['size'] > 268435456 ||
        data['sha256'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(data['sha256']) ||
        expiry == null ||
        !expiry.isAfter(now) ||
        expiry.isAfter(now.add(const Duration(seconds: 17)))) {
      throw const FormatException('Invalid peer file authority');
    }
    return PeerFileAuthority._(
      messageId,
      data['sender'],
      data['recipient'],
      data['assetId'],
      data['fileName'],
      data['size'],
      data['sha256'],
      expiry,
      groupId,
      senderVersion as int?,
      recipientVersion as int?,
      media,
      data['fileId'] as String?,
      data['clientMessageId'] as String?,
    );
  }

  static bool _validMembershipVersion(Object? value) =>
      value is int && value >= 0 && value <= 4294967295;

  bool sameFile(PeerFileAuthority other) =>
      clientMessageId == other.clientMessageId &&
      media == other.media &&
      fileId == other.fileId &&
      groupId == other.groupId &&
      senderMembershipVersion == other.senderMembershipVersion &&
      recipientMembershipVersion == other.recipientMembershipVersion &&
      messageId == other.messageId &&
      sender == other.sender &&
      recipient == other.recipient &&
      assetId == other.assetId &&
      fileName == other.fileName &&
      size == other.size &&
      sha256 == other.sha256;
  bool get valid => expiresAt.isAfter(DateTime.now().toUtc());
}
