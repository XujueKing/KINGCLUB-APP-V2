import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/nearby_peer_connector.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  test('invalid signed answer fails immediately instead of retrying a consumed offer', () async {
    final lib = DynamicLibrary.open(path!);
    final identities =
        [31, 47]
            .map(
              (seed) => NovoRudpSecureSession.fromSeed(
                library: lib,
                seed: Uint8List.fromList(List.filled(32, seed)),
              ),
            )
            .toList()
          ..sort((a, b) => a.peerId.compareTo(b.peerId));
    for (final identity in identities) {
      addTearDown(identity.dispose);
    }
    final host = InternetAddress.loopbackIPv4;
    final responder = await RawDatagramSocket.bind(host, 0);
    addTearDown(responder.close);
    responder.writeEventsEnabled = false;
    var offers = 0;
    final events = responder.listen((event) {
      if (event != RawSocketEvent.read) return;
      final packet = responder.receive();
      if (packet == null) return;
      final request =
          jsonDecode(utf8.decode(packet.data)) as Map<String, dynamic>;
      offers++;
      final accepted = identities[1].respond(
        request['offer'] as Map<String, dynamic>,
        expectedPeer: identities[0].peerId,
      );
      accepted.channel.close();
      final response = accepted.response;
      (response['signature'] as List)[0] ^= 1;
      responder.send(
        utf8.encode(
          jsonEncode({
            'kind': 'kingclub_nearby_answer_v1',
            'id': request['id'],
            'response': response,
          }),
        ),
        packet.address,
        packet.port,
      );
    });
    addTearDown(events.cancel);
    final connector = NearbyPeerConnector(
      socket: await RawDatagramSocket.bind(host, 0),
      identity: identities[0],
      expectedPeer: identities[1].peerId,
      address: host,
      port: responder.port,
    );
    addTearDown(connector.close);
    await expectLater(
      connector.connect().timeout(const Duration(seconds: 2)),
      throwsStateError,
    );
    expect(offers, 1);
    expect(connector.connect, throwsStateError);
  }, skip: path == null ? 'Requires real native library' : false);
  test(
    'offline UDP handshake recovers lost response and transfers encrypted data',
    () async {
      final lib = DynamicLibrary.open(path!);
      final a = NovoRudpSecureSession.fromSeed(
        library: lib,
        seed: Uint8List.fromList(List.filled(32, 31)),
      );
      final b = NovoRudpSecureSession.fromSeed(
        library: lib,
        seed: Uint8List.fromList(List.filled(32, 47)),
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final host = InternetAddress.loopbackIPv4;
      final sa = await RawDatagramSocket.bind(host, 0),
          sb = await RawDatagramSocket.bind(host, 0);
      final ap = sa.port, bp = sb.port;
      final proxy = await RawDatagramSocket.bind(host, 0);
      addTearDown(proxy.close);
      var dropped = false;
      proxy.writeEventsEnabled = false;
      final forwarding = proxy.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? packet;
        while ((packet = proxy.receive()) != null) {
          final p = packet!;
          if (p.port != ap && p.port != bp) continue;
          if (!dropped) {
            try {
              final message = jsonDecode(utf8.decode(p.data));
              if (message is Map &&
                  message['kind'] == 'kingclub_nearby_answer_v1') {
                dropped = true;
                continue;
              }
            } on FormatException {
              /* Encrypted payload is forwarded without inspection. */
            }
          }
          proxy.send(p.data, host, p.port == ap ? bp : ap);
        }
      });
      addTearDown(forwarding.cancel);
      final left = NearbyPeerConnector(
        socket: sa,
        identity: a,
        expectedPeer: b.peerId,
        address: host,
        port: proxy.port,
      );
      final right = NearbyPeerConnector(
        socket: sb,
        identity: b,
        expectedPeer: a.peerId,
        address: host,
        port: proxy.port,
      );
      addTearDown(left.close);
      addTearDown(right.close);
      final links = await Future.wait([left.connect(), right.connect()])
          .timeout(const Duration(seconds: 5));
      for (final link in links) {
        addTearDown(link.close);
      }
      expect(dropped, isTrue);
      expect(links[0].channel.sessionId, links[1].channel.sessionId);
      expect(links[0].localPort, ap);
      expect(links[1].localPort, bp);
      left.close();
      right.close();
      final incoming = links[1].frames.first.timeout(
        const Duration(seconds: 3),
      );
      await links[0].send(
        NovoRudpFrame(
          kind: NovoRudpFrameKind.data,
          sessionId: links[0].channel.sessionId,
          streamId: BigInt.one,
          objectId: BigInt.one,
          sequence: BigInt.one,
          ackEpoch: BigInt.zero,
          payload: [7, 9, 1],
        ),
      );
      expect((await incoming).payload, [7, 9, 1]);
      final pending = NearbyPeerConnector(
        socket: await RawDatagramSocket.bind(host, 0),
        identity: a,
        expectedPeer: b.peerId,
        address: host,
        port: proxy.port,
      );
      final result = pending.connect();
      final assertion = expectLater(result, throwsStateError);
      pending.close();
      await assertion;
    },
    skip: path == null ? 'Requires real native library' : false,
  );
}
