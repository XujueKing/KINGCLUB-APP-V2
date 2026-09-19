import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/media/media_cache.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'chat_file_downloader.dart';
import 'messaging_repository.dart';

/// Installs on the shared media store so playback, previews and prefetch use
/// the same transfer path, while the store retains ownership of deletion.
class ChatMediaTransfer {
  static void install(MessagingRepository repository) {
    MediaCache.shared.transfer =
        ({
          required url,
          required scope,
          required destination,
          required resumeDirectory,
          required cancel,
        }) => download(
          repository,
          url: url,
          scope: scope,
          destination: destination,
          resumeDirectory: resumeDirectory,
          cancel: cancel,
        );
  }

  static Future<bool> download(
    MessagingRepository repository, {
    required String url,
    required String scope,
    required File destination,
    required Directory resumeDirectory,
    required CancelToken cancel,
    Future<ChatFileDownloader> Function(Directory)? openDownloader,
    String baseUrl = kingclubApiBaseUrl,
  }) async {
    void checkCancellation() {
      if (cancel.isCancelled) throw cancel.cancelError!;
    }

    final base = Uri.parse(baseUrl), uri = Uri.parse(url);
    if (!base.hasAuthority || base.scheme != 'https') return false;
    if (scope != 'member:${repository.account}' ||
        uri.origin != base.origin ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    final prefix = base.path.replaceFirst(RegExp(r'/+$'), '');
    if (!uri.path.startsWith('$prefix/kingclub/')) return false;
    final match = RegExp(
      r'^/kingclub/(group-)?chat-(image|voice|video)/([0-9a-fA-F-]{36})(?:/(image|thumbnail|video|hevc))?$',
    ).firstMatch(uri.path.substring(prefix.length));
    if (match == null) return false;
    final group = match[1] != null, type = match[2]!, id = match[3]!;
    final slot = match[4];
    if ((type == 'voice' && slot != null) ||
        (type == 'image' && slot != 'image' && slot != 'thumbnail') ||
        (type == 'video' &&
            slot != 'video' &&
            slot != 'hevc' &&
            slot != 'thumbnail')) {
      return false;
    }
    checkCancellation();
    final result = type == 'image'
        ? await repository.imageMedia(id, group: group)
        : type == 'voice'
        ? await repository.voiceMedia(id, group: group)
        : await repository.videoMedia(
            id,
            group: group,
            preferHevc: slot == 'hevc',
          );
    checkCancellation();
    final media = slot == 'thumbnail'
        ? '$type-thumbnail'
        : slot == 'hevc'
        ? 'hevc'
        : type;
    final raw = result[slot == 'thumbnail' ? 'thumbnail' : type];
    // Older deployed services have no immutable manifest. Preserve their
    // authorized HTTP path until the server upgrade is present.
    if (raw is! Map ||
        !raw.containsKey('sha256') ||
        !result.containsKey('assetId')) {
      return false;
    }
    final asset = result['assetId'],
        sender = result['sender'],
        fileId = raw['fileId'];
    if (result['messageId'] != id ||
        asset is! String ||
        sender is! String ||
        fileId is! String ||
        raw['size'] is! int ||
        raw['sha256'] is! String ||
        raw['path'] != uri.path.substring(prefix.length)) {
      throw const FormatException('Invalid media transfer manifest');
    }
    final extension = type == 'voice'
        ? 'm4a'
        : type == 'image'
        ? 'webp'
        : slot == 'thumbnail'
        ? 'jpg'
        : 'mp4';
    final reference = ChatFileReference(
      messageId: id,
      assetId: asset,
      fileId: fileId,
      media: media,
      sender: sender,
      group: group,
      fileName: '$fileId.$extension',
      size: raw['size'] as int,
      sha256: raw['sha256'] as String,
    );
    final downloader =
        await (openDownloader?.call(resumeDirectory) ??
            ChatFileDownloader.open(
              repository,
              mediaResumeDirectory: resumeDirectory,
            ));
    var finished = false;
    unawaited(
      cancel.whenCancel.then((_) {
        if (!finished) downloader.cancel();
      }),
    );
    try {
      checkCancellation();
      final file = await downloader.download(reference);
      checkCancellation();
      await file.copy(destination.path);
      checkCancellation();
      return true;
    } finally {
      finished = true;
      await downloader.dispose();
    }
  }
}
