import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_lan_route.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_connection.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

// In-memory carrier for native encrypted control envelopes. UDP and AEAD are
// real; this test does not claim to exercise public WSS or phone NAT traversal.
class Carrier extends Fake implements NovoRudpRelayConnection {
  Carrier(this.identity);
  @override
  final NovoRudpSecureSession identity;
  final events = StreamController<Map<String, dynamic>>.broadcast();
  late Carrier other;
  @override
  Stream<Map<String, dynamic>> get messages => events.stream;
  @override
  void sendEnvelope(Map<String, dynamic> envelope) {
    other.events.add({
      'kind': 'delivery',
      'body': {
        'source_peer_id': identity.peerId,
        'target_peer_id': other.identity.peerId,
        'envelope': envelope,
      },
    });
  }
}

void main() {
  test(
    'parent rebuilds real UDP and resumes native encrypted data',
    () async {
      final library = DynamicLibrary.open(
        Platform.environment['NOVORUDP_NATIVE_LIBRARY']!,
      );
      final a = NovoRudpSecureSession.fromSeed(
        library: library,
        seed: Uint8List(32),
      );
      final b = NovoRudpSecureSession.fromSeed(
        library: library,
        seed: Uint8List.fromList(List.filled(32, 73)),
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final offer = a.start(b.peerId);
      final answer = b.respond(offer.offer, expectedPeer: a.peerId);
      final channel = a.complete(offer, answer.response);
      final ca = Carrier(a), cb = Carrier(b);
      ca.other = cb;
      cb.other = ca;
      final created = <NovoRudpLanRoute>[];
      final left = NovoRudpRelayFrameLink(
        relay: ca,
        channel: channel,
        expectedPeer: b.peerId,
        enableLan: true,
        openLanRoute:
            ({required channel, required sendControl, required deliver}) async {
              final route = await NovoRudpLanRoute.open(
                channel: channel,
                sendControl: sendControl,
                deliver: deliver,
                observerHost: '',
                observerFallbacks: '',
              );
              created.add(route!);
              return route;
            },
      );
      final right = NovoRudpRelayFrameLink(
        relay: cb,
        channel: answer.channel,
        expectedPeer: a.peerId,
        enableLan: true,
        openLanRoute:
            ({required channel, required sendControl, required deliver}) =>
                NovoRudpLanRoute.open(
                  channel: channel,
                  sendControl: sendControl,
                  deliver: deliver,
                  observerHost: '',
                  observerFallbacks: '',
                ),
      );
      addTearDown(() async {
        await left.close();
        await right.close();
        await ca.events.close();
        await cb.events.close();
      });
      Future<void> until(bool Function() predicate) async {
        final time = Stopwatch()..start();
        while (!predicate() && time.elapsed < const Duration(seconds: 15)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(predicate(), isTrue);
      }

      final deliveries = <NovoRudpFrame>[];
      var direct = 0;
      final subscription = right.frames.listen(deliveries.add);
      final observations = right.receivedRoutes.listen((r) {
        if (r.direct) direct++;
      });
      addTearDown(subscription.cancel);
      addTearDown(observations.cancel);
      await until(() => left.directLanReady && right.directLanReady);
      // Wait beyond the route's initial advertisement burst, so recovery cannot
      // accidentally depend on startup announcements still being sent.
      await Future<void>.delayed(const Duration(seconds: 9));
      await created.single.close();
      expect(left.directLanReady, isFalse);
      NovoRudpFrame frame(int value) => NovoRudpFrame(
        kind: NovoRudpFrameKind.data,
        sessionId: channel.sessionId,
        streamId: BigInt.one,
        objectId: BigInt.one,
        sequence: BigInt.from(value),
        ackEpoch: BigInt.zero,
        payload: [value],
      );
      await left.send(frame(1));
      await until(() => deliveries.isNotEmpty);
      expect(direct, 0, reason: 'closed route falls back to carrier');
      await until(
        () =>
            created.length == 2 && left.directLanReady && right.directLanReady,
      );
      await left.send(frame(2));
      await until(() => deliveries.length == 2);
      expect(deliveries.last.payload, [2]);
      expect(direct, 1, reason: 'rebuilt route really carried UDP');
    },
    skip: !Platform.environment.containsKey('NOVORUDP_NATIVE_LIBRARY'),
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
