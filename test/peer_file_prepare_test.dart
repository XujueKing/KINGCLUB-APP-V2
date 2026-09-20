import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_sent_file_cache.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/peer_file_channel.dart';
import 'package:kingclub/src/features/messaging/data/peer_file_authority.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class _Channel implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Link implements NovoRudpFrameLink {
  _Link(this.media);
  final String? media;
  @override
  final channel = _Channel();
  final incoming = StreamController<NovoRudpFrame>.broadcast();
  int requests = 0;
  bool prepared = false;
  Completer<void>? readyGate;
  @override
  Stream<NovoRudpFrame> get frames => incoming.stream;
  @override
  Future<void> send(NovoRudpFrame frame) async {
    final body = jsonDecode(utf8.decode(frame.payload)) as Map<String, dynamic>;
    if (body['op'] != 'request') return;
    expect(body['media'], media);
    expect(body['v'], media == null ? 1 : 3);
    expect(prepared, true);
    requests++;
    body['op'] = 'ready';
    void ready() => incoming.add(
      NovoRudpFrame(
        kind: frame.kind,
        sessionId: frame.sessionId,
        streamId: frame.streamId,
        objectId: frame.objectId,
        sequence: BigInt.zero,
        ackEpoch: BigInt.zero,
        payload: utf8.encode(jsonEncode(body)),
      ),
    );
    final gate = readyGate;
    if (gate == null) {
      ready();
    } else {
      unawaited(gate.future.then((_) => ready()));
    }
  }

  @override
  Future<void> close() => incoming.close();
}

void main() {
  for (final scenario in [
    (null, false, false),
    (null, true, false),
    (null, false, true),
    for (final media in PeerFileAuthority.mediaKinds) (media, false, false),
  ]) {
    final (media, cancel, delayedReady) = scenario;
    test(
      'REQUEST waits for cache preparation, media=$media cancel=$cancel delayedReady=$delayedReady',
      () async {
        final root = await Directory.systemTemp.createTemp('peer-prepare-');
        final link = _Link(media);
        if (delayedReady) link.readyGate = Completer<void>();
        const id = '11111111-1111-4111-8111-111111111111';
        final repo = MessagingRepository(
          account: 'receiver',
          call: (_, params) async {
            expect(params['media'], media);
            return {
              'messageId': id,
              'assetId': id,
              'media': ?media,
              if (media != null) 'fileId': id,
              'sender': 'sender',
              'recipient': 'receiver',
              'fileName': 'test.bin',
              'size': 3,
              'sha256': 'a' * 64,
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(seconds: 15))
                  .toIso8601String(),
            };
          },
        );
        final channel = PeerFileChannel(
          link: link,
          repository: repo,
          peer: 'sender',
          privateDirectory: root,
          canExchange: () => true,
          cache: ChatSentFileCache(
            cache: ChatDownloadCache(
              root: Directory('${root.path}/cache'),
              key: await AesGcm.with256bits().newSecretKey(),
            ),
            checkSession: () async {},
          ),
        );
        final entered = Completer<void>(), release = Completer<void>();
        var active = true;
        try {
          final authority = await channel.authorize(
            id,
            sending: false,
            media: media,
          );
          final receiving = channel.receive(
            authority,
            () => active,
            prepare: (_) async {
              entered.complete();
              await release.future;
              link.prepared = true;
            },
          );
          await entered.future.timeout(const Duration(seconds: 2));
          expect(link.requests, 0);
          if (cancel) active = false;
          release.complete();
          if (cancel) {
            await expectLater(receiving, throwsStateError);
            expect(link.requests, 0);
          } else {
            final download = await receiving.timeout(
              const Duration(seconds: 2),
            );
            expect(link.requests, 1);
            if (delayedReady) {
              var ended = false;
              unawaited(
                download.completed.then<void>(
                  (_) => ended = true,
                  onError: (Object _) {
                    ended = true;
                  },
                ),
              );
              // A real source can need >3s to restore its encrypted blocks.
              // The connection has returned; that must not abort the transfer.
              await Future<void>.delayed(const Duration(milliseconds: 3200));
              expect(ended, false);
              expect(link.requests, greaterThan(1));
              link.readyGate!.complete();
              await Future<void>.delayed(const Duration(milliseconds: 20));
              expect(ended, false);
            }
            await download.close();
          }
        } finally {
          await channel.close();
          await link.close();
          expect(await root.list().toList(), isEmpty);
          await root.delete(recursive: true);
        }
      },
    );
  }
}
