import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_runtime.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_device_binding.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _NetworkBinding();
  sqfliteFfiInit();
  final env = Platform.environment;
  final enabled = [
    'NOVORUDP_NATIVE_LIBRARY',
    'SUPERVM_TEST_RELAY_URL',
    'SUPERVM_TEST_RELAY_PEER',
    'SUPERVM_TEST_RELAY_CERT',
  ].every(env.containsKey);
  test(
    'real relay foreground reconnect and cancelled directory lookup',
    () async {
      final random = Random.secure();
      final identity = NovoRudpSecureSession.fromSeed(
        library: DynamicLibrary.open(env['NOVORUDP_NATIVE_LIBRARY']!),
        seed: Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
      );
      addTearDown(identity.dispose);
      final callerIdentity = NovoRudpSecureSession.fromSeed(
        library: DynamicLibrary.open(env['NOVORUDP_NATIVE_LIBRARY']!),
        seed: Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
      );
      addTearDown(callerIdentity.dispose);
      Completer<void>? hold;
      var reads = 0;
      final binding = NovoRudpDeviceBinding(
        identity: identity,
        messaging: MessagingRepository(
          account: 'runtime-member',
          call: (api, params) async {
            expect(api, 'K260915000672');
            final resolving = params.containsKey('peerId');
            if (resolving) expect(params['peerId'], callerIdentity.peerId);
            final remote = resolving || params['peer'] == 'friend';
            final device = remote ? callerIdentity : identity;
            reads++;
            await hold?.future;
            return {
              if (resolving) 'peer': 'friend',
              'cacheSeconds': 0,
              'keys': [
                {
                  'bindingId': remote
                      ? 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
                      : 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                  'peerId': device.peerId,
                  'publicKey': device.peerId.split(':').last,
                },
              ],
            };
          },
        ),
      );
      final runtime = MemberRelayRuntime(
        binding: binding,
        endpoint: Uri.parse(env['SUPERVM_TEST_RELAY_URL']!),
        expectedRelay: env['SUPERVM_TEST_RELAY_PEER']!,
        securityContext: SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificates(env['SUPERVM_TEST_RELAY_CERT']!),
      );
      addTearDown(runtime.close);
      final firstReady = runtime.connections.firstWhere(
        (value) => value != null,
      );
      runtime.start();
      runtime.didChangeAppLifecycleState(AppLifecycleState.resumed);
      final first = (await firstReady.timeout(const Duration(seconds: 5)))!;
      final ack = first.messages.firstWhere(
        (event) => event['kind'] == 'heartbeat_ack',
      );
      first.heartbeat();
      await ack.timeout(const Duration(seconds: 2));
      final caller = MemberRelayRuntime(
        binding: NovoRudpDeviceBinding(
          identity: callerIdentity,
          messaging: MessagingRepository(
            account: 'friend',
            call: (api, params) async {
              expect(api, 'K260915000672');
              expect(params['peer'], anyOf('friend', 'runtime-member'));
              final own = params['peer'] == 'friend';
              final device = own ? callerIdentity : identity;
              return {
                'cacheSeconds': 0,
                'keys': [
                  {
                    'bindingId': own
                        ? 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
                        : 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'publicKey': device.peerId.split(':').last,
                    'peerId': device.peerId,
                  },
                ],
              };
            },
          ),
        ),
        endpoint: runtime.endpoint,
        expectedRelay: runtime.expectedRelay,
        securityContext: runtime.securityContext,
      );
      addTearDown(caller.close);
      final callerReady = caller.connections.firstWhere(
        (value) => value != null,
      );
      caller.start();
      caller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await callerReady.timeout(const Duration(seconds: 5));
      final directory = await Directory.systemTemp.createTemp(
        'relay-text-runtime-',
      );
      Future<ChatHistoryStore> history(String account, String name) async =>
          ChatHistoryStore.openDatabaseWithKey(
            factory: databaseFactoryFfi,
            file: '${directory.path}/$name.db',
            account: account,
            key: await AesGcm.with256bits().newSecretKey(),
          );
      final receiverHistory = await history('runtime-member', 'receiver');
      final senderHistory = await history('friend', 'sender');
      final receiveText = MemberRelayText(
        runtime: runtime,
        history: receiverHistory,
      );
      final sendText = MemberRelayText(runtime: caller, history: senderHistory);
      addTearDown(() async {
        await receiveText.close();
        await sendText.close();
        await receiverHistory.close();
        await senderHistory.close();
        await directory.delete(recursive: true);
      });
      final offered = runtime.incomingHandshakes.first;
      final arrival = runtime.incomingChannels.first;
      const targetBinding = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final opening = caller.connectPeer('runtime-member', targetBinding);
      expect(
        identical(opening, caller.connectPeer('runtime-member', targetBinding)),
        isTrue,
      );
      final incoming = await offered.timeout(const Duration(seconds: 2));
      expect(incoming['body']['source_peer_id'], callerIdentity.peerId);
      expect(incoming['body']['target_peer_id'], identity.peerId);
      final accepted = await arrival.timeout(const Duration(seconds: 3));
      expect(accepted.peer, 'friend');
      final sender = await opening.timeout(const Duration(seconds: 3));
      expect(
        identical(
          sender,
          await caller.connectPeer('runtime-member', targetBinding),
        ),
        isTrue,
      );
      final frame = NovoRudpFrame(
        kind: NovoRudpFrameKind.data,
        sessionId: sender.channel.sessionId,
        streamId: BigInt.one,
        objectId: BigInt.one,
        sequence: BigInt.one,
        ackEpoch: BigInt.zero,
        payload: [1, 2, 3],
      );
      final received = accepted.link.frames.first;
      await sender.send(frame);
      expect((await received.timeout(const Duration(seconds: 2))).payload, [
        1,
        2,
        3,
      ]);
      const textId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
      final textChanged = receiveText.changes.first;
      await sendText.sendText(
        peer: 'runtime-member',
        bindingId: targetBinding,
        text: 'durable runtime text',
        messageId: textId,
      );
      expect(await textChanged.timeout(const Duration(seconds: 2)), 'friend');
      await sendText.sendText(
        peer: 'runtime-member',
        bindingId: targetBinding,
        text: 'durable runtime text',
        messageId: textId,
      );
      expect(
        (await receiverHistory.nearbyMessages(callerIdentity.peerId)).length,
        1,
      );
      expect(
        (await senderHistory.nearbyMessages(identity.peerId))
            .single['delivered'],
        true,
      );
      await receiverHistory.commit('direct:friend', [
        {
          'messageId': 'confirmed-text',
          'clientMessageId': textId,
          'sequence': 1,
          'sender': 'friend',
          'recipient': 'runtime-member',
          'text': 'durable runtime text',
        },
      ], expectedEpoch: 0);
      expect(
        (await receiverHistory.nearbyMessages(callerIdentity.peerId))
            .single['serverMessageId'],
        'confirmed-text',
      );
      final ended = accepted.link.frames.drain<void>();
      final readsBeforePause = reads;
      caller.close();
      await expectLater(sender.send(frame), throwsStateError);
      final paused = runtime.connections.firstWhere((value) => value == null);
      runtime.didChangeAppLifecycleState(AppLifecycleState.paused);
      await paused;
      await ended.timeout(const Duration(seconds: 2));
      expect(runtime.connection, isNull);
      expect(first.heartbeat, throwsStateError);
      final secondReady = runtime.connections.firstWhere(
        (value) => value != null,
      );
      runtime.didChangeAppLifecycleState(AppLifecycleState.resumed);
      final second = (await secondReady.timeout(const Duration(seconds: 5)))!;
      expect(identical(first, second), isFalse);
      expect(reads, readsBeforePause + 1);
      runtime.didChangeAppLifecycleState(AppLifecycleState.paused);
      hold = Completer<void>();
      runtime.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(reads, readsBeforePause + 2);
      final lateConnections = <Object>[];
      final subscription = runtime.connections.listen((value) {
        if (value != null) lateConnections.add(value);
      });
      addTearDown(subscription.cancel);
      final done = runtime.connections.drain<void>();
      runtime.close();
      hold.complete();
      await done;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(lateConnections, isEmpty);
      expect(runtime.connection, isNull);
      expect(second.heartbeat, throwsStateError);
    },
    skip: !enabled,
  );
}
