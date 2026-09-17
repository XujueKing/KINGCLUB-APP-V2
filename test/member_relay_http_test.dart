import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_sent_file_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_uploader.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_files.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_text.dart';
import 'package:kingclub/src/core/networking/kingclub_secure_client.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_runtime.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_device_binding.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';

class _RealHttpBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class _Outbox implements ChatOutbox {
  final rows = <String, Map<String, dynamic>>{};
  @override
  Future<List<Map<String, dynamic>>> read() async => rows.values.toList();
  @override
  Future<void> put(Map<String, dynamic> row) async {
    rows[row['clientMessageId'] as String] = {...row};
  }

  @override
  Future<void> remove(String id) async {
    rows.remove(id);
  }
}

void main() {
  _RealHttpBinding();
  sqfliteFfiInit();
  final env = Platform.environment;
  final enabled = [
    'NOVORUDP_HTTP_FIXTURE',
    'NOVORUDP_NATIVE_LIBRARY',
    'SUPERVM_TEST_RELAY_URL',
    'SUPERVM_TEST_RELAY_PEER',
    'SUPERVM_TEST_RELAY_CERT',
  ].every(env.containsKey);
  test(
    'real member HTTP plus SUPERVM runtime authentication and data',
    () async {
      final data = jsonDecode(
        await File(env['NOVORUDP_HTTP_FIXTURE']!).readAsString(),
      ) as Map;
      expect(data['database'], 'kingclub_chat_test_20260913');
      final actors = (data['actors'] as List).cast<Map>();
      final library = DynamicLibrary.open(env['NOVORUDP_NATIVE_LIBRARY']!);
      final rng = Random.secure();
      NovoRudpDeviceBinding device(Map actor) {
        final identity = NovoRudpSecureSession.fromSeed(
          library: library,
          seed: Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256))),
        );
        addTearDown(identity.dispose);
        final client = KingclubSecureClient('http://127.0.0.1:39184');
        return NovoRudpDeviceBinding(
          identity: identity,
          messaging: MessagingRepository(
            account: actor['userAccount'] as String,
            call: (id, params) async {
              final result = await client.call(
                id,
                params,
                session: Map<String, dynamic>.from(actor),
              );
              return Map<String, dynamic>.from(result['result'] as Map);
            },
          ),
        );
      }

      final a = device(actors[0]), b = device(actors[1]);
      final ka = await a.ensureRegistered(), kb = await b.ensureRegistered();
      expect((await b.resolvePeer(ka.peerId)).peer, a.messaging.account);
      MemberRelayRuntime runtime(NovoRudpDeviceBinding binding) {
        final value = MemberRelayRuntime(
          binding: binding,
          enableGroupFiles: true,
          endpoint: Uri.parse(env['SUPERVM_TEST_RELAY_URL']!),
          expectedRelay: env['SUPERVM_TEST_RELAY_PEER']!,
          securityContext: SecurityContext(withTrustedRoots: false)
            ..setTrustedCertificates(env['SUPERVM_TEST_RELAY_CERT']!),
        );
        addTearDown(value.close);
        return value;
      }

      final left = runtime(a), right = runtime(b);
      final directory = await Directory.systemTemp.createTemp(
        'member-relay-http-',
      );
      Future<ChatHistoryStore> history(String account, String name) async =>
          ChatHistoryStore.openDatabaseWithKey(
            factory: databaseFactoryFfi,
            file: '${directory.path}/$name.db',
            account: account,
            key: await AesGcm.with256bits().newSecretKey(),
          );
      final ah = await history(a.messaging.account, 'a');
      final bh = await history(b.messaging.account, 'b');
      final at = MemberRelayText(runtime: left, history: ah);
      final bt = MemberRelayText(runtime: right, history: bh);
      FlutterSecureStorage.setMockInitialValues({});
      Future<ChatSentFileCache> fileCache(String name) async =>
          ChatSentFileCache(
            cache: ChatDownloadCache(
              root: Directory('${directory.path}/$name'),
              key: await AesGcm.with256bits().newSecretKey(),
            ),
            checkSession: () async {},
            temporaryDirectory: () async => directory,
          );
      final sourceCache = await fileCache('sent');
      final af = MemberRelayFiles(
        runtime: left,
        cache: sourceCache,
        privateDirectory: directory,
      );
      final bf = MemberRelayFiles(
        runtime: right,
        cache: await fileCache('received'),
        privateDirectory: directory,
      );
      addTearDown(() async {
        await af.close();
        await bf.close();
        await at.close();
        await bt.close();
        await ah.close();
        await bh.close();
        await directory.delete(recursive: true);
      });
      final ready = Future.wait([
        left.connections.firstWhere((value) => value != null),
        right.connections.firstWhere((value) => value != null),
      ]);
      left.start();
      right.start();
      left.didChangeAppLifecycleState(AppLifecycleState.resumed);
      right.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await ready.timeout(const Duration(seconds: 12));
      final incoming = right.incomingChannels.first;
      final sender = await left.connectPeer(b.messaging.account, kb.bindingId);
      final receiver = await incoming.timeout(const Duration(seconds: 5));
      expect(receiver.peer, a.messaging.account);
      if (const bool.fromEnvironment('KINGCLUB_NOVORUDP_LAN')) {
        final probe = Stopwatch()..start();
        while ((!sender.directLanReady || !receiver.link.directLanReady) &&
            probe.elapsed < const Duration(seconds: 10)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(sender.directLanReady && receiver.link.directLanReady, isTrue);
      }
      final frame = NovoRudpFrame(
        kind: NovoRudpFrameKind.data,
        sessionId: sender.channel.sessionId,
        streamId: BigInt.one,
        objectId: BigInt.one,
        sequence: BigInt.one,
        ackEpoch: BigInt.zero,
        payload: utf8.encode('actual member authorized relay'),
      );
      final delivered = receiver.link.frames.first;
      await sender.send(frame);
      expect(
        (await delivered.timeout(const Duration(seconds: 3))).payload,
        frame.payload,
      );
      final outbox = _Outbox();
      const text = 'member relay primary and real service reconciliation';
      final id = const Uuid().v4();
      var serviceChecked = false;
      final controller = DirectChatController(
        peer: b.messaging.account,
        outbox: outbox,
        preferRelayText: () => left.connection != null,
        sendRelayText: (body, messageId) async {
          await at.sendText(
            peer: b.messaging.account,
            bindingId: kb.bindingId,
            text: body,
            messageId: messageId,
          );
          return true;
        },
        repository: MessagingRepository(
          account: a.messaging.account,
          call: (method, params) async {
            if (method == 'K260913000601') {
              final received = await bh.nearbyMemberMessages(
                a.messaging.account,
              );
              expect(
                received.where((row) => row['id'] == id).single['text'],
                text,
              );
              serviceChecked = true;
            }
            return a.messaging.call(method, params);
          },
        ),
      );
      addTearDown(controller.dispose);
      await controller.send(text, clientMessageId: id);
      expect(serviceChecked, isTrue);
      expect(controller.error, isNull);
      expect(outbox.rows, isEmpty);
      final acknowledged = controller.messages.single;
      expect(acknowledged['sequence'], isA<num>());
      final replay = await a.messaging.sendText(
        peer: b.messaging.account,
        clientMessageId: id,
        text: text,
      );
      expect(
        (replay['message'] as Map)['messageId'],
        acknowledged['messageId'],
      );
      final remote = await b.messaging.history(a.messaging.account);
      expect(
        (remote['messages'] as List).where(
          (row) => row['clientMessageId'] == id,
        ),
        hasLength(1),
      );
      // One real HTTP upload/message, then the same attachment through the
      // native encrypted relay and, after cache eviction, ordinary HTTP.
      final bytes = List<int>.generate(4097, (i) => i % 251);
      final source = await File('${directory.path}/source.bin')
          .writeAsBytes(bytes);
      final uploader = ChatFileUploader(
        repository: a.messaging,
        checkSession: () async {},
        dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:39184')),
      );
      addTearDown(uploader.dispose);
      final uploaded = await uploader.upload(
        source,
        fileName: 'synthetic-relay.bin',
      );
      for (final group in [false, true]) {
        String? groupId;
        if (group) {
          final created = await a.messaging.call('K260913000617', {
            'requestId': const Uuid().v4(),
            'name': 'Synthetic native file group',
            'members': [b.messaging.account],
          });
          groupId = created['groupId'] as String;
        }
        final sent = group
            ? await a.messaging.call('K260914000653', {
                'groupId': groupId,
                'clientMessageId': const Uuid().v4(),
                'assetId': uploaded.assetId,
              })
            : await a.messaging.sendFile(
                peer: b.messaging.account,
                clientMessageId: const Uuid().v4(),
                assetId: uploaded.assetId,
              );
        final ref = ChatFileReference(
          group: group,
          messageId: (sent['message'] as Map)['messageId'] as String,
          assetId: uploaded.assetId,
          fileName: uploaded.fileName,
          size: uploaded.size,
          sha256: uploaded.sha256,
          sender: a.messaging.account,
        );
        expect(
          await sourceCache.retain(
            source,
            assetId: ref.assetId,
            size: ref.size,
            sha256: ref.sha256,
          ),
          isTrue,
        );
        var httpChunks = 0, peerTransfers = 0;
        final downloadHttp = Dio(
          BaseOptions(baseUrl: 'http://127.0.0.1:39184'),
        );
        downloadHttp.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              httpChunks++;
              handler.next(options);
            },
          ),
        );
        final downloader = ChatFileDownloader(
          repository: b.messaging,
          checkSession: () async {},
          dio: downloadHttp,
          temporaryDirectory: () async => directory,
          peerDownload: (reference, active) async {
            final result = await bf.receive(
              peer: a.messaging.account,
              group: reference.group,
              messageId: reference.messageId,
              assetId: reference.assetId,
              fileName: reference.fileName,
              size: reference.size,
              sha256: reference.sha256,
              stillActive: active,
            );
            if (result != null) peerTransfers++;
            return result;
          },
        );
        try {
          expect(await (await downloader.download(ref)).readAsBytes(), bytes);
          expect(peerTransfers, 1, reason: 'group=$group');
          expect(httpChunks, 0);
          await sourceCache.cache.root.delete(recursive: true);
          expect(await (await downloader.download(ref)).readAsBytes(), bytes);
          expect(peerTransfers, 1, reason: 'group=$group');
          expect(httpChunks, greaterThan(0));
        } finally {
          await downloader.dispose();
        }
      }
      await b.revoke(kb);
      await expectLater(sender.revalidate(), throwsA(anything));
      await expectLater(sender.send(frame), throwsStateError);
      left.close();
      right.close();
    },
    skip: !enabled,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
