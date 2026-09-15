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
      addTearDown(() async {
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
      await b.revoke(kb);
      await expectLater(sender.revalidate(), throwsA(anything));
      await expectLater(sender.send(frame), throwsStateError);
      left.close();
      right.close();
    },
    skip: !enabled,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
