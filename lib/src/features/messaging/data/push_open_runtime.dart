import 'dart:convert';

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
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final Future<String?> Function() takePending;
  final Future<PushOpenSession?> Function() readySession;
  final Future<bool> Function(PushOpenTarget, PushOpenSession) open;
  final DateTime Function() now;
  final _seen = <String>{};
  PushOpenTarget? _pending;
  Future<void>? _running;
  bool _dirty = false, _closed = false;

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
        // Native queue is bounded too; arbitrary external intents cannot cause
        // an unbounded drain or arbitrary URLs/activity execution.
        for (var i = 0; i < 8 && !_closed; i++) {
          final raw = await takePending();
          if (raw == null) break;
          final parsed = PushOpenTarget.parse(raw, now());
          if (parsed != null && !_seen.contains(parsed.eventId)) {
            _pending = parsed;
          }
        }
        if (_closed) return;
        final pending = _pending;
        if (pending == null) continue;
        if (pending.expiresAt <= now().millisecondsSinceEpoch) {
          _pending = null;
          continue;
        }
        final session = await readySession();
        if (_closed) return;
        if (_dirty) continue;
        if (session == null) continue;
        if (pending.expiresAt <= now().millisecondsSinceEpoch) {
          _pending = null;
          continue;
        }
        if (session.account != pending.recipient) {
          _pending =
              null; // A previous account's click must not survive a switch.
          continue;
        }
        if (await open(pending, session)) {
          _seen.add(pending.eventId);
          if (_seen.length > 64) _seen.remove(_seen.first);
          if (identical(_pending, pending)) _pending = null;
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
    _seen.clear();
  }
}
