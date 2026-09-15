import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_receiver.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_sender.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_connection.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  final env = Platform.environment;
  final enabled = [
    'NOVORUDP_NATIVE_LIBRARY',
    'SUPERVM_TEST_RELAY_URL',
    'SUPERVM_TEST_RELAY_PEER',
    'SUPERVM_TEST_RELAY_CERT',
  ].every(env.containsKey);
  test(
    'actual SUPERVM encrypted file completes after lost final receipt',
    () async {
      final library = DynamicLibrary.open(env['NOVORUDP_NATIVE_LIBRARY']!);
      final random = Random.secure();
      NovoRudpSecureSession identity() {
        final value = NovoRudpSecureSession.fromSeed(
          library: library,
          seed: Uint8List.fromList(
            List.generate(32, (_) => random.nextInt(256)),
          ),
        );
        addTearDown(value.dispose);
        return value;
      }

      final a = identity(), b = identity();
      // Explicitly trusted test identities; membership lookup is not under test.
      final offer = a.start(b.peerId);
      final answer = b.respond(offer.offer, expectedPeer: a.peerId);
      final channel = a.complete(offer, answer.response);
      final context = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(env['SUPERVM_TEST_RELAY_CERT']!);
      Future<NovoRudpRelayConnection> connect(
        NovoRudpSecureSession owner,
      ) async {
        final relay = NovoRudpRelayConnection(
          identity: owner,
          endpoint: Uri.parse(env['SUPERVM_TEST_RELAY_URL']!),
          expectedRelay: env['SUPERVM_TEST_RELAY_PEER']!,
          securityContext: context,
        );
        addTearDown(relay.close);
        return relay;
      }

      final left = NovoRudpRelayFrameLink(
        relay: await connect(a),
        channel: channel,
        expectedPeer: b.peerId,
      );
      final right = NovoRudpRelayFrameLink(
        relay: await connect(b),
        channel: answer.channel,
        expectedPeer: a.peerId,
      );
      addTearDown(left.close);
      addTearDown(right.close);
      await left.relay.connect();
      await right.relay.connect();
      final outcomes = <Object?, int>{};
      final observation = left.relay.messages.listen((event) {
        if (event['kind'] == 'forward_outcome') {
          final disposition = (event['body'] as Map)['disposition'];
          outcomes.update(disposition, (count) => count + 1, ifAbsent: () => 1);
        }
      });
      addTearDown(observation.cancel);
      final directory = await Directory.systemTemp.createTemp('supervm-file-');
      addTearDown(() => directory.delete(recursive: true));
      final bytes = List.generate(256 * 1024 + 17, (_) => random.nextInt(256));
      final file = await File('${directory.path}/source.bin')
          .writeAsBytes(bytes);
      final digest = (await Sha256().hash(bytes)).bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      final receiver = await NovoRudpFileReceiver.create(
        privateDirectory: directory,
        sessionId: channel.sessionId,
        streamId: BigInt.one,
        objectId: BigInt.two,
        size: bytes.length,
        sha256: digest,
      );
      addTearDown(receiver.close);
      var doneReceipts = 0;
      var frames = 0;
      Object? lastAck;
      final errors = <Object>[];
      final subscription = right.frames.listen((frame) async {
        frames++;
        try {
          final ack = await receiver.receiveAuthenticated(frame);
          if (ack == null) return;
          lastAck = jsonDecode(utf8.decode(ack.payload));
          if ((jsonDecode(utf8.decode(ack.payload)) as Map)['receiver_done'] ==
              true) {
            doneReceipts++;
            if (doneReceipts == 1) return;
          }
          await right.send(ack);
        } catch (error) {
          errors.add(error);
        }
      });
      addTearDown(subscription.cancel);
      final elapsed = Stopwatch()..start();
      try {
        await NovoRudpFileSender(
          link: left,
          file: file,
          streamId: BigInt.one,
          objectId: BigInt.two,
          size: bytes.length,
          sha256: digest,
        ).run();
      } catch (_) {
        // Synthetic test routes only; surface daemon refusal and receiver errors.
        // ignore: avoid_print
        print(
          'file failure outcomes=$outcomes receiverErrors=$errors frames=$frames ack=$lastAck',
        );
        rethrow;
      }
      expect(errors, isEmpty);
      expect(doneReceipts, greaterThanOrEqualTo(2));
      expect(await (await receiver.verifiedFile()).readAsBytes(), bytes);
      // This checks carriage and verified temporary storage, not chat delivery.
      // ignore: avoid_print
      print(
        'SUPERVM_FILE bytes=${bytes.length} elapsedMs=${elapsed.elapsedMilliseconds} finalReceipts=$doneReceipts',
      );
    },
    skip: enabled ? false : 'requires actual SUPERVM relay and native library',
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
