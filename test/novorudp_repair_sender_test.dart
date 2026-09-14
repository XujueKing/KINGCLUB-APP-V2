import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  final libraryPath = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  group('upstream repair planner through real native channel', () {
    late NovoRudpSecureSession a, b;
    late NovoRudpSecureChannel sendChannel, receiveChannel;
    late NovoRudpRepairSender sender;
    final stream = (BigInt.one << 64) - BigInt.one;
    final object = BigInt.one << 63;
    setUp(() {
      final library = DynamicLibrary.open(libraryPath!);
      a = NovoRudpSecureSession.fromSeed(library: library, seed: Uint8List(32));
      b = NovoRudpSecureSession.fromSeed(
        library: library,
        seed: Uint8List.fromList(List.filled(32, 17)),
      );
      final start = a.start(b.peerId);
      final response = b.respond(start.offer, expectedPeer: a.peerId);
      sendChannel = a.complete(start, response.response);
      receiveChannel = response.channel;
      sender = sendChannel.createRepairSender(
        streamId: stream,
        objectId: object,
        fragments: 100,
      );
    });
    tearDown(() {
      a.dispose();
      b.dispose();
    });

    NovoRudpFrame ack(
      int epoch, {
      int total = 100,
      int missing = 3,
      bool done = false,
      BigInt? objectId,
      List<Map<String, int>>? ranges,
      NovoRudpFrameKind kind = NovoRudpFrameKind.ack,
    }) => NovoRudpFrame(
      kind: kind,
      sessionId: sendChannel.sessionId,
      streamId: stream,
      objectId: objectId ?? object,
      sequence: BigInt.zero,
      ackEpoch: BigInt.from(epoch),
      payload: utf8.encode(
        jsonEncode({
          'header': {
            'version': 1,
            'kind': 'Ack',
            'session_id': sendChannel.sessionId,
            'epoch': epoch,
            'sequence': null,
            'window_id': 0,
          },
          'expected_total': total,
          'receiver_done': done,
          'missing_count': missing,
          'current_window': done ? null : {'start': 0, 'end_inclusive': 63},
          'current_window_missing_ranges':
              ranges ??
              (done
                  ? []
                  : [
                      {'start': 2, 'end_inclusive': 3},
                      {'start': 10, 'end_inclusive': 10},
                    ]),
        }),
      ),
    );
    Future<dynamic> authenticated(NovoRudpFrame frame) async =>
        sender.acceptAuthenticatedAck(
          await sendChannel.open(await receiveChannel.seal(frame)),
        );

    test('encrypted ACK selects missing fragments, ignores stale epoch and completes', () async {
      final plan = await authenticated(ack(1)) as Map;
      expect(plan['Repair']['window']['missing_count'], 3);
      expect(plan['Repair']['window']['missing_ranges'], [
        {'start': 2, 'end_inclusive': 3},
        {'start': 10, 'end_inclusive': 10},
      ]);
      final stale = await authenticated(ack(1)) as Map;
      expect(stale['StaleAck']['latest_epoch'], 1);
      expect(
        await authenticated(ack(2, missing: 0, done: true)),
        'ReceiverDone',
      );
    });
    test(
      'wrong transfer and invalid high-epoch ACK do not advance planner',
      () async {
        for (final bad in [
          ack(500, objectId: object + BigInt.one),
          ack(500, total: 101),
          ack(500, kind: NovoRudpFrameKind.data),
          ack(
            500,
            ranges: [
              {'start': 63, 'end_inclusive': 66},
            ],
          ),
          ack(500, missing: 0),
          ack(500, missing: 3, done: true),
        ]) {
          await expectLater(authenticated(bad), throwsStateError);
        }
        expect(
          (await authenticated(ack(1)) as Map).containsKey('Repair'),
          true,
        );
      },
    );
    test(
      'sender releases with channel and rejects invalid transfer sizes',
      () async {
        expect(
          () => sendChannel.createRepairSender(
            streamId: stream,
            objectId: object,
            fragments: 0,
          ),
          throwsStateError,
        );
        expect(
          () => sendChannel.createRepairSender(
            streamId: stream,
            objectId: object,
            fragments: 1000001,
          ),
          throwsStateError,
        );
        sendChannel.close();
        await expectLater(
          sender.acceptAuthenticatedAck(ack(1)),
          throwsStateError,
        );
        sender.close();
        // Repeated children do not exhaust the native handle bound.
        for (var i = 0; i < 140; i++) {
          receiveChannel
              .createRepairSender(
                streamId: stream,
                objectId: object,
                fragments: 1,
              )
              .close();
        }
      },
    );
  }, skip: libraryPath == null ? 'Set NOVORUDP_NATIVE_LIBRARY' : false);
}
