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
  int descriptions = 0, answers = 0, closes = 0;
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
  Future<void> close() async {
    closes++;
  }
}

void main() {
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
