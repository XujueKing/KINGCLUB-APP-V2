import '../../../core/media/media_cache.dart';

import 'dart:convert';

import 'chat_download_cache.dart';
import 'chat_media_deletion.dart';
import 'chat_sent_file_cache.dart';

/// Deletes message-owned copies without clearing avatars or another account.
/// Transport cache aliases and exported files are handled separately.
class ChatMediaCleanup {
  ChatMediaCleanup({MediaCache? media, this.downloadCache, this.sentFileCache})
    : media = media ?? MediaCache.shared;
  final MediaCache media;
  final Future<ChatDownloadCache> Function(String account)? downloadCache;
  final Future<ChatDownloadCache> Function(String account)? sentFileCache;

  Future<void> remove({
    required String account,
    required bool group,
    required Map<String, dynamic> message,
    Set<String> retainedVoiceAssets = const {},
    Set<String> retainedFileAssets = const {},
    Set<String> retainedSentClients = const {},
  }) async {
    final messageId = message['messageId'];
    if (messageId is String && messageId.isNotEmpty) {
      await ChatMediaDeletion(account, group, messageId).dispatch();
    }
    if (message['messageType'] == 'voice') {
      if (messageId is String && messageId.isNotEmpty) {
        await media.removePermanently(
          scope: 'member:$account',
          contentKey: 'chat-voice-transfer:$group:$messageId',
          kind: MediaKind.audio,
        );
      }
      final asset = message['voiceAssetId'];
      if (asset is String &&
          asset.isNotEmpty &&
          !retainedVoiceAssets.contains(asset)) {
        // Asset copies can be shared by different messages. Unlike a message
        // tombstone, eviction permits a future new authorized use of the asset.
        await media.evict(
          scope: 'member:$account',
          contentKey: 'chat-voice-asset:$asset',
          kind: MediaKind.audio,
        );
      }
      return;
    }
    if (message['messageType'] == 'file') {
      final cache = await (downloadCache ?? ChatDownloadCache.open)(account);
      await cache.removePermanently(
        jsonEncode([
          account,
          group,
          message['messageId'],
          message['fileAssetId'],
          message['fileSize'],
          message['fileSha256'],
          message['fileName'],
        ]),
      );
      final asset = message['fileAssetId'],
          size = message['fileSize'],
          hash = message['fileSha256'];
      // A retained source belongs to this account, not to the sender of the
      // final reference (which may be a received copy of the same asset).
      if (asset is String &&
          size is int &&
          hash is String &&
          !retainedFileAssets.contains(asset)) {
        final sent = await (sentFileCache ?? ChatDownloadCache.openSentFiles)(
          account,
        );
        await ChatSentFileCache(
          cache: sent,
          checkSession: () async {},
        ).remove(assetId: asset, size: size, sha256: hash);
      }
      return;
    }
    if (!const {'image', 'video'}.contains(message['messageType'])) return;
    final id = message['messageId'];
    final client = message['clientMessageId'];
    final keys = <String, MediaKind>{};
    if (id is String && id.isNotEmpty) {
      keys['chat-image-message:$group:$id:image'] = MediaKind.image;
      keys['chat-image-message:$group:$id:thumbnail'] = MediaKind.image;
      keys['chat-image-transfer:$group:$id:image'] = MediaKind.image;
      keys['chat-video-message:$group:$id:video'] = MediaKind.video;
      keys['chat-video-message:$group:$id:poster'] = MediaKind.image;
      keys['chat-video-transfer:$group:$id:video'] = MediaKind.video;
      keys['chat-video-transfer:$group:$id:poster'] = MediaKind.image;
      keys['chat-video-forward:$group:$id:video'] = MediaKind.video;
    }
    if (message['sender'] == account &&
        client is String &&
        client.isNotEmpty &&
        !retainedSentClients.contains(client)) {
      keys['chat-image-sent:$client'] = MediaKind.image;
      keys['chat-video-sent:$client'] = MediaKind.video;
    }
    for (final entry in keys.entries) {
      await media.removePermanently(
        scope: 'member:$account',
        contentKey: entry.key,
        kind: entry.value,
      );
    }
  }
}
