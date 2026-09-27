import 'dart:convert';

import 'push_open_store.dart';

class PushOpenTarget {
  PushOpenTarget._(
    this.eventId,
    this.recipient,
    this.target,
    this.group,
    this.call,
    this.expiresAt,
  );
  final String eventId, recipient, target;
  final bool group, call;
  final int expiresAt;
  static final _account = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static PushOpenTarget? parse(String raw, DateTime now) {
    if (raw.length > 2048) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map ||
          data['version'] != 1 ||
          !['message', 'call'].contains(data['kind']) ||
          !['direct', 'group'].contains(data['scope'])) {
        return null;
      }
      final event = data['eventId'],
          recipient = data['recipient'],
          target = data['target'],
          expiry = data['expiresAt'];
      if (event is! String ||
          !_uuid.hasMatch(event) ||
          recipient is! String ||
          !_account.hasMatch(recipient) ||
          target is! String ||
          !(data['scope'] == 'group' ? _uuid : _account).hasMatch(target) ||
          expiry is! int ||
          expiry <= now.millisecondsSinceEpoch ||
          expiry > now.add(const Duration(days: 1)).millisecondsSinceEpoch) {
        return null;
      }
      return PushOpenTarget._(
        event,
        recipient,
        target,
        data['scope'] == 'group',
        data['kind'] == 'call',
        expiry,
      );
    } catch (_) {
      return null;
    }
  }
}

typedef PushOpenSession = ({String account, String sessionId});

/// Holds a click through bootstrap, never a login credential or message body.
/// Navigation performs a second session check immediately before opening UI.
class PushOpenRuntime {
  PushOpenRuntime({
    required this.takePending,
    required this.readySession,
    required this.open,
    this.store,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final Future<String?> Function() takePending;
  final Future<PushOpenSession?> Function() readySession;
  final Future<bool> Function(PushOpenTarget, PushOpenSession) open;
  final DateTime Function() now;
  final PushOpenStore? store;
  final _seen = <String, int>{};
  String? _handledWrite;
  PushOpenTarget? _pending;
  String? _pendingWrite;
  Future<void>? _running;
  bool _dirty = false, _closed = false;
  bool _restored = false;
  bool _discarding = false;

  void _restoreHandled(String? raw) {
    if (raw == null || raw.length > 8192) return;
    try {
      final entries = jsonDecode(raw);
      if (entries is! Map || entries.length > 64) return;
      final current = now().millisecondsSinceEpoch;
      final latest = now().add(const Duration(days: 1)).millisecondsSinceEpoch;
      for (final entry in entries.entries) {
        final id = entry.key, expiry = entry.value;
        if (id is String &&
            PushOpenTarget._uuid.hasMatch(id) &&
            expiry is int &&
            expiry > current &&
            expiry <= latest) {
          _seen[id] = expiry;
        }
      }
    } catch (_) {
      // A corrupt receipt must not prevent a new, validated click.
    }
  }

  Future<void> _persistHandled() async {
    if (_handledWrite == null) return;
    await store?.saveHandled(_handledWrite!);
    _handledWrite = null;
  }

  Future<void> _discard() async {
    _discarding = true;
    await store?.clear();
    _pending = null;
    _pendingWrite = null;
    _discarding = false;
  }

  /// Recheck after asynchronous navigation authorization: a newer native click
  /// may be waiting to be drained while the previous session read completes.
  bool isCurrent(PushOpenTarget target) =>
      !_closed && !_dirty && identical(_pending, target);

  Future<void> sync() {
    if (_closed) return Future.value();
    _dirty = true;
    return _running ??= _pump().whenComplete(() => _running = null);
  }

  Future<void> _pump() async {
    do {
      _dirty = false;
      try {
        await _persistHandled();
        if (_discarding) await _discard();
        if (_closed) return;
        if (!_restored) {
          final handled = await store?.readHandled();
          if (_closed) return;
          _restoreHandled(handled);
          if (handled != null && handled != jsonEncode(_seen)) {
            _handledWrite = jsonEncode(_seen);
            await _persistHandled();
          }
          final saved = await store?.read();
          if (_closed) return;
          if (saved != null) {
            _pending = PushOpenTarget.parse(saved, now());
            if (_pending == null) await store?.clear();
          }
          _restored = true;
        }
        _seen.removeWhere(
          (_, expiry) => expiry <= now().millisecondsSinceEpoch,
        );
        // Native queue is bounded too; arbitrary external intents cannot cause
        // an unbounded drain or arbitrary URLs/activity execution.
        for (var i = 0; i < 8 && !_closed; i++) {
          final raw = await takePending();
          if (raw == null) break;
          final parsed = PushOpenTarget.parse(raw, now());
          if (parsed != null && !_seen.containsKey(parsed.eventId)) {
            _pending = parsed;
            // Persist before waiting for login/navigation so a new runtime can
            // resume after the process is reclaimed during bootstrap.
            _pendingWrite = jsonEncode({
              'version': 1,
              'eventId': parsed.eventId,
              'recipient': parsed.recipient,
              'target': parsed.target,
              'scope': parsed.group ? 'group' : 'direct',
              'kind': parsed.call ? 'call' : 'message',
              'expiresAt': parsed.expiresAt,
            });
          }
        }
        if (_closed) return;
        if (_pendingWrite != null) {
          await store?.save(_pendingWrite!);
          _pendingWrite = null;
          if (_closed) return;
        }
        final pending = _pending;
        if (pending == null) continue;
        if (_seen.containsKey(pending.eventId)) {
          await _discard();
          continue;
        }
        if (pending.expiresAt <= now().millisecondsSinceEpoch) {
          await _discard();
          continue;
        }
        final session = await readySession();
        if (_closed) return;
        if (_dirty) continue;
        if (session == null) continue;
        if (pending.expiresAt <= now().millisecondsSinceEpoch) {
          await _discard();
          continue;
        }
        if (session.account != pending.recipient) {
          // A previous account's click must not survive a switch, including
          // a temporary secure-storage deletion failure.
          await _discard();
          continue;
        }
        if (await open(pending, session)) {
          _seen[pending.eventId] = pending.expiresAt;
          if (_seen.length > 64) _seen.remove(_seen.keys.first);
          _handledWrite = jsonEncode(_seen);
          // Save the receipt before clearing the pending target. If clearing
          // fails, a rebuilt runtime still knows the click was handled.
          await _persistHandled();
          if (identical(_pending, pending)) {
            await _discard();
          }
        }
      } catch (_) {
        // Keep the click for the next lifecycle/session/navigation update.
        // Never log extras, session identifiers or vendor payloads.
      }
    } while (_dirty && !_closed);
  }

  void close() {
    _closed = true;
    _pending = null;
    _pendingWrite = null;
    _seen.clear();
  }
}
