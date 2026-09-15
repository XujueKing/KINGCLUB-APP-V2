import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/nearby_text_channel.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_datagram_link.dart';
import 'package:kingclub/src/features/messaging/data/peer_text_failover.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_connection.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';

/// Explicit opt-in: actual upstream daemon, no fake WebSocket or relay.
void main() {
  sqfliteFfiInit();
  final env = Platform.environment;
  final enabled = [
    'SUPERVM_TEST_RELAY_URL',
    'SUPERVM_TEST_RELAY_PEER',
    'SUPERVM_TEST_RELAY_CERT',
    'NOVORUDP_NATIVE_LIBRARY',
  ].every(env.containsKey);
  test(
    'actual SUPERVM WSS forwards signed peer handshake and opaque encrypted data',
    () async {
      final lib = DynamicLibrary.open(env['NOVORUDP_NATIVE_LIBRARY']!);
      final random = Random.secure();
      NovoRudpSecureSession identity() {
        final value = NovoRudpSecureSession.fromSeed(
          library: lib,
          seed: Uint8List.fromList(
            List.generate(32, (_) => random.nextInt(256)),
          ),
        );
        addTearDown(value.dispose);
        return value;
      }

      final a = identity(), b = identity();
      final context = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(env['SUPERVM_TEST_RELAY_CERT']!);
      Future<({NovoRudpRelayConnection socket, StreamIterator<dynamic> events})>
      connect(NovoRudpSecureSession owner) async {
        final socket = NovoRudpRelayConnection(
          identity: owner,
          endpoint: Uri.parse(env['SUPERVM_TEST_RELAY_URL']!),
          expectedRelay: env['SUPERVM_TEST_RELAY_PEER']!,
          securityContext: context,
        );
        addTearDown(socket.close);
        final queue = StreamController<Map<String, dynamic>>();
        final subscription = socket.messages.listen(
          queue.add,
          onDone: queue.close,
        );
        addTearDown(subscription.cancel);
        final events = StreamIterator<dynamic>(queue.stream);
        addTearDown(events.cancel);
        await socket.connect();
        socket.heartbeat();
        await receive(events, 'heartbeat_ack');
        return (socket: socket, events: events);
      }

      final right = await connect(b), left = await connect(a);
      void send(
        NovoRudpRelayConnection socket,
        String kind,
        Map<String, dynamic> body,
      ) {
        if (kind == 'data') {
          socket.sendEnvelope(body);
        } else {
          socket.sendPeerHandshake(
            body['target_peer_id'] as String,
            body['handshake'] as Map<String, dynamic>,
          );
        }
      }

      final offer = a.start(b.peerId);
      send(left.socket, 'peer_handshake', {
        'target_peer_id': b.peerId,
        'handshake': {'kind': 'offer', 'body': offer.offer},
      });
      final deliveredOffer = await receive(
        right.events,
        'peer_handshake_delivery',
      );
      expect(deliveredOffer['source_peer_id'], a.peerId);
      expect(deliveredOffer['target_peer_id'], b.peerId);
      final accepted = b.respond(
        deliveredOffer['handshake']['body'] as Map<String, dynamic>,
        expectedPeer: a.peerId,
      );
      addTearDown(accepted.channel.close);
      send(right.socket, 'peer_handshake', {
        'target_peer_id': a.peerId,
        'handshake': {'kind': 'response', 'body': accepted.response},
      });
      final deliveredAnswer = await receive(
        left.events,
        'peer_handshake_delivery',
      );
      expect(deliveredAnswer['source_peer_id'], b.peerId);
      expect(deliveredAnswer['target_peer_id'], a.peerId);
      final channel = a.complete(
        offer,
        deliveredAnswer['handshake']['body'] as Map<String, dynamic>,
      );
      addTearDown(channel.close);
      final frame = NovoRudpFrame(
        kind: NovoRudpFrameKind.data,
        sessionId: channel.sessionId,
        streamId: BigInt.one,
        objectId: BigInt.one,
        sequence: BigInt.one,
        ackEpoch: BigInt.zero,
        payload: utf8.encode('synthetic private relay payload'),
      );
      final encrypted = await channel.seal(frame);
      send(left.socket, 'data', encrypted);
      final delivery = await receive(right.events, 'delivery');
      expect(delivery['source_peer_id'], a.peerId);
      expect(delivery['target_peer_id'], b.peerId);
      expect(delivery['envelope'], encrypted);
      final received = await accepted.channel.open(
        delivery['envelope'] as Map<String, dynamic>,
      );
      expect(received.payload, frame.payload);
      await expectLater(
        accepted.channel.open(delivery['envelope'] as Map<String, dynamic>),
        throwsStateError,
      );
      final wrongRelay = NovoRudpRelayConnection(
        identity: identity(),
        endpoint: Uri.parse(env['SUPERVM_TEST_RELAY_URL']!),
        expectedRelay: a.peerId,
        securityContext: context,
      );
      addTearDown(wrongRelay.close);
      final rejectedEvents = wrongRelay.messages.listen(
        (_) => fail('Untrusted relay delivered data'),
      );
      addTearDown(rejectedEvents.cancel);
      await expectLater(wrongRelay.connect(), throwsStateError);

      final directory = await Directory.systemTemp.createTemp('relay-text-');
      final key = await AesGcm.with256bits().newSecretKey();
      final ha = await ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: '${directory.path}/a.db',
        key: key,
        account: 'synthetic-a',
      );
      final hb = await ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: '${directory.path}/b.db',
        key: key,
        account: 'synthetic-b',
      );
      final ta = NearbyTextChannel(
        link: NovoRudpRelayFrameLink(
          relay: left.socket,
          channel: channel,
          expectedPeer: b.peerId,
        ),
        history: ha,
        peerId: b.peerId,
        canExchange: () => true,
      );
      final tb = NearbyTextChannel(
        link: NovoRudpRelayFrameLink(
          relay: right.socket,
          channel: accepted.channel,
          expectedPeer: a.peerId,
        ),
        history: hb,
        peerId: a.peerId,
        canExchange: () => true,
      );
      addTearDown(() async {
        await ta.close();
        await tb.close();
        await ha.close();
        await hb.close();
        await directory.delete(recursive: true);
      });
      const id = '11111111-1111-4111-8111-111111111111';
      final text = List.filled(350, 'relay text ').join();
      await ta
          .sendText(text, messageId: id)
          .timeout(const Duration(seconds: 10));
      expect((await hb.nearbyMessages(a.peerId)).single['text'], text);
      expect(await ha.nearbyMessages(b.peerId, pendingOnly: true), isEmpty);
      await ta
          .sendText(text, messageId: id)
          .timeout(const Duration(seconds: 10));
      expect((await hb.nearbyMessages(a.peerId)).length, 1);
      await tb
          .sendText('return receipt verified')
          .timeout(const Duration(seconds: 10));
      expect((await ha.nearbyMessages(b.peerId)).length, 2);

      // Actual direct UDP delivers the message, but a proxy drops every ACK.
      // The policy must switch to the actual WSS lane using the same journal ID.
      final udpA = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final udpB = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final proxy = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(proxy.close);
      final portA = udpA.port, portB = udpB.port;
      var droppedReceipts = 0;
      var dropReceipts = false;
      proxy.writeEventsEnabled = false;
      final pump = proxy.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? packet;
        while ((packet = proxy.receive()) != null) {
          if (packet!.port == portA) {
            proxy.send(packet.data, InternetAddress.loopbackIPv4, portB);
          } else if (packet.port == portB) {
            if (dropReceipts) {
              droppedReceipts++;
            } else {
              proxy.send(packet.data, InternetAddress.loopbackIPv4, portA);
            }
          }
        }
      });
      addTearDown(pump.cancel);
      final directOffer = a.start(b.peerId);
      final directAnswer = b.respond(directOffer.offer, expectedPeer: a.peerId);
      final directChannel = a.complete(directOffer, directAnswer.response);
      final directA = NearbyTextChannel(
        link: NovoRudpSecureDatagramLink.attach(
          socket: udpA,
          peer: InternetAddress.loopbackIPv4,
          peerPort: proxy.port,
          channel: directChannel,
        ),
        history: ha,
        peerId: b.peerId,
        canExchange: () => true,
      );
      final directB = NearbyTextChannel(
        link: NovoRudpSecureDatagramLink.attach(
          socket: udpB,
          peer: InternetAddress.loopbackIPv4,
          peerPort: proxy.port,
          channel: directAnswer.channel,
        ),
        history: hb,
        peerId: a.peerId,
        canExchange: () => true,
      );
      addTearDown(directB.close);
      var relayOpens = 0;
      final failover = PeerTextFailover(
        history: ha,
        peerId: b.peerId,
        canExchange: () => true,
        direct: directA,
        connectRelay: () async {
          relayOpens++;
          return ta;
        },
      );
      addTearDown(failover.close);
      expect(
        await failover.sendText(
          'direct receipt works',
          messageId: '33333333-3333-4333-8333-333333333333',
        ),
        PeerTextRoute.direct,
      );
      expect(relayOpens, 0);
      dropReceipts = true;
      const switchedId = '22222222-2222-4222-8222-222222222222';
      expect(
        await failover.sendText(
          'same message across routes',
          messageId: switchedId,
        ),
        PeerTextRoute.relay,
      );
      expect(droppedReceipts, greaterThan(0));
      expect(relayOpens, 1);
      final receivedRows = await hb.nearbyMessages(a.peerId);
      expect(receivedRows.where((row) => row['id'] == switchedId).length, 1);
      expect(await ha.nearbyMessages(b.peerId, pendingOnly: true), isEmpty);

      // Invalidate the generation before publishing a session event. The real
      // heartbeat timer must close both live connections without an async error.
      MemberQrMemory.clear();
      Future<void> waitClosed(StreamIterator<dynamic> events) async {
        var count = 0;
        while (await events.moveNext()) {
          // This observer also buffered the completed text exchanges above;
          // the peer links independently consumed and authenticated them.
          expect(events.current['kind'], anyOf('forward_outcome', 'delivery'));
          expect(++count, lessThan(128));
        }
      }

      await Future.wait([waitClosed(left.events), waitClosed(right.events)])
          .timeout(const Duration(seconds: 18));
    },
    skip: enabled
        ? false
        : 'Requires running SUPERVM relay and explicit local test trust',
  );
}

Future<Map<String, dynamic>> receive(
  StreamIterator<dynamic> events,
  String kind,
) async {
  return (() async {
    for (var i = 0; i < 16; i++) {
      if (!await events.moveNext()) {
        throw StateError('Relay closed before $kind');
      }
      final message = events.current as Map<String, dynamic>;
      if (message['kind'] == kind) {
        return (message['body'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
      }
      if (message['kind'] != 'forward_outcome' &&
          message['kind'] != 'heartbeat_ack') {
        throw StateError('Unexpected relay response');
      }
    }
    throw StateError('Relay response budget exceeded');
  })().timeout(const Duration(seconds: 5));
}
