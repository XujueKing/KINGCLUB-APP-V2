import 'dart:io';

import 'package:cryptography/dart.dart';

import '../../../core/media/media_cache.dart';
import 'peer_file_authority.dart';

/// Local-only lookup. Authority is still renewed by PeerFileChannel before send.
Future<File?> readPeerMediaSource(
  PeerFileAuthority authority, {
  required String account,
  required bool Function() active,
  MediaCache? cache,
}) async {
  bool usable() => active() && authority.valid && authority.sender == account;
  if (!usable()) return null;
  final group = authority.groupId != null,
      id = authority.messageId,
      client = authority.clientMessageId;
  final (kind, key) = switch (authority.media) {
    'image' => (MediaKind.image, 'chat-image-message:$group:$id:image'),
    'image-thumbnail' => (
      MediaKind.image,
      'chat-image-message:$group:$id:thumbnail',
    ),
    'voice' => (MediaKind.audio, 'chat-voice-asset:${authority.assetId}'),
    'video' ||
    'hevc' => (MediaKind.video, 'chat-video-message:$group:$id:video'),
    'video-thumbnail' => (
      MediaKind.image,
      'chat-video-message:$group:$id:poster',
    ),
    _ => throw const FormatException('Unsupported media source'),
  };
  final keys = [
    key,
    if (client != null && authority.media == 'image') 'chat-image-sent:$client',
    if (client != null &&
        (authority.media == 'video' || authority.media == 'hevc'))
      'chat-video-sent:$client',
  ];
  for (final candidate in keys) {
    if (!usable()) return null;
    try {
      final file = await (cache ?? MediaCache.shared).cached(
        scope: 'member:$account',
        contentKey: candidate,
        kind: kind,
      );
      if (!usable()) return null;
      if (await file.length() != authority.size) continue;
      final sink = const DartSha256().newHashSink();
      await for (final bytes in file.openRead()) {
        if (!usable()) {
          sink.close();
          return null;
        }
        sink.add(bytes);
      }
      sink.close();
      final digest = (await sink.hash()).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (!usable()) return null;
      if (digest == authority.sha256) return file;
    } on StateError {
      // Missing or deleted candidate is not a reason to fetch from the server.
    } on FileSystemException {
      // Local deletion may race with the read; try the other retained key.
    }
  }
  return null;
}
