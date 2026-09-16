import '../../../core/media/media_cache.dart';

import 'dart:convert';

import 'chat_download_cache.dart';

/// Deletes message-owned copies without clearing avatars or another account.
/// Transport cache aliases and exported files are handled separately.
class ChatMediaCleanup {
  ChatMediaCleanup({MediaCache? media, this.downloadCache})
    : media = media ?? MediaCache.shared;
  final MediaCache media;
  final Future<ChatDownloadCache> Function(String account)? downloadCache;

  Future<void> remove({
    required String account,
    required bool group,
    required Map<String, dynamic> message,
  }) async {
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
      return;
    }
    if (!const {'image', 'video'}.contains(message['messageType'])) return;
    final id = message['messageId'];
    final client = message['clientMessageId'];
    final keys = <String, MediaKind>{};
    if (id is String && id.isNotEmpty) {
      keys['chat-image-message:$group:$id:image'] = MediaKind.image;
      keys['chat-image-message:$group:$id:thumbnail'] = MediaKind.image;
      keys['chat-video-message:$group:$id:video'] = MediaKind.video;
      keys['chat-video-message:$group:$id:poster'] = MediaKind.image;
    }
    if (message['sender'] == account && client is String && client.isNotEmpty) {
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
