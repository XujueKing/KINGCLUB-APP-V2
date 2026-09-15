import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/network_rendezvous_repository.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_device_binding.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_peer_handshake.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  for (final cancelLostOffer in [false, true]) {
    test(
      cancelLostOffer
          ? 'native handshake cancels an offer after its acknowledgement is lost'
          : 'native handshake survives lost offer, answer and directory responses',
      () async {
        final library = DynamicLibrary.open(path!);
        final a = NovoRudpSecureSession.fromSeed(
          library: library,
          seed: Uint8List(32),
        );
        final b = NovoRudpSecureSession.fromSeed(
          library: library,
          seed: Uint8List.fromList(List.filled(32, 17)),
        );
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        const aid = '11111111-1111-4111-8111-111111111111',
            bid = '22222222-2222-4222-8222-222222222222';
        final keys = {
          'a': {
            'bindingId': aid,
            'peerId': a.peerId,
            'publicKey': a.peerId.split(':').last,
          },
          'b': {
            'bindingId': bid,
            'peerId': b.peerId,
            'publicKey': b.peerId.split(':').last,
          },
        };
        Map<String, dynamic>? stored;
        var loseOffer = true, loseAnswer = true, loseDirectory = false;
        ChatApiCall api(String actor) => (method, params) async {
          if (method.endsWith('672')) {
            if (actor == 'a' && loseDirectory) {
              loseDirectory = false;
              throw const AuthFailure('NETWORK_ERROR', 'test');
            }
            return {
              'keys': [keys[params['peer']]],
              'cacheSeconds': 0,
            };
          }
          expect(method, 'K260915000683');
          final command = params['command'] as Map;
          if (command['type'] == 'offer') {
            if (stored != null) {
              expect(command['payload'], stored!['offer']);
              expect(command['exchangeId'], stored!['exchangeId']);
            }
            stored ??= {
              'exchangeId': command['exchangeId'],
              'fromBindingId': aid,
              'toBindingId': bid,
              'offer': command['payload'],
              'answer': null,
              'expiresAtMs': DateTime.now().millisecondsSinceEpoch + 45000,
              'cancelled': false,
            };
            if (loseOffer) {
              loseOffer = false;
              throw const AuthFailure('NETWORK_ERROR', 'test');
            }
          }
          if (command['type'] == 'answer') {
            if (stored!['answer'] != null) {
              expect(command['payload'], stored!['answer']);
            }
            stored!['answer'] = command['payload'];
            if (loseAnswer) {
              loseAnswer = false;
              throw const AuthFailure('NETWORK_ERROR', 'test');
            }
          }
          if (command['type'] == 'cancel') {
            expect(command['exchangeId'], stored!['exchangeId']);
            stored!['cancelled'] = true;
          }
          return {'exchange': jsonDecode(jsonEncode(stored))};
        };
        final ma = MessagingRepository(account: 'a', call: api('a')),
            mb = MessagingRepository(account: 'b', call: api('b'));
        final ra = NetworkRendezvousRepository(
          messaging: ma,
          peer: 'b',
          ownBindingId: aid,
          peerBindingId: bid,
        );
        final rb = NetworkRendezvousRepository(
          messaging: mb,
          peer: 'a',
          ownBindingId: bid,
          peerBindingId: aid,
        );
        final left = NovoRudpPeerHandshake(
          binding: NovoRudpDeviceBinding(messaging: ma, identity: a),
          repository: ra,
        );
        final right = NovoRudpPeerHandshake(
          binding: NovoRudpDeviceBinding(messaging: mb, identity: b),
          repository: rb,
        );
        addTearDown(left.close);
        addTearDown(right.close);
        expect(stored, isNull);
        await expectLater(left.offer(), throwsA(isA<AuthFailure>()));
        if (cancelLostOffer) {
          await left.cancel();
          expect(stored!['cancelled'], isTrue);
          await expectLater(left.offer(), throwsStateError);
          await expectLater(right.answer((await rb.read())!), throwsStateError);
          await left.cancel();
          return;
        }
        await left.offer();
        expect(await left.pollAnswer(), isNull);
        final invitation = (await rb.read())!;
        await expectLater(
          right.answer(invitation),
          throwsA(isA<AuthFailure>()),
        );
        final receive = await right.answer(invitation);
        loseDirectory = true;
        await expectLater(left.pollAnswer(), throwsA(isA<AuthFailure>()));
        final send = (await left.pollAnswer())!;
        expect(send.sessionId, receive.sessionId);
        final frame = NovoRudpFrame(
          kind: NovoRudpFrameKind.data,
          sessionId: send.sessionId,
          streamId: BigInt.one,
          objectId: BigInt.two,
          sequence: BigInt.zero,
          ackEpoch: BigInt.zero,
          payload: [9, 8, 7],
        );
        final packet = await send.seal(frame);
        expect((await receive.open(packet)).payload, [9, 8, 7]);
        await expectLater(receive.open(packet), throwsStateError);
        await left.cancel();
        expect(stored!['cancelled'], isTrue);
        right.close();
        await expectLater(send.seal(frame), throwsStateError);
      },
      skip: path == null ? 'Native library must be supplied' : false,
    );
  }
}
