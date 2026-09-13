import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/call_relay_configuration.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kingclub/src/features/messaging/data/call_media_session.dart';
import 'package:kingclub/src/features/messaging/data/native_call_media.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

const callId = '00000000-0000-4000-8000-000000000001';
CallSnapshot snapshot(String account) => CallSnapshot.parse({
  'callId': callId,
  'caller': 'a',
  'callee': 'b',
  'mediaKind': 'audio',
  'phase': 'connecting',
  'version': 1,
  'deadlineMs': 9999999999999,
}, account);

class Media extends NativeCallMedia {
  Media(this.emit)
    : super(
        video: false,
        iceServers: [],
        capture: (_) async => throw StateError('unused capture'),
      );
  final void Function(RTCIceCandidate) emit;
  int descriptions = 0, answers = 0, closes = 0, restarts = 0, prepared = 0;
  Completer<void>? opening;
  @override
  Future<void> open() async {
    await opening?.future;
  }

  @override
  Future<RTCSessionDescription> offer() async {
    emit(RTCIceCandidate('candidate:fixture', '0', 0));
    return RTCSessionDescription('v=0\r\n', 'offer');
  }

  @override
  Future<RTCSessionDescription> answer() async {
    answers++;
    emit(RTCIceCandidate('candidate:fixture', '0', 0));
    return RTCSessionDescription('v=0\r\n', 'answer');
  }

  @override
  Future<void> remoteDescription(RTCSessionDescription value) async {
    descriptions++;
  }

  @override
  Future<RTCSessionDescription> restartOffer({
    required String callId,
    required CallRelayConfiguration relay,
  }) async {
    restarts++;
    return offer();
  }

