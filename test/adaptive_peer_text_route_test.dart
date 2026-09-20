import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/adaptive_peer_text_route.dart';

void main() {
  testWidgets('receipt within total budget preserves the next peer attempt', (
    tester,
  ) async {
    var calls = 0;
    final route = AdaptivePeerTextRoute(
      isActive: () => true,
      deliver: (_, _, current) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 1800));
        return current();
      },
    );
    bool? first;
    unawaited(route.send('first', 'first').then((value) => first = value));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(first, isNull);
    await tester.pump(const Duration(milliseconds: 600));
    expect(first, isTrue);

    bool? next;
    unawaited(route.send('next', 'next').then((value) => next = value));
    await tester.pump();
    expect(calls, 2);
    await tester.pump(const Duration(milliseconds: 1800));
    expect(next, isTrue);
  });

  test('new connection immediately escapes old cooldown', () async {
    Object connection = Object();
    var calls = 0;
    final route = AdaptivePeerTextRoute(
      isActive: () => true,
      elapsed: () => Duration.zero,
      connectionKey: () => connection,
      deliver: (_, _, _) async => ++calls > 1,
    );
    expect(await route.send('one', 'one'), false);
    expect(await route.send('two', 'two'), false);
    connection = Object();
    expect(await route.send('three', 'three'), true);
    expect(calls, 2);
  });

  test('old receipt cannot confirm or disturb a replacement attempt', () async {
    Object connection = Object();
    final pending = <Completer<bool>>[];
    final validity = <bool Function()>[];
    final route = AdaptivePeerTextRoute(
      isActive: () => true,
      connectionKey: () => connection,
      deliver: (_, _, valid) {
        validity.add(valid);
        final result = Completer<bool>();
        pending.add(result);
        return result.future;
      },
    );
    final old = route.send('one', 'one');
    connection = Object();
    expect(validity.first(), false);
    final replacement = route.send('two', 'two');
    pending.first.complete(true);
    expect(await old, false);
    expect(validity.last(), true);
    expect(await route.send('three', 'three'), false);
    pending.last.complete(true);
    expect(await replacement, true);
  });

  test('repeated failures back off with a cap and success resets it', () async {
    var now = Duration.zero;
    var success = false;
    var calls = 0;
    final route = AdaptivePeerTextRoute(
      isActive: () => true,
      elapsed: () => now,
      deliver: (_, _, _) async {
        calls++;
        return success;
      },
    );
    for (final second in [0, 30, 90, 210]) {
      now = Duration(seconds: second);
      expect(await route.send('hello', '$second'), false);
    }
    expect(calls, 4);
    now = const Duration(seconds: 329);
    expect(await route.send('waiting', 'waiting'), false);
    expect(calls, 4);
    now = const Duration(seconds: 330);
    success = true;
    expect(await route.send('recovered', 'recovered'), true);
    success = false;
    expect(await route.send('failed', 'failed'), false);
    now = const Duration(seconds: 360);
    success = true;
    expect(await route.send('retry', 'retry'), true);
    expect(calls, 7);
  });

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
