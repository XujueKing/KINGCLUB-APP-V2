import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_receiver.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
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

    for (final transferBytes in [
      70 * NovoRudpFileReceiver.chunkSize + 21,
      18 * 1024 * 1024,
    ]) {
      test(
        'dropped data and final ACK recover without duplicate file delivery ($transferBytes bytes)',
        () async {
          loss = true;
          final bytes = List.generate(transferBytes, (i) => i % 251);
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
            deadline: const Duration(seconds: 90),
          );
          final elapsed = Stopwatch()..start();
          await sender.run();
          debugPrint(
            'NOVORUDP_LOOPBACK_FILE bytes=$transferBytes elapsedMs=${elapsed.elapsedMilliseconds} packets=$packets dropped=$dropped',
          );
          expect(errors, isEmpty);
          expect(dropped, greaterThan(0));
          expect(finalAcks, greaterThanOrEqualTo(2));
          expect(await (await receiver.verifiedFile()).readAsBytes(), bytes);
          await expectLater(sender.run(), throwsStateError);
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }
    test(
      'new sender resumes live partial receiver without another data pass',
      () async {
        final bytes = List.generate(
          80 * NovoRudpFileReceiver.chunkSize,
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
        final half = Completer<void>();
        var dataFrames = 0, repairFrames = 0;
        final errors = <Object>[];
        final sub = right.frames.listen((frame) async {
          try {
            final ack = await receiver.receiveAuthenticated(frame);
            if (frame.kind == NovoRudpFrameKind.data) {
              if (++dataFrames == 40) half.complete();
            }
            if (frame.kind == NovoRudpFrameKind.repair) {
              repairFrames++;
              expect(frame.sequence.toInt(), greaterThanOrEqualTo(40));
            }
            if (ack != null) await right.send(ack);
          } catch (e) {
            errors.add(e);
          }
        });
        addTearDown(sub.cancel);
        for (var i = 0; i < 40; i++) {
          await left.send(
            NovoRudpFrame(
              kind: NovoRudpFrameKind.data,
              sessionId: left.channel.sessionId,
              streamId: BigInt.one,
              objectId: BigInt.two,
              sequence: BigInt.from(i),
              ackEpoch: BigInt.zero,
              payload: bytes.sublist(
                i * NovoRudpFileReceiver.chunkSize,
                (i + 1) * NovoRudpFileReceiver.chunkSize,
              ),
            ),
          );
        }
        await half.future.timeout(const Duration(seconds: 3));
        NovoRudpFileSender sender() => NovoRudpFileSender(
          link: left,
          file: input.file,
          streamId: BigInt.one,
          objectId: BigInt.two,
          size: bytes.length,
          sha256: input.hash,
          ackWait: const Duration(milliseconds: 150),
        );
        await sender().run();
        expect(errors, isEmpty);
        expect(dataFrames, 40);
        expect(repairFrames, greaterThan(0));
        expect(await (await receiver.verifiedFile()).readAsBytes(), bytes);
        final repaired = repairFrames;
        await sender().run();
        expect(dataFrames, 40);
        expect(repairFrames, repaired);
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
    test(
      'account change stops a pending transfer and releases its source',
      () async {
        final input = await source([1, 2, 3]);
        final sender = NovoRudpFileSender(
          link: left,
          file: input.file,
          streamId: BigInt.one,
          objectId: BigInt.two,
          size: 3,
          sha256: input.hash,
          ackWait: const Duration(minutes: 1),
        );
        final running = sender.run();
        final switched = Timer(const Duration(milliseconds: 20), () {
          MemberQrMemory.clear();
          SecureSessionStore.changes.add(null);
        });
        addTearDown(switched.cancel);
        await expectLater(
          running.timeout(const Duration(seconds: 2)),
          throwsStateError,
        );
        final sent = packets;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(packets, sent);
        final renamed = await input.file.rename(
          '${directory.path}/released.bin',
        );
        expect(await renamed.readAsBytes(), [1, 2, 3]);
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
