import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_route_probe.dart';

void main() {
  test('burst retries preserve delayed replies without extending expiry', () {
    var now = Duration.zero;
    final probes = NovoRudpRouteProbe(clock: () => now);
    final nonce = probes.issue('a:1', retryPending: true);
    now = const Duration(milliseconds: 400);
    expect(probes.issue('a:1', retryPending: true), nonce);
    expect(probes.accept('a:2', nonce), isFalse);
    expect(probes.accept('a:1', nonce), isTrue);
    expect(probes.accept('a:1', nonce), isFalse);
    final next = probes.issue('a:1', retryPending: true);
    expect(next, isNot(nonce));
    now = const Duration(milliseconds: 3399);
    expect(probes.issue('a:1', retryPending: true), next);
    now = const Duration(milliseconds: 3400);
    expect(probes.accept('a:1', next), isFalse);
    expect(probes.issue('a:1', retryPending: true), isNot(next));
  });
  test('only current endpoint challenge can refresh liveness once', () {
    var now = Duration.zero;
    final probes = NovoRudpRouteProbe(clock: () => now);
    final old = probes.issue('a:1');
    final current = probes.issue('a:1');
    expect(old, isNot(current));
    expect(probes.accept('b:1', current), isFalse);
    expect(probes.accept('a:2', current), isFalse);
    expect(probes.accept('a:1', old), isFalse);
    expect(probes.accept('a:1', null), isFalse);
    now = const Duration(milliseconds: 2999);
    expect(probes.accept('a:1', current), isTrue);
    expect(probes.accept('a:1', current), isFalse);
  });

  test('delayed response and endpoint changes never revive route', () {
    var now = Duration.zero;
    final probes = NovoRudpRouteProbe(clock: () => now);
    final expired = probes.issue('a:1');
    now = const Duration(seconds: 3);
    expect(probes.accept('a:1', expired), isFalse);
    final changed = probes.issue('a:1');
    probes.clear();
    expect(probes.accept('a:1', changed), isFalse);
    final fresh = probes.issue('a:1');
    expect(probes.accept('a:1', fresh), isTrue);
  });
}
