import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_datagram_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_packet.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  group(
    'actual encrypted UDP with upstream Rust',
    () {
      late NovoRudpSecureSession a, b;
      late NovoRudpSecureChannel sender, receiver;
      late RawDatagramSocket peer;
      late NovoRudpSecureDatagramLink link;
      final address = InternetAddress.loopbackIPv4;
      setUp(() async {
        final library = DynamicLibrary.open(path!);
        a = NovoRudpSecureSession.fromSeed(
          library: library,
          seed: Uint8List.fromList(List.filled(32, 31)),
        );
        b = NovoRudpSecureSession.fromSeed(
          library: library,
          seed: Uint8List.fromList(List.filled(32, 47)),
        );
        final start = a.start(b.peerId);
        final response = b.respond(start.offer, expectedPeer: a.peerId);
        sender = a.complete(start, response.response);
        receiver = response.channel;
        peer = await RawDatagramSocket.bind(address, 0);
        link = NovoRudpSecureDatagramLink.attach(
          socket: await RawDatagramSocket.bind(address, 0),
          peer: address,
          peerPort: peer.port,
          channel: sender,
        );
      });
      tearDown(() async {
        await link.close();
        peer.close();
        a.dispose();
        b.dispose();
      });
      NovoRudpFrame frame(int value, {int size = 4}) => NovoRudpFrame(
        kind: NovoRudpFrameKind.data,
        sessionId: sender.sessionId,
        streamId: (BigInt.one << 64) - BigInt.one,
        objectId: BigInt.one << 63,
        sequence: BigInt.from(value),
        ackEpoch: BigInt.zero,
        payload: List.filled(size, value),
      );

      test('1200-byte encrypted packet crosses socket and decodes in Rust', () async {
        final packet = Completer<Datagram>();
        final sub = peer.listen((event) {
          if (event == RawSocketEvent.read) {
            final value = peer.receive();
            if (value != null && !packet.isCompleted) packet.complete(value);
          }
        });
        addTearDown(sub.cancel);
        final sent = frame(23, size: NovoRudpSecurePacket.maxFramePayload);
        await link.send(sent);
        final wire = (await packet.future.timeout(const Duration(seconds: 3)))
            .data;
        expect(wire.length, 1200);
        final opened = await receiver.open(NovoRudpSecurePacket.decode(wire));
        expect(await opened.encode(), await sent.encode());
        await expectLater(
          link.send(frame(1, size: NovoRudpSecurePacket.maxFramePayload + 1)),
          throwsArgumentError,
        );
        // The packet has authenticated ciphertext, not a plain NOVRUDP0 frame.
        await expectLater(NovoRudpFrame.decode(wire), throwsFormatException);
        final response = link.frames.first.timeout(const Duration(seconds: 3));
        peer.send(
          NovoRudpSecurePacket.encode(await receiver.seal(frame(24))),
          address,
          link.localPort,
        );
        expect((await response).payload, List.filled(4, 24));
      });

      test('wrong source, malformed, tampered and replay packets never deliver', () async {
        final stranger = await RawDatagramSocket.bind(address, 0);
        addTearDown(stranger.close);
        final first = NovoRudpSecurePacket.encode(
          await receiver.seal(frame(41)),
        );
        final finalPacket = NovoRudpSecurePacket.encode(
          await receiver.seal(frame(42)),
        );
        final seen = <int>[];
        final done = Completer<void>();
        final sub = link.frames.listen((f) {
          seen.add(f.payload.first);
          if (f.payload.first == 42) done.complete();
        });
        addTearDown(sub.cancel);
        Future<void> deliver(RawDatagramSocket socket, Uint8List bytes) async {
          // Windows may briefly return zero while its UDP send buffer is busy.
          // Retry only unsent datagrams, not already accepted packets.
          for (var attempt = 0; attempt < 100; attempt++) {
            if (socket.send(bytes, address, link.localPort) == bytes.length) {
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          fail('UDP test sender remained blocked');
        }

        await deliver(stranger, first);
        await deliver(peer, Uint8List(20));
        await deliver(peer, Uint8List(1201));
        final tampered = Uint8List.fromList(first)..[first.length - 1] ^= 1;
        await deliver(peer, tampered);
        await deliver(peer, first);
        await deliver(peer, first);
        await deliver(peer, finalPacket);
        await done.future.timeout(const Duration(seconds: 3));
        expect(seen, [41, 42]);
      });

      test(
        'logout during async seal closes socket and native channel',
        () async {
          final pending = link.send(frame(1));
          MemberQrMemory.clear();
          await expectLater(pending, throwsStateError);
          await link.close();
          await link.close();
          await expectLater(sender.seal(frame(2)), throwsStateError);
          await expectLater(link.send(frame(2)), throwsStateError);
        },
      );

      test(
        'carrier rejects unsupported versions, lengths and sequence overflow',
        () async {
          final envelope = await receiver.seal(frame(1));
          final wire = NovoRudpSecurePacket.encode(envelope);
          expect(
            NovoRudpSecurePacket.encode(NovoRudpSecurePacket.decode(wire)),
            wire,
          );
          for (final offset in [0, 8, 110]) {
            final corrupt = Uint8List.fromList(wire);
            corrupt[offset] ^= 1;
            expect(
              () => NovoRudpSecurePacket.decode(corrupt),
              throwsFormatException,
            );
          }
          final overflow = Uint8List.fromList(wire)..[97] = 128;
          expect(
            () => NovoRudpSecurePacket.decode(overflow),
            throwsFormatException,
          );
          expect(
            () => NovoRudpSecurePacket.encode({
              ...envelope,
              'sender_peer_id': 'unknown',
            }),
            throwsFormatException,
          );
          expect(
            () => NovoRudpSecurePacket.encode({
              ...envelope,
              'nonce': [256],
            }),
            throwsFormatException,
          );
        },
      );
    },
    skip: path == null
        ? 'Set NOVORUDP_NATIVE_LIBRARY to the built upstream library'
        : false,
  );
}
