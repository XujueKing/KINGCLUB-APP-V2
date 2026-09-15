import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/nearby_text_channel.dart';

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/nearby_peer_connector.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';

void main() {
  sqfliteFfiInit();
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  test(
    'offline text persists at both peers despite dropped handshake and receipt',
    () async {
      final lib = DynamicLibrary.open(path!);
      final a = NovoRudpSecureSession.fromSeed(
        library: lib,
        seed: Uint8List.fromList(List.filled(32, 31)),
      );
      final b = NovoRudpSecureSession.fromSeed(
        library: lib,
        seed: Uint8List.fromList(List.filled(32, 47)),
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final host = InternetAddress.loopbackIPv4;
      final sa = await RawDatagramSocket.bind(host, 0),
          sb = await RawDatagramSocket.bind(host, 0);
      final ap = sa.port, bp = sb.port;
      final proxy = await RawDatagramSocket.bind(host, 0);
      addTearDown(proxy.close);
      var dropped = false;
      var dropReceipt = false;
      proxy.writeEventsEnabled = false;
      final forwarding = proxy.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? packet;
        while ((packet = proxy.receive()) != null) {
          final p = packet!;
          if (p.port != ap && p.port != bp) continue;
          if (dropReceipt && p.port == bp) {
            dropReceipt = false;
            continue;
          }
          if (!dropped) {
            try {
              final message = jsonDecode(utf8.decode(p.data));
              if (message is Map &&
                  message['kind'] == 'kingclub_nearby_answer_v1') {
                dropped = true;
                continue;
              }
            } on FormatException {
              /* Encrypted payload is forwarded without inspection. */
            }
          }
          proxy.send(p.data, host, p.port == ap ? bp : ap);
        }
      });
      addTearDown(forwarding.cancel);
      final left = NearbyPeerConnector(
        socket: sa,
        identity: a,
        expectedPeer: b.peerId,
        address: host,
        port: proxy.port,
      );
      final right = NearbyPeerConnector(
        socket: sb,
        identity: b,
        expectedPeer: a.peerId,
        address: host,
        port: proxy.port,
      );
      addTearDown(left.close);
      addTearDown(right.close);
      final links = await Future.wait([left.connect(), right.connect()])
          .timeout(const Duration(seconds: 5));
      for (final link in links) {
        addTearDown(link.close);
      }
      expect(dropped, isTrue);
      expect(links[0].channel.sessionId, links[1].channel.sessionId);
      expect(links[0].localPort, ap);
      expect(links[1].localPort, bp);
      left.close();
      right.close();
      final incoming = links[1].frames.first.timeout(
        const Duration(seconds: 3),
      );
      await links[0].send(
        NovoRudpFrame(
          kind: NovoRudpFrameKind.data,
          sessionId: links[0].channel.sessionId,
          streamId: BigInt.one,
          objectId: BigInt.one,
          sequence: BigInt.one,
          ackEpoch: BigInt.zero,
          payload: [7, 9, 1],
        ),
      );
      expect((await incoming).payload, [7, 9, 1]);
      final dir = await Directory.systemTemp.createTemp('nearby-text-');
      final key = await AesGcm.with256bits().newSecretKey();
      final ha = await ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: '${dir.path}/a.db',
        key: key,
        account: 'member-a',
      );
      final hb = await ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: '${dir.path}/b.db',
        key: key,
        account: 'member-b',
      );
      var authorized = true;
      final ta = NearbyTextChannel(
        link: links[0],
        history: ha,
        peerId: b.peerId,
        canExchange: () => authorized,
      );
      final tb = NearbyTextChannel(
        link: links[1],
        history: hb,
        peerId: a.peerId,
        canExchange: () => authorized,
      );
      addTearDown(() async {
        await ta.close();
        await tb.close();
        await ha.close();
        await hb.close();
        await dir.delete(recursive: true);
      });
      const messageId = '11111111-1111-4111-8111-111111111111';
      final body = List.filled(900, '\u{1f642}').join();
      dropReceipt = true;
      await ta
          .sendText(body, messageId: messageId)
          .timeout(const Duration(seconds: 5));
      expect(dropReceipt, isFalse);
      expect((await hb.nearbyMessages(a.peerId)).single['text'], body);
      expect(await ha.nearbyMessages(b.peerId, pendingOnly: true), isEmpty);
      await ta.sendText(body, messageId: messageId);
      expect((await hb.nearbyMessages(a.peerId)).length, 1);
      await ha.persistNearbyText(
        peerId: b.peerId,
        id: '22222222-2222-4222-8222-222222222222',
        text: 'saved-before-reconnect',
        outgoing: true,
      );
      await ta.resumePending();
      expect(await ha.nearbyMessages(b.peerId, pendingOnly: true), isEmpty);
      expect((await hb.nearbyMessages(a.peerId)).length, 2);
      authorized = false;
      await expectLater(ta.sendText('denied'), throwsStateError);
      final pending = NearbyPeerConnector(
        socket: await RawDatagramSocket.bind(host, 0),
        identity: a,
        expectedPeer: b.peerId,
        address: host,
        port: proxy.port,
      );
      final result = pending.connect();
      final assertion = expectLater(result, throwsStateError);
      pending.close();
      await assertion;
    },
    skip: path == null ? 'Requires real native library' : false,
  );
}
