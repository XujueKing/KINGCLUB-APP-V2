import 'dart:math';

/// Bounded, one-use challenges. All elapsed times use a monotonic clock.
class NovoRudpRouteProbe {
  NovoRudpRouteProbe({Duration Function()? clock}) {
    final watch = Stopwatch()..start();
    _clock = clock ?? (() => watch.elapsed);
  }

  late final Duration Function() _clock;
  final _random = Random.secure();
  final _pending = <String, ({String nonce, Duration sent})>{};
  static const lifetime = Duration(seconds: 3);

  String issue(String endpoint) {
    final now = _clock();
    _pending.removeWhere((_, value) => now - value.sent >= lifetime);
    // Five IPv4 and two IPv6 candidates plus two authenticated observed ports.
    if (!_pending.containsKey(endpoint) && _pending.length >= 9) {
      _pending.remove(_pending.keys.first);
    }
    final nonce = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _pending[endpoint] = (nonce: nonce, sent: now);
    return nonce;
  }

  static bool validNonce(Object? value) =>
      value is String && RegExp(r'^[0-9a-f]{32}$').hasMatch(value);

  bool accept(String endpoint, Object? nonce) {
    final pending = _pending[endpoint];
    if (pending == null || pending.nonce != nonce) return false;
    _pending.remove(endpoint);
    final age = _clock() - pending.sent;
    return age >= Duration.zero && age < lifetime;
  }

  void clear() => _pending.clear();
}
