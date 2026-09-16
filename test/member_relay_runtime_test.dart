import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:kingclub/src/features/messaging/data/offline_relay_conversations.dart';

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_text.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_runtime.dart';
import 'package:kingclub/src/features/messaging/data/relay_security_context.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_device_binding.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_files.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_sent_file_cache.dart';

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class _UnusedOutbox implements ChatOutbox {
  final items = <String, Map<String, dynamic>>{};
  @override
  Future<List<Map<String, dynamic>>> read() async => items.values.toList();
  @override
  Future<void> put(Map<String, dynamic> message) async {
    items[message['clientMessageId'] as String] = message;
  }

  @override
  Future<void> remove(String id) async {
    items.remove(id);
  }
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
  for (final preferRelay in [false, true]) {
    test(
      'real relay foreground reconnect and text route primary=$preferRelay',
      () async {
        const fileMessage = '11111111-1111-4111-8111-111111111111';
        const fileAsset = '22222222-2222-4222-8222-222222222222';
        final fileBytes = Uint8List.fromList(
          List.generate(4097, (i) => i % 251),
        );
        final fileHash = (await Sha256().hash(fileBytes)).bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        Map<String, dynamic> fileAuthority(Map<String, dynamic> params) {
          expect(params['messageId'], fileMessage);
          return {
            'messageId': fileMessage,
            'sender': 'friend',
            'recipient': 'runtime-member',
            'assetId': fileAsset,
            'fileName': 'runtime.bin',
            'size': fileBytes.length,
            'sha256': fileHash,
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(seconds: 15))
                .toIso8601String(),
          };
        }

        final random = Random.secure();
        final identity = NovoRudpSecureSession.fromSeed(
          library: DynamicLibrary.open(env['NOVORUDP_NATIVE_LIBRARY']!),
          seed: Uint8List.fromList(
            List.generate(32, (_) => random.nextInt(256)),
          ),
        );
        addTearDown(identity.dispose);
        final callerIdentity = NovoRudpSecureSession.fromSeed(
          library: DynamicLibrary.open(env['NOVORUDP_NATIVE_LIBRARY']!),
          seed: Uint8List.fromList(
            List.generate(32, (_) => random.nextInt(256)),
          ),
        );
        addTearDown(callerIdentity.dispose);
        Completer<void>? hold;
        var reads = 0;
        final binding = NovoRudpDeviceBinding(
          identity: identity,
          messaging: MessagingRepository(
            account: 'runtime-member',
            call: (api, params) async {
              if (api == 'K260916000686') return fileAuthority(params);
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
          securityContext: relaySecurityContext(
            base64Encode(
              await File(env['SUPERVM_TEST_RELAY_CERT']!).readAsBytes(),
            ),
          ),
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
                if (api == 'K260916000686') return fileAuthority(params);
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
        final sendText = MemberRelayText(
          runtime: caller,
          history: senderHistory,
        );
        Future<ChatSentFileCache> fileCache(String name) async =>
            ChatSentFileCache(
              cache: ChatDownloadCache(
                root: Directory('${directory.path}/$name'),
                key: await AesGcm.with256bits().newSecretKey(),
              ),
              checkSession: () async {},
              temporaryDirectory: () async => directory,
            );
        final sourceCache = await fileCache('sender-files');
        final localFile = await File('${directory.path}/source.bin')
            .writeAsBytes(fileBytes);
        await sourceCache.retain(
          localFile,
          assetId: fileAsset,
          size: fileBytes.length,
          sha256: fileHash,
        );
        final receiveFiles = MemberRelayFiles(
          runtime: runtime,
          cache: await fileCache('receiver-files'),
          privateDirectory: directory,
        );
        final sendFiles = MemberRelayFiles(
          runtime: caller,
          cache: sourceCache,
          privateDirectory: directory,
        );
        final conversation = DirectChatController(
          repository: runtime.binding.messaging,
          peer: 'friend',
          outbox: _UnusedOutbox(),
          readRelayMessages: () => receiveText.messages('friend'),
          relayChanges: receiveText.changes,
        );
        final displayed = Completer<void>();
        conversation.addListener(() {
          if (!displayed.isCompleted &&
              conversation.messages.any(
                (m) => m['text'] == 'durable runtime text',
              )) {
            displayed.complete();
          }
        });
        addTearDown(conversation.dispose);
        addTearDown(() async {
          await receiveFiles.close();
          await sendFiles.close();
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
          identical(
            opening,
            caller.connectPeer('runtime-member', targetBinding),
          ),
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
        // The receiver reuses a lane originally opened by the sender's text
        // path. File listeners must also attach to locally initiated lanes.
        final download = await receiveFiles.receive(
          peer: 'friend',
          messageId: fileMessage,
          assetId: fileAsset,
          fileName: 'runtime.bin',
          size: fileBytes.length,
          sha256: fileHash,
          stillActive: () => true,
        );
        expect(download, isNotNull);
        try {
          expect(await (await download!.completed).readAsBytes(), fileBytes);
        } finally {
          await download?.close();
        }
        const textId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
        final textChanged = receiveText.changes.first;
        final fallbackOutbox = _UnusedOutbox();
        final fallback = DirectChatController(
          repository: MessagingRepository(
            account: 'friend',
            call: (_, _) async {
              final received = await receiverHistory.nearbyMessages(
                callerIdentity.peerId,
              );
              expect(received.isNotEmpty, preferRelay);
              throw const AuthFailure('NETWORK_ERROR', 'service unavailable');
            },
          ),
          peer: 'runtime-member',
          outbox: fallbackOutbox,
          preferRelayText: () => preferRelay && caller.connection != null,
          sendRelayText: (text, id) async {
            await sendText.sendText(
              peer: 'runtime-member',
              bindingId: targetBinding,
              text: text,
              messageId: id,
            );
            return true;
          },
        );
        addTearDown(fallback.dispose);
        await fallback.send('durable runtime text', clientMessageId: textId);
        expect(fallbackOutbox.items[textId]!['peerDelivered'], true);
        expect(await textChanged.timeout(const Duration(seconds: 2)), 'friend');
        await displayed.future.timeout(const Duration(seconds: 2));
        expect(conversation.messages.single['sequence'], isNull);
        expect(
          (await receiveText.messages('friend')).single['text'],
          'durable runtime text',
        );
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
        final localRows = await offlineRelayConversations(receiverHistory, []);
        expect(localRows, hasLength(1));
        expect(localRows.single['peer'], 'friend');
        expect(localRows.single['preview'], 'durable runtime text');
        expect(localRows.single['unreadCount'], 1);
        await receiverHistory.saveConversationList(localRows);
        final restoredRows = await offlineRelayConversations(
          receiverHistory,
          await receiverHistory.readConversationList(),
        );
        expect(restoredRows.single['unreadCount'], 1);
        await receiverHistory.markNearbyMemberRead('friend', [textId]);
        await receiveText.flushReadReceipts('friend');
        for (var attempt = 0; attempt < 50; attempt++) {
          final sent = await senderHistory.nearbyMemberMessages(
            'runtime-member',
          );
          if (sent.single['read'] == true &&
              (await receiverHistory.pendingNearbyReadReceipts(
                callerIdentity.peerId,
              )).isEmpty) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(
          (await senderHistory.nearbyMemberMessages('runtime-member'))
              .single['read'],
          true,
        );
        expect(
          await receiverHistory.pendingNearbyReadReceipts(
            callerIdentity.peerId,
          ),
          isEmpty,
        );
        final formalRepository = MessagingRepository(
          account: 'friend',
          call: (_, _) async => {
            'conversationId': 'formal',
            'messages': [
              {
                'messageId': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
                'clientMessageId': textId,
                'sequence': 1,
                'sender': 'friend',
                'recipient': 'runtime-member',
                'text': 'durable runtime text',
                'messageType': 'text',
                'createdDate': '2026-09-15T00:00:00Z',
              },
            ],
            'settings': {'hiddenThrough': 0},
            'sendPermission': {'allowed': true},
            'lastSequence': 1,
            'peerReadSequence': 0,
            'hasMore': false,
            'historyVersion': 1,
          },
        );
        for (var reopen = 0; reopen < 2; reopen++) {
          final formal = DirectChatController(
            repository: formalRepository,
            peer: 'runtime-member',
            outbox: _UnusedOutbox(),
            openHistory: () async => senderHistory,
            readRelayMessages: () => sendText.messages('runtime-member'),
          );
          final readVisible = Completer<void>();
          formal.addListener(() {
            if (!readVisible.isCompleted &&
                formal.messages.any(
                  (m) => m['sequence'] == 1 && m['peerRead'] == true,
                )) {
              readVisible.complete();
            }
          });
          try {
            await formal.initialize();
            await readVisible.future.timeout(const Duration(seconds: 5));
            expect(formal.messages, hasLength(1));
            expect(formal.messages.single['peerRead'], true);
          } finally {
            formal.dispose();
          }
        }
        expect(
          (await offlineRelayConversations(
            receiverHistory,
            restoredRows,
          )).single['unreadCount'],
          0,
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
        expect(await receiveText.messages('friend'), isEmpty);
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
}
