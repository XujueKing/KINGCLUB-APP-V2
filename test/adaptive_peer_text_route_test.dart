import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/adaptive_peer_text_route.dart';

void main() {
  testWidgets('timeout falls back and invalidates late device work', (
    tester,
  ) async {
    final pending = Completer<bool>();
    late bool Function() current;
    final route = AdaptivePeerTextRoute(
      isActive: () => true,
      deliver: (_, _, valid) {
        current = valid;
        return pending.future;
      },
    );
    bool? result;
    unawaited(route.send('hello', 'stable-id').then((v) => result = v));
    await tester.pump();
    expect(current(), isTrue);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(result, isFalse);
    expect(current(), isFalse);
    pending.complete(true);
    await tester.pump();
    expect(result, isFalse);
  });

  test('failed peer is bypassed until cooldown, then recovers', () async {
    var now = Duration.zero;
    var calls = 0;
    final ids = <String>[];
    final route = AdaptivePeerTextRoute(
      isActive: () => true,
      elapsed: () => now,
      deliver: (_, id, _) async {
        ids.add(id);
        return ++calls > 1;
      },
    );
    expect(await route.send('one', 'one'), isFalse);
    expect(await route.send('two', 'two'), isFalse);
    expect(calls, 1);
    now = const Duration(seconds: 30);
    expect(await route.send('three', 'three'), isTrue);
    expect(await route.send('four', 'four'), isTrue);
    expect(ids, ['one', 'three', 'four']);
  });

  test('concurrent sends fall back without competing peer probes', () async {
    final pending = Completer<bool>();
    var calls = 0;
    final route = AdaptivePeerTextRoute(
      isActive: () => true,
      deliver: (_, _, _) {
        calls++;
        return pending.future;
      },
    );
    final first = route.send('one', 'one');
    expect(await route.send('two', 'two'), isFalse);
    expect(calls, 1);
    pending.complete(true);
    expect(await first, isTrue);
  });

  test(
    'session change discards receipt and forbids further delivery',
    () async {
      var active = true;
      var calls = 0;
      final pending = Completer<bool>();
      final route = AdaptivePeerTextRoute(
        isActive: () => active,
        deliver: (_, _, _) {
          calls++;
          return pending.future;
        },
      );
      final first = route.send('one', 'one');
      active = false;
      pending.complete(true);
      expect(await first, isFalse);
      expect(await route.send('two', 'two'), isFalse);
      expect(calls, 1);
    },
  );

  test('one recipient failure does not suppress another', () async {
    AdaptivePeerTextRoute route(bool success) => AdaptivePeerTextRoute(
      isActive: () => true,
      deliver: (_, _, _) async => success,
    );
    expect(await route(false).send('one', 'one'), isFalse);
    expect(await route(true).send('two', 'two'), isTrue);
  });
}
