import 'dart:async';

import '../../../core/media/media_cache.dart';
import '../../../core/session/secure_session_store.dart';
import 'chat_voice_prefetch.dart';
import 'chat_history_store.dart';
import 'group_chat_repository.dart';
import 'messaging_repository.dart';

/// Prefetch voice for changed unread conversations without opening their pages.
/// History queries and media transfers are serialized and never mark as read.
class ChatVoiceInbox {
  ChatVoiceInbox(this.repository, {this.media, this.openHistory}) {
    _session = SecureSessionStore.changes.stream.listen((_) => dispose());
  }
  final MessagingRepository repository;
  final MediaCache? media;
  final Future<ChatHistoryStore> Function()? openHistory;
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
          final history = openHistory != null
              ? await openHistory!()
              : repository.persistHistory
              ? await ChatHistoryStore.open(repository.account)
              : null;
          if (_disposed) return;
          if (history != null && history.account != repository.account) {
            throw StateError('Wrong history account');
          }
          final historyKey =
              '${item.group ? 'group' : 'direct'}:${item.target}';
          final saved = history == null
              ? null
              : await history.read(historyKey, limit: 1);
          var epoch = saved?.epoch ?? 0;
          var revision = saved?.historyVersion;
          final forward = _completed.containsKey(entry.key);
          int? cursor = _completed[entry.key];
          final worker = _worker = ChatVoicePrefetch(
            repository,
            group: item.group,
            media: media,
          );
          while (!_disposed) {
            final result = item.group
                ? await GroupChatRepository(repository).history(
                    item.target,
                    before: forward ? null : cursor,
                    after: forward ? cursor : null,
                    limit: 50,
                  )
                : await repository.history(
                    item.target,
                    before: forward ? null : cursor,
                    after: forward ? cursor : null,
                    limit: 50,
                  );
            if (_disposed) return;
            final rows = (result['messages'] as List)
                .map((row) => Map<String, dynamic>.from(row as Map))
                .toList();
            var floor = 0;
            if (history != null) {
              final nextRevision = result['historyVersion'];
              if (nextRevision != revision) {
                if (nextRevision is! int ||
                    (revision != null && nextRevision < revision)) {
                  throw StateError('History revision changed');
                }
                final adopted = await history.adoptHistoryVersion(
                  historyKey,
                  expectedEpoch: epoch,
                  historyVersion: nextRevision,
                );
                if (adopted == null) throw StateError('History was cleared');
                epoch = adopted;
                revision = nextRevision;
              }
              if (_disposed) return;
              final hidden = (result['settings'] as Map?)?['hiddenThrough'];
              if (hidden is! int || hidden < 0) {
                throw StateError('Missing history boundary');
              }
              floor = hidden > (saved?.hiddenThrough ?? 0)
                  ? hidden
                  : saved!.hiddenThrough;
              final membership = result['membershipVersion'];
              if (item.group) {
                final joined = result['joinedSequence'];
                if (membership is! int ||
                    membership < 0 ||
                    joined is! int ||
                    joined < 0 ||
                    rows.any((row) => row['groupId'] != item.target)) {
                  throw StateError('Invalid group history boundary');
                }
                if (joined > floor) floor = joined;
              }
              // Persist ownership before downloading. Do not advance the
              // foreground sync cursor: these pages are fetched backwards.
              if (!await history.commit(
                historyKey,
                rows,
                expectedEpoch: epoch,
                historyVersion: revision,
                membershipVersion: item.group ? membership as int : null,
                hiddenThrough: floor,
              )) {
                throw StateError('History changed during retention');
              }
              if (_disposed) return;
            }
            worker.update(
              rows
                  .where(
                    (row) =>
                        history == null || (row['sequence'] as int) > floor,
                  )
                  .toList(),
            );
            await worker.idle;
            if (worker.hasFailures) {
              throw StateError('Voice retention incomplete');
            }
            if (result['hasMore'] != true) break;
            if (rows.isEmpty) throw StateError('History page did not advance');
            final sequences =
                rows.map((row) => (row['sequence'] as num).toInt()).toList()
                  ..sort();
            final next = forward ? sequences.last : sequences.first;
            if (cursor != null && (forward ? next <= cursor : next >= cursor)) {
              throw StateError('History page did not advance');
            }
            cursor = next;
            if (forward && cursor >= item.sequence) break;
          }
          worker.dispose();
          _worker = null;
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
