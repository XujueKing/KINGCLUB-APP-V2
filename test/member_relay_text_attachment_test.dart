import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_runtime.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_text.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_device_binding.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_connection.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class _Binding extends Fake implements NovoRudpDeviceBinding {
  @override
  final messaging = MessagingRepository(
    account: 'me',
    call: (_, _) async => {},
  );
}

class _Connection extends Fake implements NovoRudpRelayConnection {}

class _Runtime extends Fake implements MemberRelayRuntime {
  final events = StreamController<MemberRelayArrival>.broadcast();
  final states = StreamController<NovoRudpRelayConnection?>.broadcast();
  @override
  final binding = _Binding();
  @override
  final connection = _Connection();
  @override
  Stream<MemberRelayArrival> get channels => events.stream;
  @override
  Stream<MemberRelayArrival> get incomingChannels => const Stream.empty();
  @override
  Stream<NovoRudpRelayConnection?> get connections => states.stream;
}

class _Secure extends Fake implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
}

class _Link extends Fake implements NovoRudpRelayFrameLink {
  final incoming = StreamController<NovoRudpFrame>.broadcast();
  final ack = Completer<NovoRudpFrame>();
  @override
  final expectedPeer = 'novovm-ed25519:${'a' * 64}';
  @override
  final channel = _Secure();
  @override
  Stream<NovoRudpFrame> get frames => incoming.stream;
  @override
  Future<void> send(NovoRudpFrame frame) async {
    if (frame.kind == NovoRudpFrameKind.ack && !ack.isCompleted) {
      ack.complete(frame);
    }
  }

  @override
  Future<void> close() => incoming.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('locally opened attachment lane receives text before any local text send', () async {
    final root = await Directory.systemTemp.createTemp('relay-text-attach-');
    final history = await ChatHistoryStore.openDatabaseWithKey(
      factory: databaseFactoryFfi,
      file: '${root.path}/chat.db',
      account: 'me',
      key: await AesGcm.with256bits().newSecretKey(),
    );
    final runtime = _Runtime(), link = _Link();
    final text = MemberRelayText(runtime: runtime, history: history);
    try {
      // Only the all-lanes event fires when a local file request opens a lane.
      runtime.events.add((peer: 'friend', link: link));
      runtime.events.add((peer: 'friend', link: link));
      await Future<void>.delayed(Duration.zero);
      const id = '11111111-1111-4111-8111-111111111111';
      final bytes = utf8.encode('reply after attachment');
      final hash = base64UrlEncode((await Sha256().hash(bytes)).bytes);
      final changed = text.changes.first;
      link.incoming.add(
        NovoRudpFrame(
          kind: NovoRudpFrameKind.data,
          sessionId: link.channel.sessionId,
          streamId: BigInt.from(0x4b43544d),
          objectId: BigInt.zero,
          sequence: BigInt.one,
          ackEpoch: BigInt.zero,
          payload: utf8.encode(
            jsonEncode({
              'v': 1,
              'id': id,
              'hash': hash,
              'i': 0,
              'n': 1,
              'data': base64Encode(bytes),
            }),
          ),
        ),
      );
      expect(await changed.timeout(const Duration(seconds: 2)), 'friend');
      final rows = await text.messages('friend');
      expect(rows, hasLength(1));
      expect(rows.single['text'], 'reply after attachment');
      expect(
        jsonDecode(utf8.decode((await link.ack.future).payload))['id'],
        id,
      );
    } finally {
      await text.close();
      await runtime.events.close();
      await runtime.states.close();
      await history.close();
      await root.delete(recursive: true);
    }
  });
}
