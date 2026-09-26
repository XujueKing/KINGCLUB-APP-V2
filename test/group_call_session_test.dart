import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/group_call_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_call_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_call_session.dart';
import 'package:kingclub/src/features/messaging/data/native_group_call_media.dart';

import 'native_group_call_media_test.dart' as fixtures;

class Calls extends GroupCallRepository {
  Calls() : super(fixtures.Repo().messaging);
  final actions = <GroupCallAction>[];
  Completer<void>? joining;
  @override
  Future<GroupCallSnapshot> read(String id) async => fixtures.Repo().call;
  @override
  Future<GroupCallResult> act({
    required GroupCallSnapshot call,
    required GroupCallAction action,
    required String requestId,
  }) async {
    actions.add(action);
    if (action == GroupCallAction.join) await joining?.future;
    return GroupCallResult(fixtures.Repo().call, 1, false);
  }
}

class FailingCleanupMedia extends NativeGroupCallMedia {
  FailingCleanupMedia()
    : super(
        repository: fixtures.Repo(),
        device: fixtures.DeviceFixture(),
        capture: (_) async => fixtures.StreamFixture(),
      );
  @override
  Future<void> open() async {}
  @override
  Future<void> close() async => throw StateError('native cleanup failed');
}

class FailingOpenMedia extends FailingCleanupMedia {
  int closes = 0;
  @override
  Future<void> open() async => throw TimeoutException('publish timeout');
  @override
  Future<void> close() async {
    closes++;
  }
}

void main() {
  test(
    'failed media opening releases the server seat without deadlock',
    () async {
      final calls = Calls();
      final controller = GroupCallController(
        repository: calls,
        initial: fixtures.Repo().call,
        sessionChanges: const Stream.empty(),
        invalidations: const Stream.empty(),
      );
      final media = FailingOpenMedia();
      final session = GroupCallSession(
        controller: controller,
        createMedia: (_, _, _) => media,
      );
      await expectLater(session.enter(), throwsA(isA<TimeoutException>()));
      await session.hangUp().timeout(const Duration(seconds: 1));
      expect(calls.actions, [GroupCallAction.leave]);
      expect(media.closes, greaterThan(0));
      expect(session.isClosed, true);
      expect(controller.isClosed, true);
      controller.dispose();
    },
  );

  test(
    'running media failure leaves once even when native cleanup fails',
    () async {
      final calls = Calls();
      final controller = GroupCallController(
        repository: calls,
        initial: fixtures.Repo().call,
        sessionChanges: const Stream.empty(),
        invalidations: const Stream.empty(),
      );
      late void Function(Object) fail;
      final failures = <Object>[];
      final session = GroupCallSession(
        controller: controller,
        onError: failures.add,
        createMedia: (_, _, error) {
          fail = error;
          return FailingCleanupMedia();
        },
      );
      await session.enter();
      fail(StateError('transport failed'));
      fail(StateError('duplicate failure'));
      await expectLater(session.hangUp(), throwsStateError);
      expect(calls.actions, [GroupCallAction.leave]);
      expect(controller.isClosed, true);
      expect(failures, hasLength(2));
      controller.dispose();
    },
  );

  test(
    'cleanup failure still leaves the server seat and closes controller',
    () async {
      final calls = Calls();
      final controller = GroupCallController(
        repository: calls,
        initial: fixtures.Repo().call,
        sessionChanges: const Stream.empty(),
        invalidations: const Stream.empty(),
      );
      final session = GroupCallSession(
        controller: controller,
        createMedia: (_, _, _) => FailingCleanupMedia(),
      );
      await session.enter();
      await expectLater(session.hangUp(), throwsStateError);
      expect(calls.actions, [GroupCallAction.leave]);
      expect(controller.isClosed, true);
      expect(session.isClosed, true);
      controller.dispose();
    },
  );
  test(
    'passive owner only renews while native send transport is connected',
    () async {
      final calls = Calls(), changes = StreamController<void>();
      final controller = GroupCallController(
        repository: calls,
        initial: fixtures.Repo().call,
        sessionChanges: changes.stream,
        invalidations: const Stream.empty(),
      );
      final stream = fixtures.StreamFixture();
      void Function(String, String)? connection;
      final session = GroupCallSession(
        controller: controller,
        heartbeatInterval: const Duration(milliseconds: 10),
        createMedia: (repository, state, error) {
          connection = state;
          return NativeGroupCallMedia(
            repository: fixtures.Repo(),
            device: fixtures.DeviceFixture(),
            capture: (_) async => stream,
          );
        },
      );
      expect(connection, null);
      await session.enter();
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(calls.actions, isEmpty);
      connection!('send', 'connected');
      expect(session.connectedDuration, null);
      expect(session.isConnected, false);
      connection!('receive', 'connected');
      expect(session.isConnected, true);
      expect(session.connectedDuration, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(calls.actions, contains(GroupCallAction.heartbeat));
      connection!('send', 'disconnected');
      expect(session.isConnected, false);
      final count = calls.actions.length;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(calls.actions.length, count);
      changes.add(null);
      await Future<void>.delayed(Duration.zero);
      await session.close();
      final elapsed = session.connectedDuration;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      connection!('send', 'connected');
      expect(session.connectedDuration, elapsed);
      expect(session.isConnected, false);
      expect(session.isClosed, true);
      expect(stream.track.stops, 1);
      controller.dispose();
      await changes.close();
    },
  );

  test(
    'hangup during an outstanding join cannot begin capture later',
    () async {
      final initial = GroupCallSnapshot.parse({
        'callId': fixtures.callId,
        'groupId': fixtures.callId,
        'mediaKind': 'audio',
        'version': 1,
        'endedAtMs': null,
        'participants': [
          {'account': 'me', 'phase': 'invited', 'deadlineMs': 1000},
          {'account': 'friend', 'phase': 'joined', 'deadlineMs': 1000},
        ],
      }, 'me');
      final calls = Calls()..joining = Completer<void>();
      final controller = GroupCallController(
        repository: calls,
        initial: initial,
        sessionChanges: const Stream.empty(),
        invalidations: const Stream.empty(),
      );
      var created = false;
      final session = GroupCallSession(
        controller: controller,
        createMedia: (_, _, _) {
          created = true;
          throw StateError('Unexpected capture');
        },
      );
      final opening = session.enter();
      final assertion = expectLater(opening, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      final hanging = session.hangUp();
      final duplicate = session.hangUp();
      expect(identical(hanging, duplicate), true);
      calls.joining!.complete();
      await assertion;
      await hanging;
      await duplicate;
      expect(calls.actions, [GroupCallAction.join, GroupCallAction.leave]);
      expect(created, false);
      expect(session.isClosed, true);
      controller.dispose();
    },
  );
}
