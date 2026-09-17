import 'dart:async';

import '../../../core/media/media_cache.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'messaging_repository.dart';
import 'chat_media_deletion.dart';

/// Retains recent voice messages without opening an audio device, including
/// sent messages whose local copy is missing after migration or device changes.
/// One transfer at a time; failures remain retryable on a later history update.
class ChatVoicePrefetch {
  ChatVoicePrefetch(this.repository, {required this.group, MediaCache? media})
    : _media = media ?? MediaCache.shared {
    _session = SecureSessionStore.changes.stream.listen((_) => dispose());
    _removeDeletionListener = ChatMediaDeletion.listen((event) async {
      if (event.account != repository.account || event.group != group) return;
      _deleted.add(event.messageId);
      _pending.remove(event.messageId);
      _retryAfter.remove(event.messageId);
      if (_active == event.messageId) {
        await _media.cancelForDeletion(
          scope: 'member:${repository.account}',
          contentKey: 'chat-voice-transfer:$group:${event.messageId}',
          kind: MediaKind.audio,
        );
        await _activeDone?.future;
      }
    });
  }
  final MessagingRepository repository;
  final bool group;
  final MediaCache _media;
  late final void Function() _removeDeletionListener;
  final _deleted = <String>{};
  StreamSubscription<void>? _session;
  final _pending = <String, String>{};
  final _retryAfter = <String, DateTime>{};
  Map<String, String> _recent = {};
  int _retryRevision = 0;
  bool _disposed = false, _running = false;
  String? _active;
  Completer<void>? _activeDone;
  Future<void> _work = Future.value();
  Future<void> get idle => _work;
  bool get hasFailures => _retryAfter.isNotEmpty;
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  void update(
    List<Map<String, dynamic>> messages, {
    bool retryFailures = false,
  }) {
    if (_disposed) return;
    if (retryFailures) {
      _retryRevision++;
      _retryAfter.clear();
    }
    final recent = <String, String>{};
    for (final message in messages.reversed.take(50)) {
      final id = message['messageId'], asset = message['voiceAssetId'];
      if (message['messageType'] == 'voice' &&
          id is String &&
          !_deleted.contains(id) &&
          _uuid.hasMatch(id) &&
          asset is String &&
          _uuid.hasMatch(asset)) {
        recent[id] = asset;
      }
    }
    _recent = recent;
    _pending.removeWhere((id, _) => !recent.containsKey(id));
    _retryAfter.removeWhere((id, _) => !recent.containsKey(id));
    for (final entry in recent.entries) {
      if (entry.key != _active &&
          !(_retryAfter[entry.key]?.isAfter(DateTime.now()) ?? false)) {
        _pending[entry.key] = entry.value;
      }
    }
    if (!_running) _work = _drain();
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
        _activeDone = Completer<void>();
        final revision = _retryRevision;
        try {
          await _retain(entry.key, entry.value);
          _retryAfter.remove(entry.key);
        } catch (_) {
          if (!_disposed &&
              !_deleted.contains(entry.key) &&
              _recent.containsKey(entry.key)) {
            if (revision != _retryRevision) {
              _pending[entry.key] = _recent[entry.key]!;
              continue;
            }
            _retryAfter[entry.key] = DateTime.now().add(
              const Duration(seconds: 30),
            );
          }
        } finally {
          _activeDone?.complete();
          _activeDone = null;
          _active = null;
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _retain(String id, String asset) async {
    bool stopped() => _disposed || _deleted.contains(id);
    if (stopped()) return;
    final scope = 'member:${repository.account}',
        key = 'chat-voice-asset:$asset';
    try {
      await _media.cached(scope: scope, contentKey: key, kind: MediaKind.audio);
      return;
    } catch (_) {}
    if (stopped()) return;
    final grant = _grant(await repository.voiceMedia(id, group: group), id);
    if (stopped()) return;
    final file = await _media.get(
      '${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}${grant['path']}',
      scope: scope,
      contentKey: 'chat-voice-transfer:$group:$id',
      kind: MediaKind.audio,
      headers: {
        'authorization': (grant['headers'] as Map)['authorization'] as String,
      },
    );
    if (stopped()) return;
    // Do not publish a local asset mapping using authority captured before a
    // potentially slow download (removal/hide may have happened meanwhile).
    final fresh = _grant(await repository.voiceMedia(id, group: group), id);
    if (stopped() || fresh['fileId'] != grant['fileId']) return;
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
    _removeDeletionListener();
    _pending.clear();
    _retryAfter.clear();
    _recent.clear();
    _session?.cancel();
  }
}
