import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_datagram_link.dart';

NovoRudpFrame data({int session = 0x42, int size = 5}) => NovoRudpFrame(
  kind: NovoRudpFrameKind.data,
  sessionId: List.filled(16, session),
  streamId: (BigInt.one << 64) - BigInt.one,
  objectId: BigInt.one << 63,
  sequence: BigInt.from(99),
  ackEpoch: BigInt.one,
  payload: List.filled(size, 123),
);
void main() {
  test('fixed peer and session reject wrong source, malformed and different session packets', () async {
    final peer = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final stranger = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(peer.close);
    addTearDown(stranger.close);
    final link = await NovoRudpDatagramLink.bind(
      peer: InternetAddress.loopbackIPv4,
      peerPort: peer.port,
      sessionId: List.filled(16, 0x42),
      localAddress: InternetAddress.loopbackIPv4,
    );
    addTearDown(link.close);
    final result = link.frames.first.timeout(const Duration(seconds: 3));
    stranger.send(
      await data().encode(),
      InternetAddress.loopbackIPv4,
      link.localPort,
    );
    peer.send(Uint8List(100), InternetAddress.loopbackIPv4, link.localPort);
    peer.send(
      await data(session: 1).encode(),
      InternetAddress.loopbackIPv4,
      link.localPort,
    );
    final expected = data(size: 7);
    peer.send(
      await expected.encode(),
      InternetAddress.loopbackIPv4,
      link.localPort,
    );
    expect((await result).payload.length, 7);
    await expectLater(link.send(data(size: 1105)), throwsArgumentError);
    await expectLater(link.send(data(session: 1)), throwsArgumentError);
    await link.close();
    await expectLater(link.send(data()), throwsStateError);
    await link.close();
  });
  final rust = Platform.environment['NOVORUDP_FIXTURE_EXE'];
  test(
    'Dart socket sends actual UDP frame to Rust decoder and receives Rust ACK',
    () async {
      final process = await Process.start(rust!, ['udp']);
      final errors = process.stderr.transform(utf8.decoder).join();
      addTearDown(() {
        process.kill();
      });
      final portLine = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first;
      final link = await NovoRudpDatagramLink.bind(
        peer: InternetAddress.loopbackIPv4,
        peerPort: int.parse(portLine),
        sessionId: List.filled(16, 0x42),
        localAddress: InternetAddress.loopbackIPv4,
      );
      addTearDown(link.close);
      final response = link.frames.first.timeout(const Duration(seconds: 5));
      final sent = data();
      await link.send(sent);
      final ack = await response;
      expect(ack.kind, NovoRudpFrameKind.ack);
      expect(ack.streamId, sent.streamId);
      expect(ack.objectId, sent.objectId);
      expect(ack.sequence, sent.sequence);
      expect(ack.ackEpoch, sent.ackEpoch);
      expect(ack.payload, sent.payload);
      expect(await process.exitCode, 0, reason: await errors);
    },
    skip: rust == null
        ? 'Build Rust fixture and set NOVORUDP_FIXTURE_EXE'
        : false,
  );
}
