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
            } on FormatException {}
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
