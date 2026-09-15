import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart'
    show RtpCapabilities;
import 'package:kingclub/src/features/messaging/data/group_call_media_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

const callId = '00000000-0000-4000-8000-000000000001';
const resourceId = '00000000-0000-4000-8000-000000000002';
const otherId = '00000000-0000-4000-8000-000000000003';
GroupCallMediaRepository repository(ChatApiCall api) =>
    GroupCallMediaRepository(
      MessagingRepository(account: 'me', call: api),
      GroupCallSnapshot.parse({
        'callId': callId,
        'groupId': otherId,
        'mediaKind': 'audio',
        'version': 1,
        'endedAtMs': null,
        'participants': [
          {'account': 'me', 'phase': 'joined', 'deadlineMs': 1000},
          {'account': 'friend', 'phase': 'joined', 'deadlineMs': 1000},
        ],
      }, 'me'),
    );
Map<String, dynamic> source({
  String account = 'friend',
  String kind = 'audio',
  String id = resourceId,
}) => {'producerId': id, 'userAccount': account, 'kind': kind, 'paused': false};
void main() {
  test('parses signaling parameters through the pinned SDK types', () async {
    final codec = {
      'mimeType': 'audio/opus',
      'kind': 'audio',
      'clockRate': 48000,
      'channels': 2,
      'preferredPayloadType': 100,
      'payloadType': 100,
      'parameters': <String, dynamic>{},
      'rtcpFeedback': <dynamic>[],
    };
    final repo = repository((_, params) async {
      final command = params['command'] as Map;
      switch (command['type']) {
        case 'capabilities':
          return {
            'rtpCapabilities': {
              'codecs': [codec],
              'headerExtensions': <dynamic>[],
            },
          };
        case 'createTransport':
          return {
            'transport': {
              'id': otherId,
              'iceParameters': {
                'usernameFragment': 'synthetic',
                'password': 'synthetic-test-only-password',
                'iceLite': true,
              },
              'iceCandidates': [
                {
                  'foundation': 'test',
                  'priority': 123,
                  'ip': '127.0.0.1',
                  'protocol': 'udp',
                  'port': 41000,
                  'type': 'host',
                },
              ],
              'dtlsParameters': {
                'role': 'auto',
                'fingerprints': [
                  {
                    'algorithm': 'sha-256',
                    'value': List.filled(32, 'AB').join(':'),
                  },
                ],
              },
            },
          };
        case 'consume':
          return {
            'consumer': {
              'id': otherId,
              'producerId': resourceId,
              'kind': 'audio',
              'rtpParameters': {
                'codecs': [codec],
                'headerExtensions': <dynamic>[],
                'encodings': [
                  {'ssrc': 1234},
                ],
                'rtcp': {'cname': 'synthetic', 'reducedSize': true},
              },
            },
          };
        default:
          throw StateError('Unexpected command');
      }
    });
    final caps = await repo.capabilities();
    expect(caps.codecs.single.mimeType, 'audio/opus');
    final transport = await repo.createTransport(sending: false);
    expect(transport.iceCandidates.single.port, 41000);
    final consumer = await repo.consume(
      transport.id,
      const GroupMediaSource(resourceId, 'friend', 'audio', false),
      caps,
    );
    expect(consumer.rtpParameters.codecs.single.clockRate, 48000);
  });
  test(
    'passive constructor and bound signaling with immutable member sources',
    () async {
      final requests = <Map<String, dynamic>>[];
      final repo = repository((api, params) async {
        expect(api, 'K260915000682');
        requests.add(params);
        return {
          'sources': [source()],
        };
      });
      expect(requests, isEmpty);
      final sources = await repo.sources();
      expect(requests.single, {
        'callId': callId,
        'command': {'type': 'sources'},
      });
      expect(sources.single.account, 'friend');
      expect(() => sources.clear(), throwsUnsupportedError);
    },
  );
  test(
    'rejects foreign, self, duplicate and audio-call video sources',
    () async {
      for (final rows in [
        [source(account: 'stranger')],
        [source(account: 'me')],
        [source(), source(id: otherId)],
        [source(kind: 'video')],
        [source()..['paused'] = 'false'],
      ]) {
        final repo = repository((_, _) async => {'sources': rows});
        await expectLater(repo.sources(), throwsFormatException);
      }
    },
  );
  test('drops a delayed response and sends no commands after close', () async {
    var requests = 0;
    final response = Completer<Map<String, dynamic>>();
    final repo = repository((_, _) {
      requests++;
      return response.future;
    });
    final pending = repo.sources();
    repo.close();
    response.complete({
      'sources': [source()],
    });
    await expectLater(pending, throwsStateError);
    await expectLater(repo.sources(), throwsStateError);
    expect(requests, 1);
  });
  test(
    'rejects mismatched consumer source and incorrect control acknowledgements',
    () async {
      final repo = repository((_, params) async {
        final command = params['command'] as Map;
        if (command['type'] == 'consume') {
          return {
            'consumer': {'id': otherId, 'producerId': otherId, 'kind': 'audio'},
          };
        }
        return {
          'producerId': otherId,
          'paused': true,
          'closed': false,
          'resumed': false,
        };
      });
      final caps = RtpCapabilities();
      await expectLater(
        repo.consume(
          otherId,
          const GroupMediaSource(resourceId, 'friend', 'audio', false),
          caps,
        ),
        throwsFormatException,
      );
      await expectLater(
        repo.setProducerPaused(resourceId, true),
        throwsFormatException,
      );
      await expectLater(repo.closeProducer(resourceId), throwsFormatException);
      await expectLater(repo.resumeConsumer(resourceId), throwsFormatException);
    },
  );
}
