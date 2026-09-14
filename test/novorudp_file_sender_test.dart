import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_receiver.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_sender.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_datagram_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  group('real encrypted UDP file transfer', () {
    late Directory directory;
    late NovoRudpSecureSession a, b;
    late NovoRudpSecureDatagramLink left, right;
    late RawDatagramSocket relay;
    late StreamSubscription relaySub;
    var packets = 0, dropped = 0, dropFinal = false, loss = false;
    setUp(() async {
      packets = dropped = 0;
      dropFinal = loss = false;
      directory = await Directory.systemTemp.createTemp(
        'kingclub-sender-test-',
      );
      final library = DynamicLibrary.open(path!);
      a = NovoRudpSecureSession.fromSeed(library: library, seed: Uint8List(32));
      b = NovoRudpSecureSession.fromSeed(
        library: library,
        seed: Uint8List.fromList(List.filled(32, 17)),
      );
      final init = a.start(b.peerId);
      final response = b.respond(init.offer, expectedPeer: a.peerId);
      final address = InternetAddress.loopbackIPv4;
      relay = await RawDatagramSocket.bind(address, 0);
      final l = await RawDatagramSocket.bind(address, 0);
      final r = await RawDatagramSocket.bind(address, 0);
      left = NovoRudpSecureDatagramLink.attach(
        socket: l,
        peer: address,
        peerPort: relay.port,
        channel: a.complete(init, response.response),
      );
      right = NovoRudpSecureDatagramLink.attach(
        socket: r,
        peer: address,
        peerPort: relay.port,
        channel: response.channel,
      );
      relay.writeEventsEnabled = false;
      relaySub = relay.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? packet;
        while ((packet = relay.receive()) != null) {
          packets++;
          final reverse = packet!.port == right.localPort;
          if (loss &&
              ((!reverse && packets % 7 == 0) || (reverse && dropFinal))) {
            if (reverse) dropFinal = false;
            dropped++;
            continue;
          }
          final sent = relay.send(
            packet.data,
            address,
            reverse ? left.localPort : right.localPort,
          );
          if (sent == 0) dropped++;
        }
      });
    });
    tearDown(() async {
      await left.close();
      await right.close();
      await relaySub.cancel();
      relay.close();
      a.dispose();
      b.dispose();
      await directory.delete(recursive: true);
    });
    Future<({File file, String hash})> source(List<int> bytes) async {
      final file = await File('${directory.path}/source.bin')
          .writeAsBytes(bytes);
      final hash = (await const DartSha256().hash(bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      return (file: file, hash: hash);
    }

    test(
      'dropped data and final ACK recover without duplicate file delivery',
      () async {
        loss = true;
        final bytes = List.generate(
          70 * NovoRudpFileReceiver.chunkSize + 21,
          (i) => i % 251,
        );
        final input = await source(bytes);
        final receiver = await NovoRudpFileReceiver.create(
          privateDirectory: directory,
          sessionId: left.channel.sessionId,
          streamId: BigInt.one,
          objectId: BigInt.two,
          size: bytes.length,
          sha256: input.hash,
        );
        addTearDown(receiver.close);
        var finalAcks = 0;
        final errors = <Object>[];
        final sub = right.frames.listen((frame) async {
          try {
            final ack = await receiver.receiveAuthenticated(frame);
            if (ack == null) return;
            if ((jsonDecode(utf8.decode(ack.payload))
                    as Map)['receiver_done'] ==
                true) {
              finalAcks++;
              if (finalAcks == 1) dropFinal = true;
            }
            // Local-buffer failure is not an acknowledged send; the sender's
            // ACK request timer recovers it just like an actually dropped ACK.
            try {
              await right.send(ack);
            } on SocketException {
              // A subsequent ACK request retries a locally unaccepted send.
            }
          } catch (error) {
            errors.add(error);
          }
        });
        addTearDown(sub.cancel);
        final sender = NovoRudpFileSender(
          link: left,
          file: input.file,
          streamId: BigInt.one,
          objectId: BigInt.two,
          size: bytes.length,
          sha256: input.hash,
          ackWait: const Duration(milliseconds: 150),
          deadline: const Duration(seconds: 15),
        );
        await sender.run();
        expect(errors, isEmpty);
        expect(dropped, greaterThan(0));
        expect(finalAcks, greaterThanOrEqualTo(2));
        expect(await (await receiver.verifiedFile()).readAsBytes(), bytes);
        await expectLater(sender.run(), throwsStateError);
      },
    );
    test(
      'unreachable receiver times out and cancellation wakes ACK wait',
      () async {
        final input = await source([1, 2, 3]);
        NovoRudpFileSender sender() => NovoRudpFileSender(
          link: left,
          file: input.file,
          streamId: BigInt.one,
          objectId: BigInt.two,
          size: 3,
          sha256: input.hash,
          ackWait: const Duration(milliseconds: 30),
          maxStalls: 2,
        );
        await expectLater(sender().run(), throwsA(isA<TimeoutException>()));
        final cancelled = sender();
        final running = cancelled.run();
        Timer(const Duration(milliseconds: 10), cancelled.cancel);
        await expectLater(running, throwsStateError);
      },
    );
    test('changed source fails before any datagram leaves', () async {
      final input = await source([1, 2, 3]);
      await input.file.writeAsBytes([3, 2, 1]);
      final sender = NovoRudpFileSender(
        link: left,
        file: input.file,
        streamId: BigInt.one,
        objectId: BigInt.two,
        size: 3,
        sha256: input.hash,
      );
      await expectLater(sender.run(), throwsFormatException);
      expect(packets, 0);
    });
  }, skip: path == null ? 'Set NOVORUDP_NATIVE_LIBRARY' : false);
}
