import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_nat_socket.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  test('signed UDP discovery/punch retain ports for encrypted transfer and late retry', () async {
    final lib = DynamicLibrary.open(path!);
    final a = NovoRudpSecureSession.fromSeed(
      library: lib,
      seed: Uint8List.fromList(List.filled(32, 71)),
    );
    final b = NovoRudpSecureSession.fromSeed(
      library: lib,
      seed: Uint8List.fromList(List.filled(32, 81)),
    );
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final address = InternetAddress.loopbackIPv4;
    final left = NovoRudpNatSocket.attach(
      socket: await RawDatagramSocket.bind(address, 0),
      identity: a,
      expectedPeer: b.peerId,
    );
    final right = NovoRudpNatSocket.attach(
      socket: await RawDatagramSocket.bind(address, 0),
      identity: b,
      expectedPeer: a.peerId,
    );
    addTearDown(left.close);
    addTearDown(right.close);
    final leftPort = left.localPort, rightPort = right.localPort;
    expect(
      await left.probe(address, rightPort, punch: false),
      '127.0.0.1:$leftPort',
    );
    final offer = a.start(b.peerId);
    final accepted = b.respond(offer.offer, expectedPeer: a.peerId);
    final channel = a.complete(offer, accepted.response);
    expect(() => left.handoff(channel), throwsStateError);
    await Future.wait([
      left.probe(address, rightPort),
      right.probe(address, leftPort),
    ]);
    final r = right.handoff(accepted.channel);
    addTearDown(r.close);
    // A peer whose acknowledgement was lost retries after the other handoff.
    expect(await left.probe(address, rightPort), '127.0.0.1:$leftPort');
    final l = left.handoff(channel);
    addTearDown(l.close);
    expect(l.localPort, leftPort);
    expect(r.localPort, rightPort);
    expect(() => left.handoff(channel), throwsStateError);
    left.close();
    right.close(); // Former owners cannot close transferred sockets.
    final received = r.frames.first.timeout(const Duration(seconds: 3));
    await l.send(
      NovoRudpFrame(
        kind: NovoRudpFrameKind.data,
        sessionId: channel.sessionId,
        streamId: BigInt.one,
        objectId: BigInt.one,
        sequence: BigInt.one,
        ackEpoch: BigInt.zero,
        payload: [3, 1, 4],
      ),
    );
    expect((await received).payload, [3, 1, 4]);
  }, skip: path == null ? 'Requires real native library' : false);
}