  @override
  Future<void> prepareRemoteRestart({
    required String callId,
    required CallRelayConfiguration relay,
  }) async {
    prepared++;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

void main() {
  test('both peers renegotiate one generation and retry a lost restart offer acknowledgement', () async {
    var generation = 0, lostRestartAck = true;
    final signals = <Map<String, dynamic>>[];
    final offerIds = <String>[];
    CallRepository repository(String account) => CallRepository(
      MessagingRepository(
        account: account,
        call: (method, params) async {
          if (method == 'K260913000645') {
            return {
              'call': {
                'callId': callId,
                'caller': 'a',
                'callee': 'b',
                'mediaKind': 'audio',
                'phase': 'active',
                'version': 3,
                'deadlineMs': 9999999999999,
              },
            };
          }
          if (method == 'K260914000648') {
            final expiry =
                (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600) * 1000;
            return {
              'expiresAtMs': expiry,
              'iceServers': [
                {
                  'urls': ['turn:relay.example'],
                  'username':
                      '${expiry ~/ 1000}:0123456789abcdef0123456789abcdef',
                  'credential': 'AAAAAAAAAAAAAAAAAAAAAAAAAAA=',
                },
              ],
            };
          }
          if (method == 'K260913000647') {
            if (account == 'b' && generation == 1) {
              expect(params['renewLease'], false);
            }
            final rows = signals
                .where(
                  (row) =>
                      row['sender'] != account &&
                      row['sequence'] > params['after'] &&
                      row['signal']['generation'] == generation,
                )
                .toList();
            return {
              'items': rows,
              'generation': generation,
              'hasMore': false,
              'nextSequence': rows.isEmpty
                  ? params['after']
                  : rows.last['sequence'],
            };
          }
          final signal = Map<String, dynamic>.from(params['signal'] as Map);
          if (signal['kind'] == 'offer' && signal['generation'] == 1) {
            offerIds.add(signal['clientSignalId']);
          }
          final existing = signals
              .where(
                (row) =>
                    row['signal']['clientSignalId'] == signal['clientSignalId'],
              )
              .toList();
          if (existing.isNotEmpty) {
            return {
              'sequence': existing.first['sequence'],
              'generation': generation,
              'replay': true,
            };
          }
          if (signal['kind'] == 'offer' &&
              signal['generation'] == generation + 1) {
            generation++;
          }
          if (signal['generation'] != generation) {
            throw const AuthFailure('CHAT_CALL_NEGOTIATION_CONFLICT', 'stale');
          }
          signals.add({
            'sender': account,
            'sequence': signals.length + 1,
            'signal': signal,
          });
          if (signal['kind'] == 'offer' && generation == 1 && lostRestartAck) {
            lostRestartAck = false;
            throw const AuthFailure('NETWORK_ERROR', 'lost ACK');
          }
          return {
            'sequence': signals.length,
            'generation': generation,
            'replay': false,
          };
        },
      ),
    );
    late Media callerMedia, calleeMedia;
    final caller = CallMediaSession(
      repository: repository('a'),
      call: snapshot('a'),
      mediaFactory: (emit) => callerMedia = Media(emit),
    );
    final callee = CallMediaSession(
      repository: repository('b'),
      call: snapshot('b'),
      mediaFactory: (emit) => calleeMedia = Media(emit),
    );
    await caller.flush();
    await callee.sync();
    await caller.sync();
    expect(callerMedia.descriptions, 1);
    expect(calleeMedia.descriptions, 1);
    // An old queued ICE must not prevent the recipient reading the new offer.
    calleeMedia.emit(RTCIceCandidate('candidate:old', '0', 0));
    await expectLater(caller.restart(), throwsA(isA<AuthFailure>()));
    expect(caller.generation, 1);
    await callee.sync(renewLease: false);
    expect(callee.generation, 1);
    expect(
      callee.relayExpiresAtMs,
      greaterThan(DateTime.now().millisecondsSinceEpoch),
    );
    expect(calleeMedia.prepared, 1);
    await caller.sync();
    expect(offerIds, hasLength(2));
    expect(offerIds.first, offerIds.last);
    expect(callerMedia.restarts, 1);
    expect(callerMedia.descriptions, 2);
    expect(calleeMedia.descriptions, 2);
    expect(calleeMedia.answers, 2);
    expect(caller.pendingSignals, 0);
    expect(callee.pendingSignals, 0);
    await caller.close();
    await callee.close();
  });

  test(
    'SDP precedes synchronous ICE and failed send reuses the same identity',
    () async {
      final sent = <Map<String, dynamic>>[];
      var fail = true;
      final repository = CallRepository(
        MessagingRepository(
          account: 'a',
          call: (id, params) async {
            final signal = Map<String, dynamic>.from(params['signal'] as Map);
            sent.add(signal);
            if (fail) {
              fail = false;
              throw Exception('connection lost');
            }
            return {'sequence': sent.length, 'generation': 0, 'replay': false};
          },
        ),
      );
      final session = CallMediaSession(
        repository: repository,
        call: snapshot('a'),
        mediaFactory: Media.new,
      );
      await expectLater(session.flush(), throwsException);
      expect(session.pendingSignals, 2);
      await session.flush();
      expect(sent.map((e) => e['kind']), ['offer', 'offer', 'ice']);
      expect(sent[0]['clientSignalId'], sent[1]['clientSignalId']);
      expect(session.pendingSignals, 0);
      await session.close();
    },
  );
  test(
    'callee answer retry never reapplies remote offer or regenerates answer',
    () async {
      late Media media;
      var fail = true;
      final cursors = <int>[];
      final sent = <Map<String, dynamic>>[];
      final repository = CallRepository(
        MessagingRepository(
          account: 'b',
          call: (id, params) async {
            if (id == 'K260913000647') {
              final after = params['after'] as int;
              cursors.add(after);
              return {
                'items': after == 0
                    ? [
                        {
                          'sequence': 1,
                          'signal': {
                            'callId': callId,
                            'clientSignalId':
                                '00000000-0000-4000-8000-000000000002',
                            'generation': 0,
                            'kind': 'offer',
                            'sdp': 'v=0\r\n',
                          },
                        },
                      ]
                    : [],
                'nextSequence': 1,
                'generation': 0,
                'hasMore': false,
              };
            }
            final signal = Map<String, dynamic>.from(params['signal'] as Map);
            sent.add(signal);
            if (fail) {
              fail = false;
              throw Exception('ack lost');
            }
            return {
              'sequence': sent.length + 1,
              'generation': 0,
              'replay': false,
            };
          },
        ),
      );
      final session = CallMediaSession(
        repository: repository,
        call: snapshot('b'),
        mediaFactory: (emit) => media = Media(emit),
      );
      await expectLater(session.sync(), throwsException);
      await session.sync();
      expect(media.descriptions, 1);
      expect(media.answers, 1);
      expect(cursors, [0, 1]);
      expect(sent.map((e) => e['kind']), ['answer', 'answer', 'ice']);
      expect(sent[0]['clientSignalId'], sent[1]['clientSignalId']);
      await session.close();
    },
  );
  test('close during opening suppresses all later signaling', () async {
    final opening = Completer<void>();
    var requests = 0;
    late Media media;
    final session = CallMediaSession(
      repository: CallRepository(
        MessagingRepository(
          account: 'a',
          call: (_, _) async {
            requests++;
            return {};
          },
        ),
      ),
      call: snapshot('a'),
      mediaFactory: (emit) => media = Media(emit)..opening = opening,
    );
    final start = session.start();
    final assertion = expectLater(start, throwsStateError);
    await session.close();
    opening.complete();
    await assertion;
    expect(requests, 0);
    expect(media.descriptions, 0);
    expect(session.pendingSignals, 0);
  });
}
