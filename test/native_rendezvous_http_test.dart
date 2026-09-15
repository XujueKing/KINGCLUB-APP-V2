import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/networking/kingclub_secure_client.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/network_rendezvous_repository.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_device_binding.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_peer_handshake.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';

void main() {
  final fixture = Platform.environment['NOVORUDP_HTTP_FIXTURE'];
  final libraryPath = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  test(
    'real encrypted HTTP directory and rendezvous with native handshake',
    () async {
      final data = jsonDecode(await File(fixture!).readAsString()) as Map;
      expect(data['database'], 'kingclub_chat_test_20260913');
      final actors = (data['actors'] as List).cast<Map>();
      final library = DynamicLibrary.open(libraryPath!);
      final rng = Random.secure();
      NovoRudpSecureSession identity() => NovoRudpSecureSession.fromSeed(
        library: library,
        seed: Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256))),
      );
      final a = identity(), b = identity();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      MessagingRepository messaging(Map actor) {
        final client = KingclubSecureClient('http://127.0.0.1:39184');
        return MessagingRepository(
          account: actor['userAccount'] as String,
          call: (id, params) async {
            final result = await client.call(
              id,
              params,
              session: Map<String, dynamic>.from(actor),
            );
            return Map<String, dynamic>.from(result['result'] as Map);
          },
        );
      }

      final ma = messaging(actors[0]), mb = messaging(actors[1]);
      final ba = NovoRudpDeviceBinding(messaging: ma, identity: a),
          bb = NovoRudpDeviceBinding(messaging: mb, identity: b);
      final ka = await ba.ensureRegistered(), kb = await bb.ensureRegistered();
      final ra = NetworkRendezvousRepository(
        messaging: ma,
        peer: mb.account,
        ownBindingId: ka.bindingId,
        peerBindingId: kb.bindingId,
      );
      final rb = NetworkRendezvousRepository(
        messaging: mb,
        peer: ma.account,
        ownBindingId: kb.bindingId,
        peerBindingId: ka.bindingId,
      );
      final left = NovoRudpPeerHandshake(binding: ba, repository: ra),
          right = NovoRudpPeerHandshake(binding: bb, repository: rb);
      addTearDown(left.close);
      addTearDown(right.close);
      await left.offer();
      final offered = (await rb.read())!;
      final receive = await right.answer(offered);
      final send = (await left.pollAnswer())!;
      expect(send.sessionId, receive.sessionId);
      final frame = NovoRudpFrame(
        kind: NovoRudpFrameKind.data,
        sessionId: send.sessionId,
        streamId: BigInt.one,
        objectId: BigInt.two,
        sequence: BigInt.zero,
        ackEpoch: BigInt.zero,
        payload: [1, 7, 3, 9],
      );
      final packet = await send.seal(frame);
      expect((await receive.open(packet)).payload, frame.payload);
      await expectLater(receive.open(packet), throwsStateError);
      await ra.cancel(offered.id);
      expect((await rb.read())!.cancelled, true);
    },
    skip: fixture == null || libraryPath == null
        ? 'Explicit isolated fixture and native library required'
        : false,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
