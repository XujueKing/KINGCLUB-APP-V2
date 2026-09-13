import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

const id = '00000000-0000-4000-8000-000000000001';
const request = '00000000-0000-4000-8000-000000000002';
Map<String, dynamic> snapshot() => {
  'callId': id,
  'caller': 'me',
  'callee': 'peer',
  'mediaKind': 'video',
  'phase': 'ringing',
  'version': 0,
  'deadlineMs': 1000,
  'endedAtMs': null,
  'endReason': null,
};
CallRepository repo(ChatApiCall call) =>
    CallRepository(MessagingRepository(account: 'me', call: call));
void main() {
  test('signal payload identity is immutable and pages enforce call and cursor order', () async {
    final raw = {
      'callId': id,
      'clientSignalId': request,
      'generation': 0,
      'kind': 'offer',
      'sdp': 'v=0',
    };
    final signal = CallSignal(raw);
    raw['sdp'] = 'changed';
    expect(signal.data['sdp'], 'v=0');
    final r = repo((api, params) async {
      if (api == 'K260913000646') {
        expect((params['signal'] as Map)['clientSignalId'], request);
        return {'sequence': 1, 'generation': 0, 'replay': false};
      }
      return {
        'items': [
          {'sequence': 1, 'signal': signal.data},
        ],
        'nextSequence': 1,
        'generation': 0,
        'hasMore': false,
      };
    });
    expect(await r.sendSignal(signal), 1);
    expect((await r.readSignals(callId: id)).nextSequence, 1);
    await expectLater(
      r.readSignals(callId: id, after: 1),
      throwsFormatException,
    );
    await expectLater(r.readSignals(callId: request), throwsFormatException);
  });

  test('network retry preserves call request identity and target', () async {
    final seen = <Map<String, dynamic>>[];
    final r = repo((api, params) async {
      expect(api, 'K260913000643');
      seen.add(params);
      if (seen.length == 1) throw const AuthFailure('NETWORK_ERROR', 'offline');
      return snapshot();
    });
    await expectLater(
      r.start(peer: 'peer', media: CallMedia.video, requestId: request),
      throwsA(isA<AuthFailure>()),
    );
    expect(
      (await r.start(
        peer: 'peer',
        media: CallMedia.video,
        requestId: request,
      )).id,
      id,
    );
    expect(seen[0], seen[1]);
  });
  test(
    'read accepts empty current call and rejects cross-account or wrong IDs',
    () async {
      expect(await repo((_, _) async => {'call': null}).read(), null);
      await expectLater(
        repo(
          (_, _) async => {
            'call': {...snapshot(), 'caller': 'other'},
          },
        ).read(),
        throwsFormatException,
      );
      await expectLater(
        repo(
          (_, _) async => {
            'call': {...snapshot(), 'callId': request},
          },
        ).read(callId: id),
        throwsFormatException,
      );
    },
  );
  test(
    'actions carry current version and reject regressing acknowledgements',
    () async {
      final current = CallSnapshot.parse({
        ...snapshot(),
        'phase': 'connecting',
        'version': 2,
      }, 'me');
      final r = repo((api, params) async {
        expect(api, 'K260913000644');
        expect(params['expectedVersion'], 2);
        expect(params['requestId'], request);
        return {
          ...snapshot(),
          'phase': 'ended',
          'version': 3,
          'endedAtMs': 900,
          'endReason': 'hangup',
        };
      });
      expect(
        (await r.act(
          call: current,
          action: CallAction.hangup,
          requestId: request,
        )).phase,
        CallPhase.ended,
      );
      await expectLater(
        repo((_, _) async => snapshot())
            .act(call: current, action: CallAction.hangup, requestId: request),
        throwsFormatException,
      );
    },
  );
  test('ended state needs a timestamp and supported reason', () {
    expect(
      () => CallSnapshot.parse({...snapshot(), 'phase': 'ended'}, 'me'),
      throwsFormatException,
    );
    expect(
      () => CallSnapshot.parse({...snapshot(), 'endedAtMs': 12}, 'me'),
      throwsFormatException,
    );
  });
}
