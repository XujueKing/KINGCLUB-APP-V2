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
  );
  final String messageId, sender, recipient, assetId, fileName, sha256;
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
  }) async {
    final data = await repository.peerFileAuthority(messageId, peer);
    final expiry = DateTime.tryParse(
      data['expiresAt'] is String ? data['expiresAt'] : '',
    );
    final now = DateTime.now().toUtc();
    if (!_uuid.hasMatch(messageId) ||
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
    );
  }

  bool sameFile(PeerFileAuthority other) =>
      messageId == other.messageId &&
      sender == other.sender &&
      recipient == other.recipient &&
      assetId == other.assetId &&
      fileName == other.fileName &&
      size == other.size &&
      sha256 == other.sha256;
  bool get valid => expiresAt.isAfter(DateTime.now().toUtc());
}
