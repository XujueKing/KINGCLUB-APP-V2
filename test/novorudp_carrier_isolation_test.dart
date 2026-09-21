import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_lan_route.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  for (final pending in [false, true]) {
    test(
      'UDP survives carrier pending=$pending without readiness flicker',
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
          seed: Uint8List.fromList(List.filled(32, 91)),
        );
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        final offer = a.start(b.peerId);
        final answer = b.respond(offer.offer, expectedPeer: a.peerId);
        final channel = a.complete(offer, answer.response);
        addTearDown(channel.close);
        addTearDown(answer.channel.close);
        NovoRudpLanRoute? left, right;
        var disrupted = false, attempts = 0;
        final gate = Completer<void>();
        final received = <NovoRudpFrame>[];
        Future<void> control(
          NovoRudpLanRoute? peer,
          NovoRudpFrame frame,
        ) async {
          if (disrupted) {
            attempts++;
            if (pending) return gate.future;
            throw const SocketException('carrier unavailable');
          }
          // Asynchronous carrier delivery; UDP packets still use native AEAD.
          scheduleMicrotask(() {
            unawaited(peer?.acceptControl(frame));
          });
        }

        left = await NovoRudpLanRoute.open(
          channel: channel,
          sendControl: (frame) => control(right, frame),
          deliver: (_) async {},
          observerHost: '',
          observerFallbacks: '',
        );
        right = await NovoRudpLanRoute.open(
          channel: answer.channel,
          sendControl: (frame) => control(left, frame),
          deliver: (frame) async {
            received.add(frame);
          },
          observerHost: '',
          observerFallbacks: '',
        );
        addTearDown(() async {
          await left?.close();
          await right?.close();
          gate.complete();
        });
        await left!.advertise();
        await right!.advertise();
        final startup = Stopwatch()..start();
        while (!(left.ready && right.ready) &&
            startup.elapsedMilliseconds < 5000) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(left.ready && right.ready, isTrue);
        disrupted = true;
        // Exceeds the six-second UDP heartbeat expiry and all startup announces.
        final watch = Stopwatch()..start();
        while (watch.elapsed < const Duration(seconds: 9)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(
            left.ready && right.ready,
            isTrue,
            reason: 'carrier failure must not suppress UDP heartbeats',
          );
        }
        expect(attempts, greaterThan(0));
        if (pending) {
          expect(attempts, 2, reason: 'one pending announcement per peer');
        }
        expect(
          await left.trySend(
            NovoRudpFrame(
              kind: NovoRudpFrameKind.data,
              sessionId: channel.sessionId,
              streamId: BigInt.one,
              objectId: BigInt.one,
              sequence: BigInt.one,
              ackEpoch: BigInt.zero,
              payload: [42],
            ),
          ),
          isTrue,
        );
        final delivery = Stopwatch()..start();
        while (received.isEmpty && delivery.elapsedMilliseconds < 2000) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(received.single.payload, [42]);
      },
      skip: !Platform.environment.containsKey('NOVORUDP_NATIVE_LIBRARY'),
      timeout: const Timeout(Duration(seconds: 20)),
    );
  }
}
