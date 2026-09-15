import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

const id = '00000000-0000-4000-8000-000000000001';
const group = '00000000-0000-4000-8000-000000000002';
const request = '00000000-0000-4000-8000-000000000003';
Map<String, dynamic> snapshot() => {
  'callId': id,
  'groupId': group,
  'mediaKind': 'audio',
  'version': 0,
  'endedAtMs': null,
  'appliedVersion': 0,
  'replay': false,
  'participants': [
    {'account': 'me', 'phase': 'joined', 'deadlineMs': 1000},
    {'account': 'friend', 'phase': 'invited', 'deadlineMs': 1000},
  ],
};
GroupCallRepository repo(ChatApiCall call) =>
    GroupCallRepository(MessagingRepository(account: 'me', call: call));
void main() {
  for (final code in ['NETWORK_ERROR', 'CHAT_GROUP_CALL_VERSION_CONFLICT']) {
    test(
      'decline retry preserves identity except definite conflict: $code',
      () async {
        final sent = <Map<String, dynamic>>[];
        final repository = repo((api, params) async {
          expect(api, 'K260915000679');
          sent.add(params);
          throw AuthFailure(code, 'test');
        });
        GroupCallSnapshot invitation(int version) => GroupCallSnapshot.parse({
          ...snapshot(),
          'version': version,
          'participants': [
            {'account': 'me', 'phase': 'invited', 'deadlineMs': 1000},
            {'account': 'friend', 'phase': 'joined', 'deadlineMs': 1000},
          ],
        }, 'me');
        await expectLater(
          repository.declineInvitation(invitation(0)),
          throwsA(isA<AuthFailure>()),
        );
        await expectLater(
          repository.declineInvitation(invitation(2)),
          throwsA(isA<AuthFailure>()),
        );
        expect(sent[1]['action'], 'decline');
        if (code == 'NETWORK_ERROR') {
          expect(sent[1], sent[0]);
        } else {
          expect(sent[1]['requestId'], isNot(sent[0]['requestId']));
          expect(sent[1]['expectedVersion'], 2);
        }
      },
    );
  }

  test(
    'construction is passive and network retry keeps the supplied request',
    () async {
      final requests = <Map<String, dynamic>>[];
      final repository = repo((api, params) async {
        expect(api, 'K260915000678');
        requests.add(params);
        if (requests.length == 1) {
          throw const AuthFailure('NETWORK_ERROR', 'offline');
        }
        return snapshot();
      });
      expect(requests, isEmpty);
      Future<GroupCallResult> send() => repository.start(
        groupId: group,
        invitees: ['friend'],
        media: CallMedia.audio,
        requestId: request,
      );
      await expectLater(send(), throwsA(isA<AuthFailure>()));
      expect((await send()).call.id, id);
      expect(requests.first, requests.last);
    },
  );
  test('rejects cross-account, duplicate, unknown and inconsistent state', () {
    for (final patch in <Map<String, dynamic>>[
      {'groupId': 'bad'},
      {'mediaKind': 'unknown'},
      {'version': -1},
      {
        'participants': [
          {'account': 'friend', 'phase': 'joined', 'deadlineMs': 1},
          {'account': 'other', 'phase': 'invited', 'deadlineMs': 1},
        ],
      },
      {
        'participants': [
          {'account': 'me', 'phase': 'joined', 'deadlineMs': 1},
          {'account': 'me', 'phase': 'joined', 'deadlineMs': 1},
        ],
      },
      {
        'participants': [
          {'account': 'me', 'phase': 'unknown', 'deadlineMs': 1},
          {'account': 'friend', 'phase': 'joined', 'deadlineMs': 1},
        ],
      },
      {'endedAtMs': 1000},
    ]) {
      expect(
        () => GroupCallSnapshot.parse({...snapshot(), ...patch}, 'me'),
        throwsFormatException,
      );
    }
  });
  test(
    'read enforces requested ID and current requires an active participant',
    () async {
      expect(await repo((_, _) async => {'call': null}).current(), null);
      await expectLater(
        repo((_, _) async => {}).current(),
        throwsFormatException,
      );
      await expectLater(
        repo((_, _) async => snapshot()).read(group),
        throwsFormatException,
      );
      final current = await repo((api, params) async {
        expect(api, 'K260915000681');
        expect(params, isEmpty);
        return {'call': snapshot()};
      }).current();
      expect(current!.participants.length, 2);
      expect(() => current.participants.clear(), throwsUnsupportedError);
      final inactive = snapshot();
      (inactive['participants'] as List)[0] = {
        'account': 'me',
        'phase': 'left',
        'deadlineMs': 1,
      };
      (inactive['participants'] as List)[1] = {
        'account': 'friend',
        'phase': 'joined',
        'deadlineMs': 1,
      };
      await expectLater(
        repo((_, _) async => {'call': inactive}).current(),
        throwsFormatException,
      );
    },
  );
  test('start validates targets and acknowledgement membership', () async {
    final repository = repo((_, _) async => snapshot());
    await expectLater(
      repository.start(
        groupId: group,
        invitees: ['other'],
        media: CallMedia.audio,
        requestId: request,
      ),
      throwsFormatException,
    );
    await expectLater(
      repository.start(
        groupId: group,
        invitees: ['me'],
        media: CallMedia.audio,
        requestId: request,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.start(
        groupId: group,
        invitees: ['friend', 'friend'],
        media: CallMedia.audio,
        requestId: request,
      ),
      throwsArgumentError,
    );
  });
  test(
    'action preserves applied version when replay returns a later ended state',
    () async {
      final initial = GroupCallSnapshot.parse(snapshot(), 'me');
      final ended = {
        ...snapshot(),
        'version': 3,
        'appliedVersion': 1,
        'replay': true,
        'endedAtMs': 2000,
        'participants': [
          {'account': 'me', 'phase': 'left', 'deadlineMs': 1000},
          {'account': 'friend', 'phase': 'declined', 'deadlineMs': 1000},
        ],
      };
      final result = await repo((api, params) async {
        expect(api, 'K260915000679');
        expect(params['expectedVersion'], 0);
        expect(params['requestId'], request);
        expect(params['action'], 'leave');
        return ended;
      }).act(call: initial, action: GroupCallAction.leave, requestId: request);
      expect(result.call.version, 3);
      expect(result.appliedVersion, 1);
      expect(result.replay, true);
      await expectLater(
        repo(
          (_, _) async => {...ended, 'appliedVersion': 2},
        ).act(call: initial, action: GroupCallAction.leave, requestId: request),
        throwsFormatException,
      );
      await expectLater(
        repo(
          (_, _) async => {...ended, 'groupId': request},
        ).act(call: initial, action: GroupCallAction.leave, requestId: request),
        throwsFormatException,
      );
    },
  );
}
