import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_lan_route.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_connection.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class Identity extends Fake implements NovoRudpSecureSession {
  @override
  String get peerId => 'novovm-ed25519:${'a' * 64}';
}

class Relay extends Fake implements NovoRudpRelayConnection {
  @override
  final identity = Identity();
  @override
  Stream<Map<String, dynamic>> get messages => const Stream.empty();
}

class Channel extends Fake implements NovoRudpSecureChannel {
  int closes = 0;
  @override
  void close() {
    closes++;
  }
}

class Route extends Fake implements NovoRudpLanRoute {
  @override
  bool isClosed = false;
  int advertisements = 0;
  @override
  Future<void> advertise() async {
    advertisements++;
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

void main() {
  // A non-closing relay stream is required: an empty stream closes the lane.
  NovoRudpRelayFrameLink link(
    Channel channel,
    NovoRudpLanRouteFactory factory,
    Relay relay,
  ) => NovoRudpRelayFrameLink(
    relay: relay,
    channel: channel,
    expectedPeer: 'novovm-ed25519:${'b' * 64}',
    enableLan: true,
    openLanRoute: factory,
  );
  testWidgets('closed UDP route is replaced without closing secure channel', (
    tester,
  ) async {
    final relay = LiveRelay(), channel = Channel(), routes = <Route>[];
    final lane = link(channel, ({
      required channel,
      required sendControl,
      required deliver,
    }) async {
      final route = Route();
      routes.add(route);
      return route;
    }, relay);
    await tester.pump();
    expect(routes.length, 1);
    routes.first.close();
    await tester.pump(const Duration(seconds: 5));
    expect(routes.length, 2);
    expect(routes.last.advertisements, 1);
    expect(channel.closes, 0);
    await tester.pump(const Duration(seconds: 10));
    expect(routes.length, 2, reason: 'healthy route is retained');
    unawaited(lane.close());
    await tester.pump();
    expect(channel.closes, 1);
    final closedEvents = relay.events.close();
    await tester.pump();
    unawaited(closedEvents);
    await tester.pump(const Duration(seconds: 10));
    expect(routes.length, 2);
  });
  testWidgets('failed bind retries and only one pending open can exist', (
    tester,
  ) async {
    final relay = LiveRelay(), channel = Channel();
    final pending = Completer<NovoRudpLanRoute?>();
    var attempts = 0;
    final lane = link(channel, ({
      required channel,
      required sendControl,
      required deliver,
    }) async {
      attempts++;
      if (attempts == 1) throw StateError('bind unavailable');
      return pending.future;
    }, relay);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(attempts, 2);
    await tester.pump(const Duration(seconds: 15));
    expect(attempts, 2);
    unawaited(lane.close());
    await tester.pump();
    expect(channel.closes, 1);
    final late = Route();
    pending.complete(late);
    await tester.pump();
    expect(late.isClosed, isTrue);
    expect(late.advertisements, 0);
    final closedEvents = relay.events.close();
    await tester.pump();
    unawaited(closedEvents);
  });
}

class LiveRelay extends Relay {
  final events = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get messages => events.stream;
}
