import 'dart:async';

/// Bounds peer-first delivery and avoids repeatedly delaying service delivery
/// while a peer is offline. Scope this object to one account and recipient.
class AdaptivePeerTextRoute {
  AdaptivePeerTextRoute({
    required this.isActive,
    required this.deliver,
    this.budget = const Duration(milliseconds: 2500),
    this.cooldown = const Duration(seconds: 30),
    Duration Function()? elapsed,
  }) : _elapsed = elapsed ?? (Stopwatch()..start()).elapsedDuration;

  final bool Function() isActive;
  final Future<bool> Function(String text, String id, bool Function() current)
  deliver;
  final Duration budget;
  final Duration cooldown;
  final Duration Function() _elapsed;
  Duration _retryAt = Duration.zero;
  Object? _attempt;

  Future<bool> send(String text, String id) async {
    if (!isActive() || _attempt != null || _elapsed() < _retryAt) return false;
    final token = Object();
    _attempt = token;
    bool current() => identical(_attempt, token) && isActive();
    var delivered = false;
    try {
      delivered = await Future<bool>.sync(() => deliver(text, id, current))
          .timeout(budget);
      return current() && delivered;
    } catch (_) {
      return false;
    } finally {
      // A late handshake/receipt cannot launch another device attempt once the
      // service fallback has started. Existing wire IDs remain unchanged.
      if (identical(_attempt, token)) {
        _attempt = null;
        if (!delivered) _retryAt = _elapsed() + cooldown;
      }
    }
  }
}

extension on Stopwatch {
  Duration elapsedDuration() => elapsed;
}
