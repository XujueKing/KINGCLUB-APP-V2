import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_download.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_receiver.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class _Channel implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Link
    implements
        NovoRudpFrameLink,
        NovoRudpRemoteLiveness,
        NovoRudpRouteRecovery {
  @override
  final channel = _Channel();
  final incoming = StreamController<NovoRudpFrame>();
  final probed = Completer<void>();
  final reply = Completer<void>();
  int recoveryHints = 0;
  @override
  Stream<NovoRudpFrame> get frames => incoming.stream;
  @override
  Future<void> send(NovoRudpFrame frame) async {}
  @override
  Future<void> close() => incoming.close();
  @override
  void reportDeliveryStall() => recoveryHints++;
  @override
  Future<void> ensureRemoteSession() {
    if (!probed.isCompleted) probed.complete();
    return reply.future;
  }

  void deliver(int sequence, List<int> bytes, {bool done = false}) {
    incoming.add(
      NovoRudpFrame(
        kind: done ? NovoRudpFrameKind.done : NovoRudpFrameKind.data,
        sessionId: channel.sessionId,
        streamId: BigInt.one,
        objectId: BigInt.two,
        sequence: BigInt.from(sequence),
        ackEpoch: BigInt.zero,
        payload: bytes,
      ),
    );
  }
}

void main() {
  late Directory directory;
  late _Link link;
  late NovoRudpFileDownload download;
  final bytes = Uint8List(NovoRudpFileReceiver.chunkSize * 3);
  final chunk = bytes.sublist(0, NovoRudpFileReceiver.chunkSize);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('download-stall-');
    link = _Link();
    final hash = (await const DartSha256().hash(bytes)).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    download = await NovoRudpFileDownload.open(
      link: link,
      privateDirectory: directory,
      streamId: BigInt.one,
      objectId: BigInt.two,
      size: bytes.length,
      sha256: hash,
      canReceive: () => true,
    );
  });
  tearDown(() async {
    await download.close();
    if (!link.reply.isCompleted) link.reply.complete();
    await link.close();
    await directory.delete(recursive: true);
  });

  test(
    'unreachable sender fails before the eight-second idle budget',
    () async {
      final failed = expectLater(
        download.completed,
        throwsA(isA<TimeoutException>()),
      );
      link.deliver(0, chunk);
      await link.probed.future.timeout(const Duration(seconds: 4));
      link.reply.completeError(const SocketException('offline'));
      await failed.timeout(const Duration(seconds: 1));
      expect(link.recoveryHints, 1);
    },
  );

  test('a probe that never replies is bounded', () async {
    final failed = expectLater(
      download.completed,
      throwsA(isA<TimeoutException>()),
    );
    link.deliver(0, chunk);
    await link.probed.future.timeout(const Duration(seconds: 4));
    await failed.timeout(const Duration(seconds: 2));
    expect(link.reply.isCompleted, isFalse);
  });

  test('source preparation without data is not probed early', () async {
    await Future<void>.delayed(const Duration(milliseconds: 3200));
    expect(link.probed.isCompleted, isFalse);
    expect(link.recoveryHints, 0);
  });

  test('a live slow sender may continue after the early probe', () async {
    link.deliver(0, chunk);
    await link.probed.future.timeout(const Duration(seconds: 4));
    link.reply.complete();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    link.deliver(1, chunk);
    link.deliver(2, chunk);
    link.deliver(0, const [], done: true);
    final file = await download.completed.timeout(const Duration(seconds: 2));
    expect(await file.readAsBytes(), bytes);
  });

  test('new data invalidates a late failed probe', () async {
    link.deliver(0, chunk);
    await link.probed.future.timeout(const Duration(seconds: 4));
    link.deliver(1, chunk);
    while (download.receivedBytes < chunk.length * 2) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    link.reply.completeError(const SocketException('relay unavailable'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    link.deliver(2, chunk);
    link.deliver(0, const [], done: true);
    final file = await download.completed.timeout(const Duration(seconds: 2));
    expect(await file.readAsBytes(), bytes);
  });
}
