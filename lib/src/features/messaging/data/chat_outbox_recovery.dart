import 'dart:async';

import 'chat_outbox.dart';
import 'chat_session_controller.dart';
import 'direct_chat_controller.dart';
import 'group_chat_controller.dart';
import 'group_chat_repository.dart';
import 'messaging_repository.dart';
import 'novorudp_binding_runtime.dart';
import 'chat_history_store.dart';

/// Foreground delivery is independent of which conversation is visible.
/// Existing controllers retain receipt validation and membership checks.
class ChatOutboxRecovery {
  ChatOutboxRecovery(this.repository, this.outbox, {this.relaySenderFor});
  final Future<bool> Function(String text, String id) Function(String peer)?
  relaySenderFor;
  final MessagingRepository repository;
  final ChatOutbox outbox;
  static final _visible = <String, int>{};
  static final _workers = <ChatOutboxRecovery>{};
  final _running = <String, ChatSessionController>{};
  Future<void>? _draining;
  Timer? _timer;
  bool _closed = false;

  static String _key(String account, String target, bool group) =>
      '$account:${group ? "group" : "direct"}:$target';

  /// A page takes over before opening its controller. An in-flight recovery
  /// request can finish on the server; the stable client ID makes retry safe.
  static void Function() hold(String account, String target, bool group) {
    final key = _key(account, target, group);
    _visible[key] = (_visible[key] ?? 0) + 1;
    for (final worker in _workers) {
      worker._running.remove(key)?.dispose();
    }
    var released = false;
    return () {
      if (released) return;
      released = true;
      final count = (_visible[key] ?? 1) - 1;
      if (count == 0) {
        _visible.remove(key);
      } else {
        _visible[key] = count;
      }
    };
  }

  void start() {
    if (_closed) return;
    _workers.add(this);
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) => notify());
    notify();
  }

  Future<void> notify() {
    if (_closed) return Future<void>.value();
    return _draining ??= _drain().whenComplete(() => _draining = null);
  }

  Future<void> _drain() async {
    await Future.wait([_retryReads(), _drainMessages()]);
  }

  Future<void> _retryReads() async {
    // Read-intent storage/network failures must not delay pending messages.
    try {
      await repository.retryPendingReads(isActive: () => !_closed);
    } catch (_) {}
  }

  Future<void> _drainMessages() async {
    try {
      final rows = await outbox.read();
      final visited = <String>{};
      for (final row in rows) {
        if (_closed) return;
        if (row['status'] != 'queued') continue;
        final group = row['groupId'] is String;
        final target = group ? row['groupId'] : row['recipient'];
        if (target is! String || target.isEmpty) continue;
        final key = _key(repository.account, target, group);
        if (!visited.add(key) || _visible.containsKey(key)) continue;
        final ChatSessionController chat = group
            ? GroupChatController(
                repository: GroupChatRepository(repository),
                groupId: target,
                outbox: outbox,
              )
            : DirectChatController(
                repository: repository,
                peer: target,
                outbox: outbox,
                openHistory: repository.persistHistory
                    ? () => ChatHistoryStore.open(repository.account)
                    : null,
                sendRelayText:
                    relaySenderFor?.call(target) ??
                    (repository.persistHistory
                        ? NovoRudpBindingRuntime.textSender(
                            repository.account,
                            target,
                          )
                        : null),
              );
        _running[key] = chat;
        try {
          await chat.initialize();
        } finally {
          if (identical(_running[key], chat)) {
            _running.remove(key);
            chat.dispose();
          }
        }
      }
    } catch (_) {
      // Durable queue survives storage/network errors; retry on ready/resume.
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _workers.remove(this);
    for (final chat in _running.values) {
      chat.dispose();
    }
    _running.clear();
  }
}
