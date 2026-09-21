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
  for (final respond in [false, true]) {
    test(
      'bounded real UDP burst with dropped/delayed reply respond=$respond',
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
          seed: Uint8List.fromList(List.filled(32, 97)),
        );
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        final offer = a.start(b.peerId);
        final answer = b.respond(offer.offer, expectedPeer: a.peerId);
        final channel = a.complete(offer, answer.response);
        addTearDown(channel.close);
        addTearDown(answer.channel.close);
        final peer = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        peer.writeEventsEnabled = false;
        addTearDown(peer.close);
        Map? advertised;
        final route = (await NovoRudpLanRoute.open(
          channel: channel,
          sendControl: (frame) async {
            advertised = jsonDecode(utf8.decode(frame.payload)) as Map;
          },
          deliver: (_) async {},
          observerHost: '',
          observerFallbacks: '',
        ))!;
        addTearDown(route.close);
        await route.advertise();
        final addresses = advertised!['addresses'] as List;
        expect(addresses, isNotEmpty);
        NovoRudpFrame control(Map<String, Object> body) => NovoRudpFrame(
          kind: NovoRudpFrameKind.data,
          sessionId: channel.sessionId,
          streamId: NovoRudpLanRoute.controlStream,
          objectId: BigInt.zero,
          sequence: BigInt.zero,
          ackEpoch: BigInt.zero,
          payload: utf8.encode(jsonEncode(body)),
        );
        var count = 0;
        final nonceValues = <String>{};
        Future<void>? reply;
        final subscription = peer.listen((event) async {
          if (event != RawSocketEvent.read) return;
          final packet = peer.receive();
          if (packet == null) return;
          final frame = await answer.channel.open(
            NovoRudpSecurePacket.decode(packet.data),
          );
          final body = jsonDecode(utf8.decode(frame.payload)) as Map;
          if (body['op'] != 'ping') return;
          count++;
          nonceValues.add(body['nonce'] as String);
          // First two probes are lost; reply arrives after another retry was sent.
          if (respond && count == 3) {
            reply = () async {
              await Future<void>.delayed(const Duration(milliseconds: 350));
              final wire = NovoRudpSecurePacket.encode(
                await answer.channel.seal(
                  control({'op': 'pong', 'nonce': body['nonce'] as String}),
                ),
              );
              peer.send(wire, packet.address, packet.port);
            }();
          }
        });
        addTearDown(() async {
          await reply;
          await subscription.cancel();
        });
        final endpoint = control({
          'op': 'endpoint',
          'addresses': [addresses.first],
          'port': peer.port,
        });
        await route.acceptControl(endpoint);
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        expect(route.ready, respond);
        expect(
          nonceValues.length,
          1,
          reason: 'retries retain the unexpired challenge',
        );
        if (respond) {
          expect(count, inInclusiveRange(3, 5));
        } else {
          expect(count, 6, reason: 'one immediate plus five retry probes');
        }
        await route.close();
        final closedCount = count;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(count, closedCount);
      },
      skip: !Platform.environment.containsKey('NOVORUDP_NATIVE_LIBRARY'),
    );
  }
}
