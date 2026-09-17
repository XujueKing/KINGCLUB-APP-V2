import 'dart:async';

import 'package:cryptography/dart.dart';

import 'chat_video_grant.dart';

import '../../../core/media/media_cache.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'messaging_repository.dart';
import 'chat_media_deletion.dart';

/// Backfills recent sent videos without opening a player or blocking the UI.
/// One transfer at a time; failures remain retryable on a later history update.
class ChatVideoPrefetch {
  ChatVideoPrefetch(this.repository, {required this.group, MediaCache? media})
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
          contentKey: 'chat-video-transfer:$group:${event.messageId}:video',
          kind: MediaKind.video,
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
      final id = message['messageId'], asset = message['clientMessageId'];
      if (message['messageType'] == 'video' &&
          message['sender'] == repository.account &&
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

  Future<ChatVideoGrant> _grant(String id) async => ChatVideoGrant.parse(
    await repository.videoMedia(id, group: group),
    id,
    group: group,
    full: true,
  );

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

  Future<void> _retain(String id, String client) async {
    bool stopped() => _disposed || _deleted.contains(id);
    if (stopped()) return;
    final scope = 'member:${repository.account}';
    final key = 'chat-video-message:$group:$id:video';
    for (final localKey in [key, 'chat-video-sent:$client']) {
      try {
        await _media.cached(
          scope: scope,
          contentKey: localKey,
          kind: MediaKind.video,
        );
        return;
      } catch (_) {}
    }
    if (stopped()) return;
    final grant = await _grant(id);
    if (stopped()) return;
    final file = await _media.get(
      '${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}${grant.path}',
      scope: scope,
      contentKey: 'chat-video-transfer:$group:$id:video',
      kind: MediaKind.video,
      headers: {'authorization': grant.authorization},
    );
    if (stopped()) return;
    Future<void> discardTransfer() => _media.evict(
      scope: scope,
      contentKey: 'chat-video-transfer:$group:$id:video',
      kind: MediaKind.video,
    );
    if (await file.length() != grant.size) {
      await discardTransfer();
      throw const FormatException('Incomplete video');
    }
    final hash = const DartSha256().newHashSink();
    await for (final bytes in file.openRead()) {
      if (stopped()) {
        hash.close();
        return;
      }
      hash.add(bytes);
    }
    hash.close();
    final digest = (await hash.hash()).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    if (digest != grant.sha256) {
      await discardTransfer();
      throw const FormatException('Invalid video hash');
    }
    final fresh = await _grant(id);
    if (stopped() ||
        fresh.fileId != grant.fileId ||
        fresh.sha256 != grant.sha256 ||
        fresh.size != grant.size) {
      return;
    }
    await _media.importFile(
      file,
      scope: scope,
      contentKey: key,
      kind: MediaKind.video,
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
