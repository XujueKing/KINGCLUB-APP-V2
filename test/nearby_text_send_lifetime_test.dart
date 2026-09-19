import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/nearby_text_channel.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Channel implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Link implements NovoRudpFrameLink {
  @override
  final channel = _Channel();
  final incoming = StreamController<NovoRudpFrame>();
  final sent = <NovoRudpFrame>[];
  void Function(NovoRudpFrame)? onSend;
  @override
  Stream<NovoRudpFrame> get frames => incoming.stream;
  @override
  Future<void> send(NovoRudpFrame frame) async {
    sent.add(frame);
    onSend?.call(frame);
  }

  void acknowledge(NovoRudpFrame frame) {
    final data = jsonDecode(utf8.decode(frame.payload)) as Map;
    incoming.add(
      NovoRudpFrame(
        kind: NovoRudpFrameKind.ack,
        sessionId: frame.sessionId,
        streamId: frame.streamId,
        objectId: BigInt.zero,
        sequence: frame.sequence,
        ackEpoch: BigInt.zero,
        payload: utf8.encode(
          jsonEncode({'v': 1, 'id': data['id'], 'hash': data['hash']}),
        ),
      ),
    );
  }

  @override
  Future<void> close() => incoming.close();
}

void main() {
  sqfliteFfiInit();
  late ChatHistoryStore history;
  late NearbyTextChannel sender;
  late _Link link;
  late Directory directory;
  const peer =
      'novovm-ed25519:1111111111111111111111111111111111111111111111111111111111111111';
  const id = '11111111-1111-4111-8111-111111111111';
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('text-lifetime-');
    history = await ChatHistoryStore.openDatabaseWithKey(
      factory: databaseFactoryFfi,
      file: '${directory.path}/chat.db',
      key: await AesGcm.with256bits().newSecretKey(),
      account: 'test-account',
    );
    link = _Link();
    sender = NearbyTextChannel(
      link: link,
      history: history,
      peerId: peer,
      canExchange: () => true,
    );
  });
  tearDown(() async {
    await sender.close();
    await history.close();
    await directory.delete(recursive: true);
  });

  test('expired attempt neither persists nor sends', () async {
    await expectLater(
      sender.sendText('hello', messageId: id, stillActive: () => false),
      throwsStateError,
    );
    expect(link.sent, isEmpty);
    expect(await history.nearbyMessages(peer), isEmpty);
  });

  test(
    'fallback stops remaining fragments without closing shared lane',
    () async {
      var active = true;
      link.onSend = (_) => active = false;
      await expectLater(
        sender.sendText(
          List.filled(1500, 'a').join(),
          messageId: id,
          stillActive: () => active,
        ),
        throwsStateError,
      );
      expect(link.sent, hasLength(1));
      expect(
        await history.nearbyMessages(peer, pendingOnly: true),
        hasLength(1),
      );
      link.onSend = link.acknowledge;
      await sender.sendText(
        'next message',
        messageId: '22222222-2222-4222-8222-222222222222',
      );
      expect(link.sent, hasLength(2));
      expect(
        await history.nearbyMessages(peer, pendingOnly: true),
        hasLength(1),
      );
    },
  );

  test('fallback while waiting for receipt stops retries', () async {
    var active = true;
    final first = Completer<void>();
    link.onSend = (_) {
      if (!first.isCompleted) first.complete();
    };
    final send = sender.sendText(
      'hello',
      messageId: id,
      stillActive: () => active,
    );
    final result = expectLater(send, throwsStateError);
    await first.future.timeout(const Duration(seconds: 3));
    active = false;
    await result.timeout(const Duration(seconds: 3));
    expect(link.sent, hasLength(1));
    expect(await history.nearbyMessages(peer, pendingOnly: true), hasLength(1));
  });
}
