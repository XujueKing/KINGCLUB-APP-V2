import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/push_registration_runtime.dart';

PushSession session(String id) => {
  'sessionId': id,
  'apiKeyId': 'key-$id',
  'apiKey': 'secret-$id',
  'account': {'userAccount': id, 'accountStatus': 'active'},
  'membership': {'status': 'active', 'registrationStatus': 'approved'},
};

void main() {
  testWidgets(
    'permission follows successful binding and failure does not retry binding',
    (tester) async {
      final events = <String>[];
      final runtime = PushRegistrationRuntime(
        readSession: () async => session('a'),
        register: () async {
          events.add('register');
          return 'token';
        },
        call: (s, id, p) async {
          events.add('bind');
        },
        requestNotificationPermission: () async {
          events.add('permission');
          throw StateError('system prompt unavailable');
        },
      );
      addTearDown(runtime.close);
      runtime.sync();
      await tester.pump();
      await tester.pump(const Duration(minutes: 1));
      expect(events, ['register', 'bind', 'permission']);
    },
  );
  testWidgets('background during binding never prompts for permission', (
    tester,
  ) async {
    final binding = Completer<void>();
    var prompts = 0;
    final runtime = PushRegistrationRuntime(
      readSession: () async => session('a'),
      register: () async => 'token',
      call: (s, id, p) => binding.future,
      requestNotificationPermission: () async {
        prompts++;
      },
    );
    addTearDown(runtime.close);
    runtime.sync();
    await tester.pump();
    runtime.foreground(false);
    binding.complete();
    await tester.pump();
    expect(prompts, 0);
  });
  testWidgets('unknown binding outcome is still cleaned up on logout', (
    tester,
  ) async {
    PushSession? current = session('a');
    final calls = <String>[];
    final runtime = PushRegistrationRuntime(
      readSession: () async => current,
      register: () async => 'token',
      call: (s, id, p) async {
        calls.add(id);
        if (id.endsWith('730')) throw TimeoutException('response lost');
      },
    );
    runtime.sync();
    await tester.pump();
    current = null;
    runtime.sync();
    await tester.pump();
    expect(calls, ['K260926000730', 'K260926000731']);
    runtime.close();
  });
  testWidgets('switch during SDK registration never binds the old account', (
    tester,
  ) async {
    PushSession? current = session('a');
    final pending = Completer<String>();
    var registrations = 0;
    final calls = <(String, String)>[];
    final runtime = PushRegistrationRuntime(
      readSession: () async => current,
      register: () =>
          ++registrations == 1 ? pending.future : Future.value('new-token'),
      call: (s, id, p) async {
        calls.add((s['sessionId'] as String, id));
      },
    );
    addTearDown(runtime.close);
    runtime.sync();
    await tester.pump();
    current = session('b');
    runtime.sync();
    pending.complete('old-token');
    await tester.pump();
    expect(calls, [('b', 'K260926000730')]);
  });
  testWidgets(
    'switch during binding cleans old binding before new registration',
    (tester) async {
      PushSession? current = session('a');
      final pending = Completer<void>();
      final calls = <(String, String)>[];
      final runtime = PushRegistrationRuntime(
        readSession: () async => current,
        register: () async => 'token',
        call: (s, id, p) async {
          calls.add((s['sessionId'] as String, id));
          if (s['sessionId'] == 'a' && id.endsWith('730')) await pending.future;
        },
      );
      addTearDown(runtime.close);
      runtime.sync();
      await tester.pump();
      current = session('b');
      runtime.sync();
      pending.complete();
      await tester.pump();
      expect(calls, [
        ('a', 'K260926000730'),
        ('a', 'K260926000731'),
        ('b', 'K260926000730'),
      ]);
    },
  );
  testWidgets(
    'failed logout cleanup is retried without registering another token',
    (tester) async {
      PushSession? current = session('a');
      var deletes = 0, registers = 0;
      final runtime = PushRegistrationRuntime(
        readSession: () async => current,
        retryDelay: const Duration(seconds: 1),
        register: () async {
          registers++;
          return 'token';
        },
        call: (s, id, p) async {
          if (id.endsWith('731') && ++deletes == 1) throw StateError('offline');
        },
      );
      addTearDown(runtime.close);
      runtime.sync();
      await tester.pump();
      current = null;
      runtime.sync();
      await tester.pump();
      expect(deletes, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(deletes, 2);
      expect(registers, 1);
    },
  );
  testWidgets('pause suspends retry and resume retries failed registration', (
    tester,
  ) async {
    var attempts = 0;
    final runtime = PushRegistrationRuntime(
      readSession: () async => session('a'),
      retryDelay: const Duration(seconds: 1),
      register: () async {
        attempts++;
        throw StateError('offline');
      },
      call: (s, id, p) async {},
    );
    addTearDown(runtime.close);
    runtime.sync();
    await tester.pump();
    expect(attempts, 1);
    runtime.foreground(false);
    await tester.pump(const Duration(seconds: 5));
    expect(attempts, 1);
    runtime.foreground(true);
    await tester.pump();
    expect(attempts, 2);
    runtime.close();
  });
  testWidgets('ineligible member and closed runtime do not bind', (
    tester,
  ) async {
    var current = session('a');
    current['membership'] = {
      'status': 'active',
      'registrationStatus': 'pending_review',
    };
    final pending = Completer<String>();
    var registered = 0, bound = 0;
    final runtime = PushRegistrationRuntime(
      readSession: () async => current,
      register: () {
        registered++;
        return pending.future;
      },
      call: (s, id, p) async {
        bound++;
      },
    );
    runtime.sync();
    await tester.pump();
    expect(registered, 0);
    current = session('a');
    runtime.sync();
    await tester.pump();
    runtime.close();
    pending.complete('token');
    await tester.pump();
    expect(bound, 0);
  });
}
