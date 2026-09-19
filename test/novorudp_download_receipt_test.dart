import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_download.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class _Channel implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Link implements NovoRudpFrameLink {
  @override
  final channel = _Channel();
  final incoming = StreamController<NovoRudpFrame>();
  final entered = Completer<void>();
  final release = Completer<void>();
  int sends = 0;
  bool closed = false;
  @override
  Stream<NovoRudpFrame> get frames => incoming.stream;
  @override
  Future<void> send(NovoRudpFrame frame) {
    sends++;
    if (!entered.isCompleted) entered.complete();
    return release.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  void deliver(NovoRudpFrameKind kind, [List<int> bytes = const []]) {
    incoming.add(
      NovoRudpFrame(
        kind: kind,
        sessionId: channel.sessionId,
        streamId: BigInt.one,
        objectId: BigInt.two,
        sequence: BigInt.zero,
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
  const bytes = [1, 2, 3];
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('download-ack-');
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
      idleTimeout: const Duration(milliseconds: 500),
    );
  });
  tearDown(() async {
    await download.close();
    if (!link.release.isCompleted) link.release.complete();
    await link.incoming.close();
    await directory.delete(recursive: true);
  });

  test('verified file is available despite a blocked ACK', () async {
    link.deliver(NovoRudpFrameKind.data, bytes);
    link.deliver(NovoRudpFrameKind.done);
    final file = await download.completed.timeout(const Duration(seconds: 2));
    expect(await file.readAsBytes(), bytes);
    expect(link.release.isCompleted, isFalse);
    await download.close().timeout(const Duration(seconds: 1));
    expect(await file.exists(), isFalse);
    expect(link.closed, isFalse);
    // A late transport failure after cleanup must be consumed.
    link.release.completeError(StateError('late send failure'));
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'ACK polls cannot pile up blocked sends or keep partial file alive',
    () async {
      final failed = expectLater(
        download.completed,
        throwsA(isA<TimeoutException>()),
      );
      link.deliver(NovoRudpFrameKind.done);
      await link.entered.future.timeout(const Duration(seconds: 2));
      for (var i = 0; i < 50; i++) {
        link.deliver(NovoRudpFrameKind.done);
      }
      await failed;
      expect(link.sends, 1);
      expect(link.closed, isFalse);
    },
  );

  test('a dropped local ACK allows the next poll to retry', () async {
    link.deliver(NovoRudpFrameKind.done);
    await link.entered.future.timeout(const Duration(seconds: 2));
    link.release.completeError(const SocketException('dropped'));
    await Future<void>.delayed(Duration.zero);
    link.deliver(NovoRudpFrameKind.data, bytes);
    link.deliver(NovoRudpFrameKind.done);
    final file = await download.completed.timeout(const Duration(seconds: 2));
    expect(await file.readAsBytes(), bytes);
    expect(link.sends, 2);
  });
}
