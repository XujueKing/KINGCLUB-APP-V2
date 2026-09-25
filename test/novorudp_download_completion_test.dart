import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_download.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class _Channel extends Fake implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
}

class _Link extends Fake implements NovoRudpFrameLink {
  @override
  final channel = _Channel();
  final incoming = StreamController<NovoRudpFrame>.broadcast();
  final ack = Completer<void>();
  bool throwImmediately = false;
  @override
  Stream<NovoRudpFrame> get frames => incoming.stream;
  @override
  Future<void> send(NovoRudpFrame frame) {
    if (throwImmediately) throw StateError('carrier disconnected');
    return ack.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final fault in [
    'immediate-ack',
    'late-ack',
    'closed-lane',
    'session-revoked',
  ]) {
    test('verified file handoff handles $fault', () async {
      final root = await Directory.systemTemp.createTemp('verified-handoff-');
      final link = _Link()..throwImmediately = fault == 'immediate-ack';
      final bytes = [1, 2, 3, 4];
      final hash = (await const DartSha256().hash(bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final download = await NovoRudpFileDownload.open(
        link: link,
        privateDirectory: root,
        streamId: BigInt.one,
        objectId: BigInt.two,
        size: bytes.length,
        sha256: hash,
        canReceive: () => true,
      );
      addTearDown(() async {
        if (!link.ack.isCompleted) link.ack.complete();
        await download.close();
        await link.incoming.close();
        await root.delete(recursive: true);
      });
      NovoRudpFrame frame(NovoRudpFrameKind kind) => NovoRudpFrame(
        kind: kind,
        sessionId: link.channel.sessionId,
        streamId: BigInt.one,
        objectId: BigInt.two,
        sequence: BigInt.zero,
        ackEpoch: BigInt.zero,
        payload: kind == NovoRudpFrameKind.data ? bytes : [],
      );
      link.incoming.add(frame(NovoRudpFrameKind.data));
      link.incoming.add(frame(NovoRudpFrameKind.done));
      final file = await download.completed.timeout(const Duration(seconds: 3));
      if (fault == 'late-ack') link.ack.completeError(StateError('lost route'));
      if (fault == 'closed-lane') await link.incoming.close();
      if (fault == 'session-revoked') SecureSessionStore.changes.add(null);
      // Let asynchronous failure cleanup run before the owner copies the file.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (fault == 'session-revoked') {
        final wait = Stopwatch()..start();
        while (await file.exists() &&
            wait.elapsed < const Duration(seconds: 2)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(await file.exists(), false);
      } else {
        expect(await file.readAsBytes(), bytes);
      }
      await download.close();
      expect(await file.exists(), false);
    });
  }
}
