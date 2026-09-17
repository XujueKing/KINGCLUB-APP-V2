import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:dio/dio.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_receiver.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_download.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_file_sender.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_datagram_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_sent_file_cache.dart';
import 'package:kingclub/src/features/messaging/data/peer_file_channel.dart';
import 'package:kingclub/src/features/messaging/data/group_file_device_scope.dart';
import 'package:kingclub/src/features/messaging/data/group_file_scope_exchange.dart';

class HeldSendLink implements NovoRudpFrameLink {
  HeldSendLink(this.delegate);
  final NovoRudpFrameLink delegate;
  final entered = Completer<void>();
  final release = Completer<void>();
  int sends = 0;
  bool closed = false;
  @override
  NovoRudpSecureChannel get channel => delegate.channel;
  @override
  Stream<NovoRudpFrame> get frames => delegate.frames;
  @override
  Future<void> send(NovoRudpFrame frame) {
    sends++;
    if (!entered.isCompleted) entered.complete();
    return release.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  final path = Platform.environment['NOVORUDP_NATIVE_LIBRARY'];
  group('real encrypted UDP file transfer', () {
    late Directory directory;
    late NovoRudpSecureSession a, b;
    late NovoRudpSecureDatagramLink left, right;
    late RawDatagramSocket relay;
    late StreamSubscription relaySub;
    var packets = 0, dropped = 0, dropFinal = false, loss = false;
    setUp(() async {
      packets = dropped = 0;
      dropFinal = loss = false;
      directory = await Directory.systemTemp.createTemp(
        'kingclub-sender-test-',
      );
      final library = DynamicLibrary.open(path!);
      a = NovoRudpSecureSession.fromSeed(library: library, seed: Uint8List(32));
      b = NovoRudpSecureSession.fromSeed(
        library: library,
        seed: Uint8List.fromList(List.filled(32, 17)),
      );
      final init = a.start(b.peerId);
      final response = b.respond(init.offer, expectedPeer: a.peerId);
      final address = InternetAddress.loopbackIPv4;
      relay = await RawDatagramSocket.bind(address, 0);
      final l = await RawDatagramSocket.bind(address, 0);
      final r = await RawDatagramSocket.bind(address, 0);
      left = NovoRudpSecureDatagramLink.attach(
        socket: l,
        peer: address,
        peerPort: relay.port,
        channel: a.complete(init, response.response),
      );
      right = NovoRudpSecureDatagramLink.attach(
        socket: r,
        peer: address,
        peerPort: relay.port,
        channel: response.channel,
      );
      relay.writeEventsEnabled = false;
      relaySub = relay.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? packet;
        while ((packet = relay.receive()) != null) {
          packets++;
          final reverse = packet!.port == right.localPort;
          if (loss &&
              ((!reverse && packets % 7 == 0) || (reverse && dropFinal))) {
            if (reverse) dropFinal = false;
            dropped++;
            continue;
          }
          final sent = relay.send(
            packet.data,
            address,
            reverse ? left.localPort : right.localPort,
          );
          if (sent == 0) dropped++;
        }
      });
    });
    tearDown(() async {
      await left.close();
      await right.close();
      await relaySub.cancel();
      relay.close();
      a.dispose();
      b.dispose();
      await directory.delete(recursive: true);
    });
    Future<({File file, String hash})> source(List<int> bytes) async {
      final file = await File('${directory.path}/source.bin')
          .writeAsBytes(bytes);
      final hash = (await const DartSha256().hash(bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      return (file: file, hash: hash);
    }

    test(
      'sender refuses an expired live authorization before sending bytes',
      () async {
        final input = await source([1, 2, 3]);
        final sender = NovoRudpFileSender(
          link: left,
          file: input.file,
          streamId: BigInt.from(71),
          objectId: BigInt.from(92),
          size: 3,
          sha256: input.hash,
          canSend: () => false,
        );
        await expectLater(sender.run(), throwsStateError);
        expect(packets, 0);
      },
    );

    for (final mismatch in [false, true]) {
      test(
        'encrypted scope confirmation with delayed peer mismatch=$mismatch',
        () async {
          const message = '11111111-1111-4111-8111-111111111111';
          const group = '22222222-2222-4222-8222-222222222222';
          GroupFileDeviceScope scope(int epoch) => GroupFileDeviceScope.parse(
            {
              'kind': 'group-file',
              'messageId': message,
              'groupId': group,
              'sender': 'a',
              'recipient': 'b',
              'senderMembershipVersion': 1,
              'recipientMembershipVersion': epoch,
            },
            messageId: message,
            groupId: group,
            account: 'a',
            peer: 'b',
          );
          final first = GroupFileScopeExchange.confirm(left, scope(1));
          final checked = mismatch
              ? expectLater(first, throwsStateError)
              : first;
          await Future<void>.delayed(const Duration(milliseconds: 100));
          final second = GroupFileScopeExchange.confirm(
            right,
            scope(mismatch ? 2 : 1),
          );
          await Future.wait([
            checked,
            mismatch
                ? expectLater(
                    second,
                    throwsA(anyOf(isA<StateError>(), isA<TimeoutException>())),
                  )
                : second,
          ]);
        },
      );
    }

    for (final scenario in [
      'success',
      'missing',
      'wrong-member',
      'group-success',
      'group-rejoined',
      'group-stale-sender',
      'group-stale-recipient',
    ]) {
      test('peer file negotiation over encrypted UDP: $scenario', () async {
        const messageId = '00000000-0000-4000-8000-000000000001';
        const assetId = '00000000-0000-4000-8000-000000000002';
        final groupId = scenario.startsWith('group-')
            ? '00000000-0000-4000-8000-000000000003'
            : null;
        final bytes = List.generate(70000, (i) => i % 251);
        final input = await source(bytes);
        final cache = ChatSentFileCache(
          cache: ChatDownloadCache(
            root: Directory('${directory.path}/cache'),
            key: await DartAesGcm.with256bits().newSecretKey(),
          ),
          checkSession: () async {},
          temporaryDirectory: () async => directory,
        );
        if (scenario != 'missing') {
          await cache.retain(
            input.file,
            assetId: assetId,
            size: bytes.length,
            sha256: input.hash,
          );
        }
        var senderChecks = 0, receiverChecks = 0;
        MessagingRepository repository(String account) => MessagingRepository(
          account: account,
          call: (id, params) async {
            expect(id, 'K260916000686');
            expect(params['messageId'], messageId);
            expect(params['group'], groupId == null ? null : true);
            expect(params['peer'], account == 'a' ? 'b' : 'a');
            if (account == 'a') {
              senderChecks++;
            } else {
              receiverChecks++;
            }
            return {
              'messageId': messageId,
              'sender': scenario == 'wrong-member' && account == 'a'
                  ? 'outsider'
                  : 'a',
              'recipient': 'b',
              if (groupId != null) ...{
                'groupId': groupId,
                'senderMembershipVersion': scenario == 'group-stale-sender'
                    ? 2
                    : 1,
                'recipientMembershipVersion':
                    (scenario == 'group-rejoined' && receiverChecks > 1) ||
                        scenario == 'group-stale-recipient'
                    ? 2
                    : 1,
              },
              'assetId': assetId,
              'fileName': 'fixture.bin',
              'size': bytes.length,
              'sha256': input.hash,
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(seconds: 15))
                  .toIso8601String(),
            };
          },
        );
        final scope = groupId == null
            ? null
            : GroupFileDeviceScope.parse(
                {
                  'kind': 'group-file',
                  'groupId': groupId,
                  'messageId': messageId,
                  'sender': 'a',
                  'recipient': 'b',
                  'senderMembershipVersion': 1,
                  'recipientMembershipVersion': 1,
                },
                messageId: messageId,
                groupId: groupId,
                account: 'a',
                peer: 'b',
              );
        final sending = PeerFileChannel(
          link: left,
          repository: repository('a'),
          peer: 'b',
          groupScope: scope,
          cache: cache,
          privateDirectory: directory,
          canExchange: () => true,
        );
        final receiving = PeerFileChannel(
          link: right,
          repository: repository('b'),
          peer: 'a',
          groupScope: scope,
          cache: cache,
          privateDirectory: directory,
          canExchange: () => true,
        );
        addTearDown(sending.close);
        addTearDown(receiving.close);
        if (groupId != null) {
          await expectLater(
            receiving.authorize(assetId, sending: false),
            throwsStateError,
          );
        }
        if (scenario.startsWith('group-stale-')) {
          await expectLater(
            receiving.authorize(messageId, sending: false),
            throwsStateError,
          );
          await expectLater(
            sending.authorize(messageId, sending: true),
            throwsStateError,
          );
          expect(packets, 0);
          expect(senderChecks, 1);
          expect(receiverChecks, 1);
          return;
        }
        final authority = await receiving.authorize(messageId, sending: false);
        if (scenario == 'success' || scenario == 'group-success') {
          final transfer = await receiving.receive(authority, () => true);
          try {
            expect(await (await transfer.completed).readAsBytes(), bytes);
          } finally {
            await transfer.close();
          }
          expect(senderChecks, greaterThanOrEqualTo(2));
        } else {
          await expectLater(
            receiving.receive(authority, () => true),
            throwsStateError,
          );
          expect(senderChecks, scenario == 'group-rejoined' ? 0 : 1);
        }
        expect(receiverChecks, 2);
        await sending.close();
        await receiving.close();
        expect(
          await directory
              .list()
              .where((e) => e.path.contains('kingclub-peer-source-'))
              .toList(),
          isEmpty,
        );
      });
    }

    for (final throws in [false, true]) {
      test(
        'download coordinator cleans initialization permission ${throws ? 'error' : 'denial'}',
        () async {
          final input = await source([1, 2, 3]);
          var checks = 0;
          await expectLater(
            NovoRudpFileDownload.open(
              link: right,
              privateDirectory: directory,
              streamId: BigInt.from(71),
              objectId: BigInt.from(92),
              size: 3,
              sha256: input.hash,
              canReceive: () {
                if (++checks == 1) return true;
                if (throws) throw StateError('Permission check failed');
                return false;
              },
            ),
            throwsStateError,
          );
          expect(checks, 2);
          expect(
            await directory
                .list()
                .where((entry) => entry is Directory)
                .toList(),
            isEmpty,
          );
          expect(await input.file.readAsBytes(), [1, 2, 3]);
          expect(packets, 0);
        },
      );
    }

    test(
      'download coordinator verifies file and leaves shared lane open',
      () async {
        final bytes = List.generate(70000, (i) => i % 251);
        final input = await source(bytes);
        final download = await NovoRudpFileDownload.open(
          link: right,
          privateDirectory: directory,
          streamId: BigInt.from(71),
          objectId: BigInt.from(92),
          size: bytes.length,
          sha256: input.hash,
          canReceive: () => true,
        );
        addTearDown(download.close);
        await left.send(
          NovoRudpFrame(
            kind: NovoRudpFrameKind.data,
            sessionId: left.channel.sessionId,
            streamId: BigInt.from(70),
            objectId: BigInt.from(92),
            sequence: BigInt.zero,
            ackEpoch: BigInt.zero,
            payload: [9],
          ),
        );
        await NovoRudpFileSender(
          link: left,
          file: input.file,
          streamId: BigInt.from(71),
          objectId: BigInt.from(92),
          size: bytes.length,
          sha256: input.hash,
        ).run();
        final received = await download.completed;
        expect(await received.readAsBytes(), bytes);
        await download.close();
        expect(await received.exists(), false);
        final arrival = right.frames.first;
        await left.send(
          NovoRudpFrame(
            kind: NovoRudpFrameKind.data,
            sessionId: left.channel.sessionId,
            streamId: BigInt.from(99),
            objectId: BigInt.one,
            sequence: BigInt.zero,
            ackEpoch: BigInt.zero,
            payload: [1, 2, 3],
          ),
        );
        expect((await arrival.timeout(const Duration(seconds: 2))).payload, [
          1,
          2,
          3,
        ]);
      },
    );

    test(
      'download coordinator rejects corrupt content and removes partial file',
      () async {
        final input = await source([1, 2, 3]);
        final download = await NovoRudpFileDownload.open(
          link: right,
          privateDirectory: directory,
          streamId: BigInt.from(71),
          objectId: BigInt.from(92),
          size: 3,
          sha256: input.hash,
          canReceive: () => true,
        );
        final rejected = expectLater(download.completed, throwsFormatException);
        await left.send(
          NovoRudpFrame(
            kind: NovoRudpFrameKind.data,
            sessionId: left.channel.sessionId,
            streamId: BigInt.from(71),
            objectId: BigInt.from(92),
            sequence: BigInt.zero,
            ackEpoch: BigInt.zero,
            payload: [1, 2, 4],
          ),
        );
        await rejected;
        await download.close();
        expect(
          await directory.list().where((entry) => entry is Directory).toList(),
          isEmpty,
        );
      },
    );

    for (final revocation in ['none', 'media', 'peer']) {
      test(
        'chat downloader uses verified peer file; final revocation=$revocation',
        () async {
          final revoked = revocation != 'none';
          final bytes = List.generate(1024 * 1024 + 3, (i) => i % 251);
          final input = await source(bytes);
          const id = '12345678-1234-4234-8234-123456789012';
          const asset = '22345678-1234-4234-8234-123456789012';
          var grants = 0, httpRequests = 0, authorities = 0;
          Future<void>? sending;
          final repository = MessagingRepository(
            account: 'a',
            call: (api, params) async {
              if (api == 'K260916000686') {
                authorities++;
                expect(params, {'messageId': id, 'peer': 'b'});
                if (revocation == 'peer') throw StateError('peer revoked');
                return {
                  'messageId': id,
                  'sender': 'b',
                  'recipient': 'a',
                  'assetId': asset,
                  'fileName': 'sample.bin',
                  'size': bytes.length,
                  'sha256': input.hash,
                  'expiresAt': DateTime.now()
                      .toUtc()
                      .add(const Duration(seconds: 15))
                      .toIso8601String(),
                };
              }
              if (++grants == 2 && revoked) throw StateError('revoked');
              return {
                'messageId': id,
                'file': {
                  'assetId': asset,
                  'fileName': 'sample.bin',
                  'size': bytes.length,
                  'sha256': input.hash,
                  'chunkBytes': 1024 * 1024,
                  'chunkCount':
                      (bytes.length + 1024 * 1024 - 1) ~/ (1024 * 1024),
                  'contentType': 'application/octet-stream',
                  'path': '/kingclub/chat-file/$id',
                  'headers': {'authorization': 'Bearer synthetic-only'},
                },
              };
            },
          );
          final dio = Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  httpRequests++;
                  handler.reject(DioException(requestOptions: options));
                },
              ),
            );
          final downloader = ChatFileDownloader(
            repository: repository,
            checkSession: () async {},
            dio: dio,
            temporaryDirectory: () async => directory,
            peerDownload: (ref, active) async {
              final reception = await NovoRudpFileDownload.open(
                link: right,
                privateDirectory: directory,
                streamId: BigInt.from(71),
                objectId: BigInt.from(92),
                size: ref.size,
                sha256: ref.sha256,
                canReceive: active,
              );
              sending = NovoRudpFileSender(
                link: left,
                file: input.file,
                streamId: BigInt.from(71),
                objectId: BigInt.from(92),
                size: bytes.length,
                sha256: input.hash,
              ).run();
              return reception;
            },
          );
          addTearDown(downloader.dispose);
          final progress = <int>[];
          final result = downloader.download(
            ChatFileReference(
              messageId: id,
              assetId: asset,
              fileName: 'sample.bin',
              size: bytes.length,
              sha256: input.hash,
              sender: 'b',
            ),
            onProgress: (received, total) {
              expect(total, bytes.length);
              progress.add(received);
            },
          );
          if (revoked) {
            await expectLater(result, throwsStateError);
            expect(progress.every((n) => n < bytes.length), isTrue);
          } else {
            final file = await result;
            expect(await file.readAsBytes(), bytes);
            expect(file.path, contains('kingclub-chat-download-'));
            expect(progress.last, bytes.length);
            expect(progress.any((n) => n > 0 && n < bytes.length), isTrue);
          }
          await sending;
          expect(grants, 2);
          expect(authorities, 1);
          expect(httpRequests, 0);
          await downloader.dispose();
          expect(
            await directory
                .list()
                .where((entry) => entry is Directory)
                .toList(),
            isEmpty,
          );
        },
      );
    }

    test('idle download ignores duplicate fragments and ACK polls', () async {
      final bytes = List<int>.filled(NovoRudpFileReceiver.chunkSize + 1, 7);
      final input = await source(bytes);
      final download = await NovoRudpFileDownload.open(
        link: right,
        privateDirectory: directory,
        streamId: BigInt.from(71),
        objectId: BigInt.from(92),
        size: bytes.length,
        sha256: input.hash,
        canReceive: () => true,
        idleTimeout: const Duration(milliseconds: 300),
      );
      final expectation = expectLater(
        download.completed,
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.message,
            'reason',
            'File receive stalled',
          ),
        ),
      );
      NovoRudpFrame frame(NovoRudpFrameKind kind) => NovoRudpFrame(
        kind: kind,
        sessionId: left.channel.sessionId,
        streamId: BigInt.from(71),
        objectId: BigInt.from(92),
        sequence: BigInt.zero,
        ackEpoch: BigInt.zero,
        payload: kind == NovoRudpFrameKind.data
            ? bytes.sublist(0, NovoRudpFileReceiver.chunkSize)
            : [],
      );
      await left.send(frame(NovoRudpFrameKind.data));
      final repeat = Timer.periodic(const Duration(milliseconds: 50), (_) {
        unawaited(left.send(frame(NovoRudpFrameKind.data)));
        unawaited(left.send(frame(NovoRudpFrameKind.done)));
      });
      try {
        await expectation.timeout(const Duration(seconds: 2));
      } finally {
        repeat.cancel();
        expect(download.receivedBytes, NovoRudpFileReceiver.chunkSize);
        await download.close();
      }
    });

    test('idle download extends only while new fragments arrive', () async {
      final bytes = List<int>.filled(NovoRudpFileReceiver.chunkSize * 3, 9);
      final input = await source(bytes);
      final download = await NovoRudpFileDownload.open(
        link: right,
        privateDirectory: directory,
        streamId: BigInt.from(71),
        objectId: BigInt.from(92),
        size: bytes.length,
        sha256: input.hash,
        canReceive: () => true,
        idleTimeout: const Duration(milliseconds: 500),
      );
      try {
        for (var index = 0; index < 3; index++) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await left.send(
            NovoRudpFrame(
              kind: NovoRudpFrameKind.data,
              sessionId: left.channel.sessionId,
              streamId: BigInt.from(71),
              objectId: BigInt.from(92),
              sequence: BigInt.from(index),
              ackEpoch: BigInt.zero,
              payload: bytes.sublist(
                index * NovoRudpFileReceiver.chunkSize,
                (index + 1) * NovoRudpFileReceiver.chunkSize,
              ),
            ),
          );
        }
        await left.send(
          NovoRudpFrame(
            kind: NovoRudpFrameKind.done,
            sessionId: left.channel.sessionId,
            streamId: BigInt.from(71),
            objectId: BigInt.from(92),
            sequence: BigInt.zero,
            ackEpoch: BigInt.zero,
            payload: [],
          ),
        );
        expect(await (await download.completed).readAsBytes(), bytes);
      } finally {
        await download.close();
      }
    });

    for (final revoke in [false, true]) {
      test(
        'download coordinator cleans ${revoke ? 'revoked' : 'timed out'} transfer',
        () async {
          final input = await source([1, 2, 3]);
          var allowed = true;
          final download = await NovoRudpFileDownload.open(
            link: right,
            privateDirectory: directory,
            streamId: BigInt.from(71),
            objectId: BigInt.from(92),
            size: 3,
            sha256: input.hash,
            canReceive: () => allowed,
            deadline: const Duration(milliseconds: 200),
          );
          final expectation = expectLater(
            download.completed,
            revoke ? throwsStateError : throwsA(isA<TimeoutException>()),
          );
          if (revoke) {
            allowed = false;
            await left.send(
              NovoRudpFrame(
                kind: NovoRudpFrameKind.data,
                sessionId: left.channel.sessionId,
                streamId: BigInt.from(71),
                objectId: BigInt.from(92),
                sequence: BigInt.zero,
                ackEpoch: BigInt.zero,
                payload: [1, 2, 3],
              ),
            );
          }
          await expectation;
          await download.close();
          expect(
            await directory
                .list()
                .where((entry) => entry is Directory)
                .toList(),
            isEmpty,
          );
          expect(await input.file.exists(), true);
        },
      );
    }

    for (final transferBytes in [
      70 * NovoRudpFileReceiver.chunkSize + 21,
      18 * 1024 * 1024,
    ]) {
      test(
        'dropped data and final ACK recover without duplicate file delivery ($transferBytes bytes)',
        () async {
          loss = true;
          final bytes = List.generate(transferBytes, (i) => i % 251);
          final input = await source(bytes);
          final receiver = await NovoRudpFileReceiver.create(
            privateDirectory: directory,
            sessionId: left.channel.sessionId,
            streamId: BigInt.one,
            objectId: BigInt.two,
            size: bytes.length,
            sha256: input.hash,
          );
          addTearDown(receiver.close);
          var finalAcks = 0;
          final errors = <Object>[];
          final sub = right.frames.listen((frame) async {
            try {
              final ack = await receiver.receiveAuthenticated(frame);
              if (ack == null) return;
              if ((jsonDecode(utf8.decode(ack.payload))
                      as Map)['receiver_done'] ==
                  true) {
                finalAcks++;
                if (finalAcks == 1) dropFinal = true;
              }
              // Local-buffer failure is not an acknowledged send; the sender's
              // ACK request timer recovers it just like an actually dropped ACK.
              try {
                await right.send(ack);
              } on SocketException {
                // A subsequent ACK request retries a locally unaccepted send.
              }
            } catch (error) {
              errors.add(error);
            }
          });
          addTearDown(sub.cancel);
          final sender = NovoRudpFileSender(
            link: left,
            file: input.file,
            streamId: BigInt.one,
            objectId: BigInt.two,
            size: bytes.length,
            sha256: input.hash,
            ackWait: const Duration(milliseconds: 150),
            deadline: const Duration(seconds: 90),
          );
          final elapsed = Stopwatch()..start();
          await sender.run();
          debugPrint(
            'NOVORUDP_LOOPBACK_FILE bytes=$transferBytes elapsedMs=${elapsed.elapsedMilliseconds} packets=$packets dropped=$dropped',
          );
          expect(errors, isEmpty);
          expect(dropped, greaterThan(0));
          expect(finalAcks, greaterThanOrEqualTo(2));
          expect(await (await receiver.verifiedFile()).readAsBytes(), bytes);
          await expectLater(sender.run(), throwsStateError);
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }
    test(
      'new sender resumes live partial receiver without another data pass',
      () async {
        final bytes = List.generate(
          80 * NovoRudpFileReceiver.chunkSize,
          (i) => i % 251,
        );
        final input = await source(bytes);
        final receiver = await NovoRudpFileReceiver.create(
          privateDirectory: directory,
          sessionId: left.channel.sessionId,
          streamId: BigInt.one,
          objectId: BigInt.two,
          size: bytes.length,
          sha256: input.hash,
        );
        addTearDown(receiver.close);
        final half = Completer<void>();
        var dataFrames = 0, repairFrames = 0;
        final errors = <Object>[];
        final sub = right.frames.listen((frame) async {
          try {
            final ack = await receiver.receiveAuthenticated(frame);
            if (frame.kind == NovoRudpFrameKind.data) {
              if (++dataFrames == 40) half.complete();
            }
            if (frame.kind == NovoRudpFrameKind.repair) {
              repairFrames++;
              expect(frame.sequence.toInt(), greaterThanOrEqualTo(40));
            }
            if (ack != null) await right.send(ack);
          } catch (e) {
            errors.add(e);
          }
        });
        addTearDown(sub.cancel);
        for (var i = 0; i < 40; i++) {
          await left.send(
            NovoRudpFrame(
              kind: NovoRudpFrameKind.data,
              sessionId: left.channel.sessionId,
              streamId: BigInt.one,
              objectId: BigInt.two,
              sequence: BigInt.from(i),
              ackEpoch: BigInt.zero,
              payload: bytes.sublist(
                i * NovoRudpFileReceiver.chunkSize,
                (i + 1) * NovoRudpFileReceiver.chunkSize,
              ),
            ),
          );
        }
        await half.future.timeout(const Duration(seconds: 3));
        NovoRudpFileSender sender() => NovoRudpFileSender(
          link: left,
          file: input.file,
          streamId: BigInt.one,
          objectId: BigInt.two,
          size: bytes.length,
          sha256: input.hash,
          ackWait: const Duration(milliseconds: 150),
        );
        await sender().run();
        expect(errors, isEmpty);
        expect(dataFrames, 40);
        expect(repairFrames, greaterThan(0));
        expect(await (await receiver.verifiedFile()).readAsBytes(), bytes);
        final repaired = repairFrames;
        await sender().run();
        expect(dataFrames, 40);
        expect(repairFrames, repaired);
      },
    );
    test(
      'unreachable receiver times out and cancellation wakes ACK wait',
      () async {
        final input = await source([1, 2, 3]);
        NovoRudpFileSender sender() => NovoRudpFileSender(
          link: left,
          file: input.file,
          streamId: BigInt.one,
          objectId: BigInt.two,
          size: 3,
          sha256: input.hash,
          ackWait: const Duration(milliseconds: 30),
          maxStalls: 2,
        );
        await expectLater(sender().run(), throwsA(isA<TimeoutException>()));
        final cancelled = sender();
        final running = cancelled.run();
        Timer(const Duration(milliseconds: 10), cancelled.cancel);
        await expectLater(running, throwsStateError);
      },
    );
    test(
      'account change stops a pending transfer and releases its source',
      () async {
        final input = await source([1, 2, 3]);
        final sender = NovoRudpFileSender(
          link: left,
          file: input.file,
          streamId: BigInt.one,
          objectId: BigInt.two,
          size: 3,
          sha256: input.hash,
          ackWait: const Duration(minutes: 1),
        );
        final running = sender.run();
        final switched = Timer(const Duration(milliseconds: 20), () {
          MemberQrMemory.clear();
          SecureSessionStore.changes.add(null);
        });
        addTearDown(switched.cancel);
        await expectLater(
          running.timeout(const Duration(seconds: 2)),
          throwsStateError,
        );
        final sent = packets;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(packets, sent);
        final renamed = await input.file.rename(
          '${directory.path}/released.bin',
        );
        expect(await renamed.readAsBytes(), [1, 2, 3]);
      },
    );
    for (final reason in ['cancel', 'account', 'deadline']) {
      test(
        '$reason interrupts a stalled transport without closing shared lane',
        () async {
          final input = await source([1, 2, 3]);
          final held = HeldSendLink(left);
          final sender = NovoRudpFileSender(
            link: held,
            file: input.file,
            streamId: BigInt.one,
            objectId: BigInt.two,
            size: 3,
            sha256: input.hash,
            deadline: reason == 'deadline'
                ? const Duration(milliseconds: 150)
                : const Duration(minutes: 1),
          );
          final running = sender.run();
          final assertion = expectLater(
            running.timeout(const Duration(seconds: 2)),
            reason == 'deadline'
                ? throwsA(
                    isA<TimeoutException>().having(
                      (error) => error.message,
                      'message',
                      'File transfer deadline',
                    ),
                  )
                : throwsStateError,
          );
          await held.entered.future.timeout(const Duration(seconds: 1));
          if (reason == 'cancel') sender.cancel();
          if (reason == 'account') {
            MemberQrMemory.clear();
            SecureSessionStore.changes.add(null);
          }
          await assertion;
          expect(held.closed, isFalse);
          final renamed = await input.file.rename(
            '${directory.path}/released.bin',
          );
          expect(await renamed.readAsBytes(), [1, 2, 3]);
          held.release.completeError(const SocketException('late failure'));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(held.sends, 1);
        },
      );
    }
    test('changed source fails before any datagram leaves', () async {
      final input = await source([1, 2, 3]);
      await input.file.writeAsBytes([3, 2, 1]);
      final sender = NovoRudpFileSender(
        link: left,
        file: input.file,
        streamId: BigInt.one,
        objectId: BigInt.two,
        size: 3,
        sha256: input.hash,
      );
      await expectLater(sender.run(), throwsFormatException);
      expect(packets, 0);
    });
  }, skip: path == null ? 'Set NOVORUDP_NATIVE_LIBRARY' : false);
}
