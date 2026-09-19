import 'dart:async';

/// Bounds peer-first delivery and avoids repeatedly delaying service delivery
/// while a peer is offline. Scope this object to one account and recipient.
class AdaptivePeerTextRoute {
  AdaptivePeerTextRoute({
    required this.isActive,
    required this.deliver,
    this.budget = const Duration(milliseconds: 2500),
    this.cooldown = const Duration(seconds: 30),
    this.connectionKey,
    Duration Function()? elapsed,
  }) : _elapsed = elapsed ?? (Stopwatch()..start()).elapsedDuration;

  final bool Function() isActive;
  final Future<bool> Function(String text, String id, bool Function() current)
  deliver;
  final Duration budget;
  final Duration cooldown;

  /// A fresh authenticated connection permits recovery without waiting for the
  /// old connection's cooldown. Its identity also fences late receipts.
  final Object? Function()? connectionKey;
  final Duration Function() _elapsed;
  Duration _retryAt = Duration.zero;
  Object? _attempt;
  Object? _connection;
  int _failures = 0;

  Future<bool> send(String text, String id) async {
    if (!isActive()) return false;
    final connection = connectionKey?.call();
    if (!identical(connection, _connection)) {
      _connection = connection;
      _retryAt = Duration.zero;
      _failures = 0;
      _attempt = null;
    }
    if (_attempt != null || _elapsed() < _retryAt) return false;
    final token = Object();
    _attempt = token;
    bool current() =>
        identical(_attempt, token) &&
        isActive() &&
        identical(connectionKey?.call(), connection);
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
        if (delivered &&
            isActive() &&
            identical(connectionKey?.call(), connection)) {
          _failures = 0;
          _retryAt = Duration.zero;
        } else if (identical(connectionKey?.call(), connection)) {
          // Repeated unavailable peers should not delay every new message.
          // A successful receipt or new connection resets this backoff.
          _failures = (_failures + 1).clamp(1, 3);
          _retryAt = _elapsed() + cooldown * (1 << (_failures - 1));
        }
      }
    }
  }
}

extension on Stopwatch {
  Duration elapsedDuration() => elapsed;
}
