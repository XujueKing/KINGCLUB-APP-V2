import 'dart:async';

import '../../../core/media/media_cache.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'chat_media_deletion.dart';
import 'messaging_repository.dart';

/// Serial background retention of recent message images, without decoding them.
class ChatImagePrefetch {
  ChatImagePrefetch(this.repository, {required this.group, MediaCache? media})
    : _media = media ?? MediaCache.shared {
    _session = SecureSessionStore.changes.stream.listen((_) => dispose());
    _removeListener = ChatMediaDeletion.listen((event) async {
      if (event.account != repository.account || event.group != group) return;
      _deleted.add(event.messageId);
      _pending.remove(event.messageId);
      _retryAfter.remove(event.messageId);
      if (_active == event.messageId) {
        await _media.cancelForDeletion(
          scope: _scope,
          contentKey: _transferKey(event.messageId),
          kind: MediaKind.image,
        );
        await _activeDone?.future;
      }
    });
  }
  final MessagingRepository repository;
  final bool group;
  final MediaCache _media;
  late final void Function() _removeListener;
  StreamSubscription<void>? _session;
  final _pending = <String, String?>{};
  final _deleted = <String>{};
  final _retryAfter = <String, DateTime>{};
  Map<String, String?> _recent = {};
  int _retryRevision = 0;
  bool _disposed = false, _running = false;
  String? _active;
  Completer<void>? _activeDone;
  Future<void> _work = Future.value();
  Future<void> get idle => _work;
  bool get hasFailures => _retryAfter.isNotEmpty;
  String get _scope => 'member:${repository.account}';
  String _transferKey(String id) => 'chat-image-transfer:$group:$id:image';
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
    final recent = <String, String?>{};
    for (final row in messages.reversed.take(50)) {
      final id = row['messageId'], client = row['clientMessageId'];
      if (row['messageType'] != 'image' ||
          id is! String ||
          !_uuid.hasMatch(id) ||
          _deleted.contains(id)) {
        continue;
      }
      recent[id] =
          row['sender'] == repository.account &&
              client is String &&
              _uuid.hasMatch(client)
          ? client
          : null;
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

  Future<Map<String, dynamic>> _grant(String id) async {
    final result = await repository.imageMedia(id, group: group);
    final image = result['image'];
    if (result['messageId'] != id ||
        image is! Map ||
        image['path'] !=
            '/kingclub/${group ? 'group-chat-image' : 'chat-image'}/$id/image' ||
        image['fileId'] is! String ||
        !_uuid.hasMatch(image['fileId'] as String) ||
        image['width'] is! int ||
        image['height'] is! int ||
        (image['width'] as int) < 1 ||
        (image['width'] as int) > 2560 ||
        (image['height'] as int) < 1 ||
        (image['height'] as int) > 2560 ||
        (image['headers'] as Map?)?['authorization'] is! String ||
        !((image['headers'] as Map)['authorization'] as String).startsWith(
          'Bearer ',
        )) {
      throw const FormatException('Invalid image grant');
    }
    return Map<String, dynamic>.from(image);
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
              _pending[entry.key] = _recent[entry.key];
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

  Future<void> _retain(String id, String? client) async {
    bool stopped() => _disposed || _deleted.contains(id);
    final key = 'chat-image-message:$group:$id:image';
    for (final existing in [
      key,
      if (client != null) 'chat-image-sent:$client',
    ]) {
      try {
        await _media.cachedImage(scope: _scope, contentKey: existing);
        return;
      } catch (_) {}
    }
    if (stopped()) return;
    final grant = await _grant(id);
    if (stopped()) return;
    final file = await _media.get(
      '${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}${grant['path']}',
      scope: _scope,
      contentKey: _transferKey(id),
      kind: MediaKind.image,
      headers: {
        'authorization': (grant['headers'] as Map)['authorization'] as String,
      },
    );
    if (stopped()) return;
    final fresh = await _grant(id);
    if (stopped() || fresh['fileId'] != grant['fileId']) return;
    await _media.importFile(
      file,
      scope: _scope,
      contentKey: key,
      kind: MediaKind.image,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _removeListener();
    _session?.cancel();
    _pending.clear();
    _retryAfter.clear();
    _recent.clear();
  }
}
