import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_sent_file_cache.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/peer_file_channel.dart';

const _id = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';

class _Channel implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Link implements NovoRudpFrameLink {
  @override
  final channel = _Channel();
  final incoming = StreamController<NovoRudpFrame>.broadcast();
  Completer<void> rejected = Completer<void>();
  @override
  Stream<NovoRudpFrame> get frames => incoming.stream;
  @override
  Future<void> send(NovoRudpFrame frame) async {
    expect(frame.kind, NovoRudpFrameKind.endpoint);
    final body = jsonDecode(utf8.decode(frame.payload));
    expect(
      body['op'],
      'reject',
      reason: 'cancelled source must never send DATA',
    );
    if (!rejected.isCompleted) rejected.complete();
  }

  void control(
    String op, {
    int object = 1,
    String id = _id,
    String media = 'image',
  }) {
    incoming.add(
      NovoRudpFrame(
        kind: NovoRudpFrameKind.endpoint,
        sessionId: channel.sessionId,
        streamId: PeerFileChannel.controlStream,
        objectId: BigInt.from(object),
        sequence: BigInt.zero,
        ackEpoch: BigInt.zero,
        payload: utf8.encode(
          jsonEncode({'v': 3, 'op': op, 'messageId': id, 'media': media}),
        ),
      ),
    );
  }

  @override
  Future<void> close() => incoming.close();
}

void main() {
  for (final scenario in [
    'authorize',
    'source',
    'wrong-object',
    'wrong-message',
    'wrong-media',
  ]) {
    test('cancel is scoped and stops delayed $scenario', () async {
      final root = await Directory.systemTemp.createTemp('peer-cancel-');
      final link = _Link();
      final entered = Completer<void>(), release = Completer<void>();
      var checks = 0, sources = 0;
      final repo = MessagingRepository(
        account: 'sender',
        call: (_, params) async {
          checks++;
          if (checks == 1 && scenario != 'source') {
            entered.complete();
            await release.future;
          }
          return {
            'messageId': _id,
            'assetId': _id,
            'fileId': _id,
            'media': 'image',
            'sender': 'sender',
            'recipient': 'receiver',
            'fileName': 'test.webp',
            'size': 3,
            'sha256': 'a' * 64,
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(seconds: 15))
                .toIso8601String(),
          };
        },
      );
      final lane = PeerFileChannel(
        link: link,
        repository: repo,
        peer: 'receiver',
        privateDirectory: root,
        canExchange: () => true,
        cache: ChatSentFileCache(
          cache: ChatDownloadCache(
            root: Directory('${root.path}/cache'),
            key: await AesGcm.with256bits().newSecretKey(),
          ),
          checkSession: () async {},
        ),
        mediaSource: (_) async {
          sources++;
          if (scenario == 'source' && sources == 1) {
            entered.complete();
            await release.future;
            // Cancellation must prevent even opening this source.
            return File('${root.path}/not-opened');
          }
          return null;
        },
      );
      try {
        link.control('request');
        await entered.future.timeout(const Duration(seconds: 2));
        link.control(
          'cancel',
          object: scenario == 'wrong-object' ? 2 : 1,
          id: scenario == 'wrong-message' ? _other : _id,
          media: scenario == 'wrong-media' ? 'voice' : 'image',
        );
        await Future<void>.delayed(Duration.zero);
        release.complete();
        await link.rejected.future.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);
        expect(checks, 1);
        expect(sources, scenario == 'authorize' ? 0 : 1);
        if (!scenario.startsWith('wrong-')) {
          link.control('request'); // Late retransmission must stay cancelled.
          await Future<void>.delayed(Duration.zero);
          expect(checks, 1);
          link.rejected = Completer<void>();
          link.control('request', object: 3); // A fresh attempt remains usable.
          await link.rejected.future.timeout(const Duration(seconds: 2));
          expect(checks, 2);
        }
      } finally {
        if (!release.isCompleted) release.complete();
        await lane.close();
        await link.close();
        await root.delete(recursive: true);
      }
    });
  }
}
