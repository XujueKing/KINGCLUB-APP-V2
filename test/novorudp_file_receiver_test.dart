import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_receiver.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  group('disk receiver with real upstream encryption and repair', () {
    late Directory root;
    late NovoRudpSecureSession a, b;
    late NovoRudpSecureChannel tx, rx;
    final receivers = <NovoRudpFileReceiver>[];
    final object = BigInt.one << 63;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('kingclub-receive-test-');
      final library = DynamicLibrary.open(path!);
      a = NovoRudpSecureSession.fromSeed(library: library, seed: Uint8List(32));
      b = NovoRudpSecureSession.fromSeed(
        library: library,
        seed: Uint8List.fromList(List.filled(32, 17)),
      );
      final init = a.start(b.peerId);
      final response = b.respond(init.offer, expectedPeer: a.peerId);
      tx = a.complete(init, response.response);
      rx = response.channel;
    });
    tearDown(() async {
      for (final receiver in receivers) {
        await receiver.close();
      }
      receivers.clear();
      a.dispose();
      b.dispose();
      await root.delete(recursive: true);
    });
    Future<NovoRudpFileReceiver> create(
      List<int> bytes, {
      String? digest,
    }) async {
      final hash = (await const DartSha256().hash(bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final receiver = await NovoRudpFileReceiver.create(
        privateDirectory: root,
        sessionId: tx.sessionId,
        streamId: BigInt.one,
        objectId: object,
        size: bytes.length,
        sha256: digest ?? hash,
      );
      receivers.add(receiver);
      return receiver;
    }

    NovoRudpFrame part(List<int> bytes, int index, {BigInt? objectId}) {
      final start = index * NovoRudpFileReceiver.chunkSize;
      return NovoRudpFrame(
        kind: NovoRudpFrameKind.data,
        sessionId: tx.sessionId,
        streamId: BigInt.one,
        objectId: objectId ?? object,
        sequence: BigInt.from(index),
        ackEpoch: BigInt.zero,
        payload: bytes.sublist(
          start,
          math.min(bytes.length, start + NovoRudpFileReceiver.chunkSize),
        ),
      );
    }

    Future<void> deliver(
      NovoRudpFileReceiver receiver,
      NovoRudpFrame frame,
    ) async =>
        receiver.acceptAuthenticated(await rx.open(await tx.seal(frame)));

    test('out of order, missing and duplicate fragments repair to exact file bytes', () async {
      final bytes = List.generate(
        31 * NovoRudpFileReceiver.chunkSize + 17,
        (i) => i % 251,
      );
      final receiver = await create(bytes);
      final planner = tx.createRepairSender(
        streamId: BigInt.one,
        objectId: object,
        fragments: receiver.fragments,
      );
      for (var i = receiver.fragments - 1; i >= 0; i--) {
        if (i != 2 && i != 3 && i != 19) {
          await deliver(receiver, part(bytes, i));
        }
      }
      await deliver(receiver, part(bytes, 5));
      await expectLater(receiver.verifiedFile(), throwsStateError);
      final ack = await tx.open(
        await rx.seal(await receiver.acknowledgement()),
      );
      final decision = await planner.acceptAuthenticatedAck(ack) as Map;
      final ranges = decision['Repair']['window']['missing_ranges'] as List;
      expect(ranges, [
        {'start': 2, 'end_inclusive': 3},
        {'start': 19, 'end_inclusive': 19},
      ]);
      for (final range in ranges) {
        for (var i = range['start'] as int; i <= range['end_inclusive']; i++) {
          await deliver(receiver, part(bytes, i));
        }
      }
      expect(await (await receiver.verifiedFile()).readAsBytes(), bytes);
      final done = await tx.open(
        await rx.seal(await receiver.acknowledgement()),
      );
      expect(await planner.acceptAuthenticatedAck(done), 'ReceiverDone');
      final file = await receiver.verifiedFile();
      await receiver.close();
      expect(await file.exists(), false);
    });

    test(
      'wrong object and digest cannot produce a completed ACK or usable file',
      () async {
        final bytes = [1, 2, 3];
        final receiver = await create(
          bytes,
          digest: List.filled(64, '0').join(),
        );
        await expectLater(
          deliver(receiver, part(bytes, 0, objectId: object + BigInt.one)),
          throwsFormatException,
        );
        expect(
          jsonDecode(
            utf8.decode((await receiver.acknowledgement()).payload),
          )['missing_count'],
          1,
        );
        await expectLater(
          deliver(receiver, part(bytes, 0)),
          throwsFormatException,
        );
        await expectLater(receiver.verifiedFile(), throwsStateError);
        await expectLater(receiver.acknowledgement(), throwsStateError);
      },
    );

    test('many holes keep ACK within encrypted packet budget', () async {
      final bytes = List.filled(130 * NovoRudpFileReceiver.chunkSize, 17);
      final receiver = await create(bytes);
      for (var i = 1; i < 130; i += 2) {
        await deliver(receiver, part(bytes, i));
      }
      final ack = await receiver.acknowledgement();
      expect(
        ack.payload.length,
        lessThanOrEqualTo(NovoRudpFileReceiver.chunkSize),
      );
      final planner = tx.createRepairSender(
        streamId: BigInt.one,
        objectId: object,
        fragments: 130,
      );
      expect(
        (await planner.acceptAuthenticatedAck(
          await tx.open(await rx.seal(ack)),
        ) as Map).containsKey('Repair'),
        true,
      );
    });

    test('empty file requires its one authenticated fragment; logout cleans staging', () async {
      final receiver = await create([]);
      await expectLater(receiver.verifiedFile(), throwsStateError);
      await deliver(receiver, part([], 0));
      expect(await (await receiver.verifiedFile()).length(), 0);
      MemberQrMemory.clear();
      await expectLater(receiver.verifiedFile(), throwsStateError);
      await receiver.close();
      expect(await root.list().isEmpty, true);
    });
  }, skip: path == null ? 'Set NOVORUDP_NATIVE_LIBRARY' : false);
}
