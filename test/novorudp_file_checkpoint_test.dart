import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_receiver.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';

void main() {
  test(
    'unaligned HTTP ranges export only when all covering fragments exist',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'udp-checkpoint-',
      );
      final chunk = NovoRudpFileReceiver.chunkSize;
      final bytes = Uint8List.fromList(
        List.generate(chunk * 4, (i) => i % 251),
      );
      final hash = (await const DartSha256().hash(bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final receiver = await NovoRudpFileReceiver.create(
        privateDirectory: directory,
        sessionId: Uint8List(16),
        streamId: BigInt.one,
        objectId: BigInt.two,
        size: bytes.length,
        sha256: hash,
      );
      Future<void> fragment(int index) => receiver.acceptAuthenticated(
        NovoRudpFrame(
          kind: NovoRudpFrameKind.data,
          sessionId: Uint8List(16),
          streamId: BigInt.one,
          objectId: BigInt.two,
          sequence: BigInt.from(index),
          ackEpoch: BigInt.zero,
          payload: bytes.sublist(index * chunk, (index + 1) * chunk),
        ),
      );
      try {
        for (final index in [3, 0, 2]) {
          await fragment(index);
        }
        final blocks = <int, Uint8List>{};
        final blockSize = chunk + 13;
        await receiver.checkpointBlocks(blockSize, (index, block) async {
          blocks[index] = block;
        });
        expect(blocks.keys.toList(), [2, 3]);
        for (final entry in blocks.entries) {
          final start = entry.key * blockSize;
          expect(
            entry.value,
            bytes.sublist(start, (start + blockSize).clamp(0, bytes.length)),
          );
        }
        await expectLater(receiver.verifiedFile(), throwsStateError);
        await fragment(1);
        blocks.clear();
        await receiver.checkpointBlocks(blockSize, (index, block) async {
          blocks[index] = block;
        });
        expect([for (final block in blocks.values) ...block], bytes);
        expect(await (await receiver.verifiedFile()).readAsBytes(), bytes);
        await receiver.close();
        await expectLater(
          receiver.checkpointBlocks(blockSize, (_, _) async {}),
          throwsStateError,
        );
      } finally {
        await receiver.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
