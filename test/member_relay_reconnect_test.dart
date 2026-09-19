import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_runtime.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_device_binding.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_connection.dart';

class _Binding implements NovoRudpDeviceBinding {
  @override
  Future<NetworkDeviceKey> ensureRegistered() async => NetworkDeviceKey.parse({
    'bindingId': '11111111-1111-4111-8111-111111111111',
    'publicKey': 'a' * 64,
    'peerId': 'novovm-ed25519:${'a' * 64}',
  });
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connection implements NovoRudpRelayConnection {
  _Connection({this.fail = false, this.pending});
  final bool fail;
  final Completer<void>? pending;
  final events = StreamController<Map<String, dynamic>>.broadcast();
  bool closed = false;
  @override
  Stream<Map<String, dynamic>> get messages => events.stream;
  @override
  Future<void> connect() async {
    if (fail) throw StateError('test unavailable');
    await pending?.future;
  }

  @override
  void close([Object? error]) {
    if (closed) return;
    closed = true;
    unawaited(events.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  MemberRelayRuntime runtime(NovoRudpRelayConnection Function() factory) =>
      MemberRelayRuntime(
        binding: _Binding(),
        endpoint: Uri.parse('wss://relay.invalid/novovm'),
        expectedRelay: 'novovm-ed25519:${'b' * 64}',
        connectionFactory: factory,
        retryJitter: () => 0,
      );

  testWidgets('failed connections back off to a bounded 30 seconds', (
    tester,
  ) async {
    final sockets = <_Connection>[];
    final relay = runtime(() {
      final socket = _Connection(fail: true);
      sockets.add(socket);
      return socket;
    });
    addTearDown(relay.close);
    relay.start();
    relay.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(sockets.length, 1);
    for (final seconds in [1, 2, 4, 8, 16, 30, 30]) {
      final before = sockets.length;
      await tester.pump(Duration(milliseconds: seconds * 1000 - 1));
      expect(sockets.length, before);
      await tester.pump(const Duration(milliseconds: 1));
      expect(sockets.length, before + 1);
    }
    expect(sockets.every((s) => s.closed), isTrue);
    relay.close();
    final count = sockets.length;
    await tester.pump(const Duration(minutes: 1));
    expect(sockets.length, count);
  });

  testWidgets('flapping does not reset backoff; stable connection does', (
    tester,
  ) async {
    final sockets = <_Connection>[];
    final relay = runtime(() {
      final socket = _Connection();
      sockets.add(socket);
      return socket;
    });
    addTearDown(relay.close);
    relay.start();
    relay.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    sockets.last.close();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(sockets.length, 2);
    sockets.last.close();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(sockets.length, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(sockets.length, 3);
    await tester.pump(const Duration(seconds: 30));
    sockets.last.close();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(sockets.length, 4);
    relay.close();
  });

  testWidgets('background cancels retries, foreground reconnects immediately', (
    tester,
  ) async {
    var calls = 0;
    final relay = runtime(() {
      calls++;
      return _Connection(fail: true);
    });
    addTearDown(relay.close);
    relay.start();
    relay.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 1);
    relay.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 1);
    relay.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 2);
    relay.close();
  });

  testWidgets(
    'late background handshake cannot replace foreground connection',
    (tester) async {
      final held = Completer<void>();
      final old = _Connection(pending: held);
      final fresh = _Connection();
      var calls = 0;
      final relay = runtime(() => calls++ == 0 ? old : fresh);
      addTearDown(relay.close);
      relay.start();
      relay.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      relay.didChangeAppLifecycleState(AppLifecycleState.paused);
      relay.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(relay.connection, same(fresh));
      held.complete();
      await tester.pump();
      expect(old.closed, isTrue);
      expect(relay.connection, same(fresh));
      await tester.pump(const Duration(seconds: 31));
      expect(calls, 2);
      relay.close();
    },
  );
  testWidgets('account change cancels a scheduled retry', (tester) async {
    var calls = 0;
    final relay = runtime(() {
      calls++;
      return _Connection(fail: true);
    });
    addTearDown(relay.close);
    relay.start();
    relay.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 1);
    MemberQrMemory.clear();
    await tester.pump(const Duration(seconds: 31));
    expect(calls, 1);
    expect(relay.connection, isNull);
    relay.close();
  });
}
