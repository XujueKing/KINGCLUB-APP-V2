import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  group(
    'real Rust dynamic library',
    () {
      late NovoRudpSecureSession a, b;
      setUp(() {
        final library = DynamicLibrary.open(path!);
        a = NovoRudpSecureSession.fromSeed(
          library: library,
          seed: Uint8List.fromList(List.filled(32, 31)),
        );
        b = NovoRudpSecureSession.fromSeed(
          library: library,
          seed: Uint8List.fromList(List.filled(32, 47)),
        );
      });
      tearDown(() {
        a.dispose();
        b.dispose();
      });
      test('handshake, encrypted frame, tamper rejection, replay and channel close', () async {
        final start = a.start(b.peerId);
        expect(() => b.complete(start, {}), throwsStateError);
        expect(
          () => b.respond(start.offer, expectedPeer: b.peerId),
          throwsStateError,
        );
        final accepted = b.respond(start.offer, expectedPeer: a.peerId);
        final sender = a.complete(start, accepted.response);
        expect(() => a.complete(start, accepted.response), throwsStateError);
        final frame = NovoRudpFrame(
          kind: NovoRudpFrameKind.data,
          sessionId: sender.sessionId,
          streamId: (BigInt.one << 64) - BigInt.one,
          objectId: BigInt.one,
          sequence: BigInt.one,
          ackEpoch: BigInt.zero,
          payload: [1, 2, 3],
        );
        final envelope = await sender.seal(frame);
        final bad = jsonDecode(jsonEncode(envelope)) as Map<String, dynamic>;
        (bad['ciphertext'] as List)[0] ^= 1;
        await expectLater(accepted.channel.open(bad), throwsStateError);
        final decoded = await accepted.channel.open(envelope);
        expect(await decoded.encode(), await frame.encode());
        await expectLater(accepted.channel.open(envelope), throwsStateError);
        sender.close();
        sender.close();
        await expectLater(sender.seal(frame), throwsStateError);
      });
      test(
        'generation change during encryption cannot return an old envelope',
        () async {
          final start = a.start(b.peerId);
          final accepted = b.respond(start.offer, expectedPeer: a.peerId);
          final channel = a.complete(start, accepted.response);
          final pending = channel.seal(
            NovoRudpFrame(
              kind: NovoRudpFrameKind.data,
              sessionId: channel.sessionId,
              streamId: BigInt.zero,
              objectId: BigInt.zero,
              sequence: BigInt.zero,
              ackEpoch: BigInt.zero,
              payload: [4],
            ),
          );
          MemberQrMemory.clear();
          await expectLater(pending, throwsStateError);
          expect(() => a.peerId, throwsStateError);
        },
      );
      test('session event closes pending handshake and identity', () async {
        final start = a.start(b.peerId);
        SecureSessionStore.changes.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(() => a.peerId, throwsStateError);
        expect(() => a.cancel(start), throwsStateError);
        // Objects are actually released, not merely made inaccessible in Dart.
        final library = DynamicLibrary.open(path!);
        for (var i = 0; i < 140; i++) {
          final session = NovoRudpSecureSession.fromSeed(
            library: library,
            seed: Uint8List(32),
          );
          session.dispose();
        }
      });
    },
    skip: path == null
        ? 'Set NOVORUDP_NATIVE_LIBRARY to the built native library'
        : false,
  );
}
