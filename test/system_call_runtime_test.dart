import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_state_controller.dart';
import 'package:kingclub/src/features/messaging/data/native_system_calls.dart';
import 'package:kingclub/src/features/messaging/data/system_call_runtime.dart';

import 'system_call_controller_binding_test.dart' as fixtures;

class Bridge extends fixtures.Native {
  List<SystemCallEvent> events = [];
  int acknowledgements = 0;
  @override
  Future<List<SystemCallEvent>> pending() async => List.of(events);
  @override
  Future<bool> acknowledge(SystemCallEvent event) async {
    acknowledgements++;
    events.removeWhere((e) => e.id == event.id);
    return true;
  }

  @override
  void listen({
    required Future<void> Function() changed,
    required Future<void> Function(bool) audio,
    void Function()? tokenChanged,
  }) {}
  @override
  void detach() {}
}

Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await fixtures.tick();
  }
}

void main() {
  test(
    'cold engine handles incoming without a page or media capture',
    () async {
      final f = fixtures.Fixture();
      final bridge = Bridge()..events = [fixtures.event('incoming')];
      var preparations = 0;
      final runtime = SystemCallRuntime(
        native: bridge,
        changed: () {},
        prepare: (_) async {
          preparations++;
          return f.controller;
        },
      );
      runtime.start();
      await settle();
      expect(runtime.active, same(f.controller));
      expect(preparations, 1);
      expect(f.media, isNull);
      expect(bridge.acknowledgements, 1);
      runtime.attachPage(f.controller);
      runtime.close();
      await f.close();
    },
  );

  test('concurrent native drains share setup and controller', () async {
    final f = fixtures.Fixture();
    final bridge = Bridge()..events = [fixtures.event('incoming')];
    final pending = Completer<CallStateController>();
    var preparations = 0;
    final runtime = SystemCallRuntime(
      native: bridge,
      changed: () {},
      prepare: (_) {
        preparations++;
        return pending.future;
      },
    );
    await runtime.drain();
    await runtime.drain();
    pending.complete(f.controller);
    await settle();
    expect(preparations, 1);
    expect(runtime.find(fixtures.callId), same(f.controller));
    runtime.attachPage(f.controller);
    runtime.close();
    await f.close();
  });

  test('foreground controller wins against an in-flight cold setup', () async {
    final f = fixtures.Fixture(), duplicate = fixtures.Fixture();
    final bridge = Bridge()..events = [fixtures.event('incoming')];
    final pending = Completer<CallStateController>();
    final runtime = SystemCallRuntime(
      native: bridge,
      changed: () {},
      prepare: (_) => pending.future,
    );
    await runtime.drain();
    runtime.adopt(f.controller);
    runtime.attachPage(f.controller);
    pending.complete(duplicate.controller);
    await settle();
    expect(runtime.active, same(f.controller));
    expect(duplicate.controller.isClosed, isTrue);
    expect(f.media, isNull);
    runtime.close();
    duplicate.binding.close();
    await duplicate.changes.close();
    await f.close();
  });

  test(
    'logout invalidates pending setup without accepting or capturing',
    () async {
      final f = fixtures.Fixture();
      final bridge = Bridge()..events = [fixtures.event('answer')];
      final pending = Completer<CallStateController>();
      final runtime = SystemCallRuntime(
        native: bridge,
        changed: () {},
        prepare: (_) => pending.future,
      );
      await runtime.drain();
      runtime.reset();
      pending.complete(f.controller);
      await settle();
      expect(runtime.active, isNull);
      expect(f.actions, isEmpty);
      expect(f.media, isNull);
      expect(bridge.completions, [('answer', false)]);
      runtime.close();
      f.binding.close();
      await f.changes.close();
    },
  );

  test(
    'native expiration prevents late setup from resurrecting the call',
    () async {
      final f = fixtures.Fixture();
      final bridge = Bridge()..events = [fixtures.event('incoming')];
      final pending = Completer<CallStateController>();
      final runtime = SystemCallRuntime(
        native: bridge,
        changed: () {},
        prepare: (_) => pending.future,
      );
      await runtime.drain();
      bridge.events = [
        SystemCallEvent.parse({
          'eventId': '00000000-0000-4000-8000-000000000009',
          'callId': fixtures.callId,
          'account': 'b',
          'scope': 'direct',
          'kind': 'ended',
        }),
      ];
      await runtime.drain();
      await settle();
      pending.complete(f.controller);
      await settle();
      expect(runtime.active, isNull);
      expect(f.media, isNull);
      runtime.close();
      f.binding.close();
      await f.changes.close();
    },
  );
}
