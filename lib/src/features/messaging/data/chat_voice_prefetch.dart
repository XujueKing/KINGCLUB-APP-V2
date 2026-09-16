import 'dart:async';

import '../../../core/media/media_cache.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'messaging_repository.dart';

/// Retains recent received voice messages without opening an audio device.
/// One transfer at a time; failures remain retryable on a later history update.
class ChatVoicePrefetch {
  ChatVoicePrefetch(this.repository, {required this.group, MediaCache? media})
    : _media = media ?? MediaCache.shared {
    _session = SecureSessionStore.changes.stream.listen((_) => dispose());
  }
  final MessagingRepository repository;
  final bool group;
  final MediaCache _media;
  StreamSubscription<void>? _session;
  final _pending = <String, String>{};
  final _retryAfter = <String, DateTime>{};
  bool _disposed = false, _running = false;
  String? _active;
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  void update(List<Map<String, dynamic>> messages) {
    if (_disposed) return;
    final recent = <String, String>{};
    for (final message in messages.reversed.take(50)) {
      final id = message['messageId'], asset = message['voiceAssetId'];
      if (message['messageType'] == 'voice' &&
          message['sender'] != repository.account &&
          id is String &&
          _uuid.hasMatch(id) &&
          asset is String &&
          _uuid.hasMatch(asset)) {
        recent[id] = asset;
      }
    }
    _pending.removeWhere((id, _) => !recent.containsKey(id));
    _retryAfter.removeWhere((id, _) => !recent.containsKey(id));
    for (final entry in recent.entries) {
      if (entry.key != _active &&
          !(_retryAfter[entry.key]?.isAfter(DateTime.now()) ?? false)) {
        _pending[entry.key] = entry.value;
      }
    }
    unawaited(_drain());
  }

  Map<String, dynamic> _grant(Map<String, dynamic> result, String id) {
    final voice = result['voice'];
    if (result['messageId'] != id || voice is! Map) {
      throw const FormatException('Invalid voice grant');
    }
    final media = Map<String, dynamic>.from(voice);
    final file = media['fileId'], duration = media['durationMs'];
    final token = (media['headers'] as Map?)?['authorization'];
    if (media['path'] !=
            '/kingclub/${group ? 'group-chat-voice' : 'chat-voice'}/$id' ||
        file is! String ||
        !_uuid.hasMatch(file) ||
        duration is! int ||
        duration < 1000 ||
        duration > 60500 ||
        media['contentType'] != 'audio/mp4' ||
        token is! String ||
        !token.startsWith('Bearer ')) {
      throw const FormatException('Invalid voice grant');
    }
    return media;
  }

  Future<void> _drain() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      while (!_disposed && _pending.isNotEmpty) {
        final entry = _pending.entries.first;
        _pending.remove(entry.key);
        _active = entry.key;
        try {
          await _retain(entry.key, entry.value);
        } catch (_) {
          if (!_disposed) {
            _retryAfter[entry.key] = DateTime.now().add(
              const Duration(seconds: 30),
            );
          }
        } finally {
          _active = null;
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _retain(String id, String asset) async {
    final scope = 'member:${repository.account}',
        key = 'chat-voice-asset:$asset';
    try {
      await _media.cached(scope: scope, contentKey: key, kind: MediaKind.audio);
      return;
    } catch (_) {}
    if (_disposed) return;
    final grant = _grant(await repository.voiceMedia(id, group: group), id);
    if (_disposed) return;
    final file = await _media.get(
      '${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}${grant['path']}',
      scope: scope,
      contentKey: 'chat-voice:${repository.account}:${grant['fileId']}',
      kind: MediaKind.audio,
      headers: {
        'authorization': (grant['headers'] as Map)['authorization'] as String,
      },
    );
    if (_disposed) return;
    // Do not publish a local asset mapping using authority captured before a
    // potentially slow download (removal/hide may have happened meanwhile).
    final fresh = _grant(await repository.voiceMedia(id, group: group), id);
    if (_disposed || fresh['fileId'] != grant['fileId']) return;
    await _media.importFile(
      file,
      scope: scope,
      contentKey: key,
      kind: MediaKind.audio,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    _retryAfter.clear();
    _session?.cancel();
  }
}
