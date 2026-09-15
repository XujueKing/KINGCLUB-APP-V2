import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';

/// Explicit opt-in: actual upstream daemon, no fake WebSocket or relay.
void main() {
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
      Future<({WebSocket socket, StreamIterator<dynamic> events})> connect(
        NovoRudpSecureSession owner,
      ) async {
        final http = HttpClient(context: context);
        addTearDown(() => http.close(force: true));
        final socket = await WebSocket.connect(
          env['SUPERVM_TEST_RELAY_URL']!,
          customClient: http,
          compression: CompressionOptions.compressionOff,
        ).timeout(const Duration(seconds: 5));
        addTearDown(socket.close);
        final events = StreamIterator<dynamic>(socket);
        addTearDown(events.cancel);
        final offer = owner.start(env['SUPERVM_TEST_RELAY_PEER']!);
        socket.add(
          utf8.encode(
            jsonEncode({'kind': 'handshake_offer', 'body': offer.offer}),
          ),
        );
        final response = await receive(events, 'handshake_response');
        owner.complete(offer, response).close();
        return (socket: socket, events: events);
      }

      final right = await connect(b), left = await connect(a);
      void send(WebSocket socket, String kind, Map<String, dynamic> body) =>
          socket.add(utf8.encode(jsonEncode({'kind': kind, 'body': body})));
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
      final wire = events.current;
      if (wire is! List<int> || wire.length > 16384) {
        throw StateError('Invalid relay frame');
      }
      final message = jsonDecode(utf8.decode(wire)) as Map<String, dynamic>;
      if (message['kind'] == kind) {
        return message['body'] as Map<String, dynamic>;
      }
      if (message['kind'] != 'forward_outcome' &&
          message['kind'] != 'heartbeat_ack') {
        throw StateError('Unexpected relay response');
      }
    }
    throw StateError('Relay response budget exceeded');
  })().timeout(const Duration(seconds: 5));
}
