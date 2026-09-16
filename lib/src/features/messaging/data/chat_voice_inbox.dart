import 'dart:async';

import '../../../core/media/media_cache.dart';
import '../../../core/session/secure_session_store.dart';
import 'chat_voice_prefetch.dart';
import 'group_chat_repository.dart';
import 'messaging_repository.dart';

/// Prefetch voice for changed unread conversations without opening their pages.
/// History queries and media transfers are serialized and never mark as read.
class ChatVoiceInbox {
  ChatVoiceInbox(this.repository, {this.media}) {
    _session = SecureSessionStore.changes.stream.listen((_) => dispose());
  }
  final MessagingRepository repository;
  final MediaCache? media;
  StreamSubscription<void>? _session;
  final _pending = <String, ({String target, bool group, int sequence})>{};
  final _completed = <String, int>{};
  final _retry = <String, DateTime>{};
  bool _disposed = false, _running = false;
  ChatVoicePrefetch? _worker;
  Future<void> _work = Future.value();
  Future<void> get idle => _work;

  void update(List<Map<String, dynamic>> conversations) {
    if (_disposed) return;
    final visible = <String>{};
    for (final row in conversations.take(50)) {
      final group = row['kind'] == 'group';
      final target = row[group ? 'groupId' : 'peer'];
      final sequence = row['lastSequence'];
      if (target is! String ||
          target.isEmpty ||
          sequence is! num ||
          row['localOnly'] == true) {
        continue;
      }
      final key = '$group:$target';
      visible.add(key);
      if ((row['unreadCount'] as num? ?? 0) <= 0) {
        _pending.remove(key);
        continue;
      }
      if (_completed[key] == sequence.toInt() ||
          (_retry[key]?.isAfter(DateTime.now()) ?? false)) {
        continue;
      }
      _pending[key] = (
        target: target,
        group: group,
        sequence: sequence.toInt(),
      );
    }
    _pending.removeWhere((key, _) => !visible.contains(key));
    _completed.removeWhere((key, _) => !visible.contains(key));
    _retry.removeWhere((key, _) => !visible.contains(key));
    if (!_running) _work = _drain();
  }

  Future<void> _drain() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      while (!_disposed && _pending.isNotEmpty) {
        final entry = _pending.entries.first;
        _pending.remove(entry.key);
        try {
          final item = entry.value;
          final result = item.group
              ? await GroupChatRepository(repository)
                    .history(item.target, messageType: 'voice', limit: 50)
              : await repository.history(
                  item.target,
                  messageType: 'voice',
                  limit: 50,
                );
          if (_disposed) return;
          final rows = (result['messages'] as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
          final worker = _worker = ChatVoicePrefetch(
            repository,
            group: item.group,
            media: media,
          );
          worker.update(rows);
          await worker.idle;
          final failed = worker.hasFailures;
          worker.dispose();
          _worker = null;
          if (failed) throw StateError('Voice retention incomplete');
          if (!_disposed) _completed[entry.key] = item.sequence;
          if (_pending[entry.key]?.sequence == item.sequence) {
            _pending.remove(entry.key);
          }
        } catch (_) {
          _pending.remove(entry.key);
          if (!_disposed) {
            _retry[entry.key] = DateTime.now().add(const Duration(seconds: 30));
          }
        } finally {
          _worker?.dispose();
          _worker = null;
        }
      }
    } finally {
      _running = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    _completed.clear();
    _retry.clear();
    _worker?.dispose();
    _session?.cancel();
  }
}
