import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/push_open_runtime.dart';

void main() {
  final time = DateTime.utc(2026, 9, 27);
  const session = (account: 'fixture_recipient', sessionId: 'fixture_session');
  Map<String, dynamic> payload() => {
    'version': 1,
    'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'recipient': session.account,
    'target': 'fixture_sender',
    'scope': 'direct',
    'kind': 'message',
    'expiresAt': time.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
  };
  test(
    'accepts scoped message/call hints and rejects invalid or stale input',
    () {
      for (final kind in ['message', 'call']) {
        for (final scope in ['direct', 'group']) {
          final data = payload()
            ..['kind'] = kind
            ..['scope'] = scope;
          if (scope == 'group') {
            data['target'] = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
          }
          final parsed = PushOpenTarget.parse(jsonEncode(data), time)!;
          expect(parsed.call, kind == 'call');
          expect(parsed.group, scope == 'group');
        }
      }
      for (final change in <Map<String, dynamic>>[
        {'target': 'https://invalid.example'},
        {'recipient': '../other'},
        {'scope': 'group'},
        {'version': 2},
        {'eventId': ''},
        {'kind': 'execute'},
        {'expiresAt': time.millisecondsSinceEpoch},
        {'expiresAt': time.add(const Duration(days: 2)).millisecondsSinceEpoch},
      ]) {
        expect(
          PushOpenTarget.parse(jsonEncode(payload()..addAll(change)), time),
          isNull,
        );
      }
      expect(PushOpenTarget.parse('x' * 2049, time), isNull);
      expect(PushOpenTarget.parse('[]', time), isNull);
    },
  );
  test(
    'holds cold click through bootstrap, deduplicates foreground delivery',
    () async {
      final queue = [jsonEncode(payload())];
      PushOpenSession? ready;
      var opens = 0;
      final runtime = PushOpenRuntime(
        takePending: () async => queue.isEmpty ? null : queue.removeAt(0),
        readySession: () async => ready,
        open: (target, current) async {
          expect(current, session);
          opens++;
          return true;
        },
        now: () => time,
      );
      addTearDown(runtime.close);
      await runtime.sync();
      expect(opens, 0);
      ready = session;
      await runtime.sync();
      expect(opens, 1);
      queue.add(jsonEncode(payload()));
      await runtime.sync();
      expect(opens, 1);
    },
  );
  test('drops a previous account click permanently', () async {
    final queue = [jsonEncode(payload())];
    var ready = (account: 'other', sessionId: 'other');
    var opens = 0;
    final runtime = PushOpenRuntime(
      takePending: () async => queue.isEmpty ? null : queue.removeAt(0),
      readySession: () async => ready,
      open: (_, _) async {
        opens++;
        return true;
      },
      now: () => time,
    );
    addTearDown(runtime.close);
    await runtime.sync();
    ready = session;
    await runtime.sync();
    expect(opens, 0);
  });
  for (final duringNavigation in [false, true]) {
    test(
      'new click supersedes stale ${duringNavigation ? 'navigation' : 'session'} read',
      () async {
        final queue = [jsonEncode(payload())];
        final gate = Completer<void>();
        final entered = Completer<void>();
        final opened = <String>[];
        var reads = 0;
        late PushOpenRuntime runtime;
        runtime = PushOpenRuntime(
          takePending: () async => queue.isEmpty ? null : queue.removeAt(0),
          readySession: () async {
            if (!duringNavigation && reads++ == 0) {
              entered.complete();
              await gate.future;
            }
            return session;
          },
          open: (target, _) async {
            if (duringNavigation && !entered.isCompleted) {
              entered.complete();
              await gate.future;
            }
            if (!runtime.isCurrent(target)) return false;
            opened.add(target.target);
            return true;
          },
          now: () => time,
        );
        addTearDown(runtime.close);
        final first = runtime.sync();
        await entered.future;
        queue.add(
          jsonEncode(
            payload()
              ..['eventId'] = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
              ..['target'] = 'new_sender',
          ),
        );
        final second = runtime.sync();
        gate.complete();
        await Future.wait([first, second]);
        expect(opened, ['new_sender']);
        await runtime.sync();
        expect(opened, ['new_sender']);
      },
    );
  }
  test(
    'navigation not ready retains click and racing sync stays serialized',
    () async {
      final queue = [jsonEncode(payload())];
      final release = Completer<bool>();
      var opens = 0;
      final runtime = PushOpenRuntime(
        takePending: () async => queue.isEmpty ? null : queue.removeAt(0),
        readySession: () async => session,
        open: (_, _) async {
          opens++;
          return opens == 1 ? release.future : true;
        },
        now: () => time,
      );
      addTearDown(runtime.close);
      final first = runtime.sync();
      await Future<void>.delayed(Duration.zero);
      final second = runtime.sync();
      expect(opens, 1);
      release.complete(false);
      await Future.wait([first, second]);
      expect(opens, 2);
      await runtime.sync();
      expect(opens, 2);
    },
  );
  for (final dispose in [false, true]) {
    test(
      'late session read blocked by ${dispose ? 'dispose' : 'expiry'}',
      () async {
        var clock = time;
        final queue = [jsonEncode(payload())];
        final ready = Completer<PushOpenSession?>();
        var opens = 0;
        final runtime = PushOpenRuntime(
          takePending: () async => queue.isEmpty ? null : queue.removeAt(0),
          readySession: () => ready.future,
          open: (_, _) async {
            opens++;
            return true;
          },
          now: () => clock,
        );
        addTearDown(runtime.close);
        final task = runtime.sync();
        await Future<void>.delayed(Duration.zero);
        if (dispose) {
          runtime.close();
        } else {
          clock = time.add(const Duration(minutes: 2));
        }
        ready.complete(session);
        await task;
        expect(opens, 0);
      },
    );
  }
}
