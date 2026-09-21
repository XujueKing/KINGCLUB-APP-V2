import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_lan_route.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_packet.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  for (final unknownAddress in [false, true]) {
    test(
      'authenticated observed endpoint unknownAddress=$unknownAddress needs return probe',
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
          seed: Uint8List.fromList(List.filled(32, 43)),
        );
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        final offer = a.start(b.peerId);
        final answer = b.respond(offer.offer, expectedPeer: a.peerId);
        final channel = a.complete(offer, answer.response);
        addTearDown(channel.close);
        addTearDown(answer.channel.close);
        // This held socket represents the advertised mapping. The actual peer
        // will transmit from a different socket on the same interface.
        final advertised = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );
        advertised.writeEventsEnabled = false;
        final sub = advertised.listen((event) {
          if (event == RawSocketEvent.read) {
            while (advertised.receive() != null) {}
          }
        });
        addTearDown(() async {
          await sub.cancel();
          advertised.close();
        });
        Map? leftAddress;
        final received = <NovoRudpFrame>[];
        final left = (await NovoRudpLanRoute.open(
          channel: channel,
          sendControl: (frame) async {
            leftAddress = jsonDecode(utf8.decode(frame.payload)) as Map;
          },
          deliver: (frame) async {
            received.add(frame);
          },
        ))!;
        addTearDown(left.close);
        await left.advertise();
        final addresses = leftAddress!['addresses'] as List;
        expect(
          addresses,
          isNotEmpty,
          reason: 'native integration requires a private IPv4 interface',
        );
        final target = InternetAddress(addresses.first as String);
        final port = leftAddress!['port'] as int;
        NovoRudpFrame control(Map<String, Object> body) => NovoRudpFrame(
          kind: NovoRudpFrameKind.data,
          sessionId: channel.sessionId,
          streamId: NovoRudpLanRoute.controlStream,
          objectId: BigInt.zero,
          sequence: BigInt.zero,
          ackEpoch: BigInt.zero,
          payload: utf8.encode(jsonEncode(body)),
        );
        await left.acceptControl(
          control({
            'op': 'endpoint',
            'addresses': unknownAddress ? <String>[] : addresses,
            'port': advertised.port,
          }),
        );
        final actual = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        actual.writeEventsEnabled = false;
        addTearDown(actual.close);
        final challenge = Completer<NovoRudpFrame>();
        final actualSub = actual.listen((event) async {
          if (event != RawSocketEvent.read) return;
          final packet = actual.receive();
          if (packet == null) return;
          final frame = await answer.channel.open(
            NovoRudpSecurePacket.decode(packet.data),
          );
          final body = jsonDecode(utf8.decode(frame.payload)) as Map;
          if (body['op'] == 'ping' && !challenge.isCompleted) {
            challenge.complete(frame);
          }
        });
        addTearDown(actualSub.cancel);
        // Junk from an unadvertised port must not establish a route.
        actual.send(Uint8List(150), target, port);
        final forged = NovoRudpSecurePacket.encode(
          await answer.channel.seal(control({'op': 'ping', 'nonce': 'c' * 32})),
        );
        forged[forged.length - 1] ^= 1;
        actual.send(forged, target, port);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(left.ready, isFalse);
        expect(challenge.isCompleted, isFalse);
        Future<void> send(NovoRudpFrame frame) async {
          actual.send(
            NovoRudpSecurePacket.encode(await answer.channel.seal(frame)),
            target,
            port,
          );
        }

        // Even authenticated application data from an unconfirmed endpoint must
        // not be delivered or establish readiness.
        await send(
          NovoRudpFrame(
            kind: NovoRudpFrameKind.data,
            sessionId: channel.sessionId,
            streamId: BigInt.one,
            objectId: BigInt.one,
            sequence: BigInt.zero,
            ackEpoch: BigInt.zero,
            payload: [99],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(received, isEmpty);
        expect(left.ready, isFalse);
        await send(control({'op': 'ping', 'nonce': 'a' * 32}));
        final probe = await challenge.future.timeout(
          const Duration(seconds: 2),
        );
        expect(
          left.ready,
          isFalse,
          reason: 'valid incoming ping alone proves no return path',
        );
        final body = jsonDecode(utf8.decode(probe.payload)) as Map;
        await send(control({'op': 'pong', 'nonce': 'b' * 32}));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          left.ready,
          isFalse,
          reason: 'wrong nonce cannot confirm observed endpoint',
        );
        await send(control({'op': 'pong', 'nonce': body['nonce'] as String}));
        final wait = Stopwatch()..start();
        while (!left.ready && wait.elapsed < const Duration(seconds: 2)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(left.ready, isTrue);
        await send(
          NovoRudpFrame(
            kind: NovoRudpFrameKind.data,
            sessionId: channel.sessionId,
            streamId: BigInt.one,
            objectId: BigInt.one,
            sequence: BigInt.zero,
            ackEpoch: BigInt.zero,
            payload: [7, 8, 9],
          ),
        );
        wait.reset();
        while (received.isEmpty && wait.elapsed < const Duration(seconds: 2)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(received.single.payload, [7, 8, 9]);
      },
      skip: !Platform.environment.containsKey('NOVORUDP_NATIVE_LIBRARY'),
    );
  }
}
