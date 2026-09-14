import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/call_state_controller.dart';
import 'package:kingclub/src/features/messaging/data/call_media_session.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/native_call_media.dart';

const id = '00000000-0000-4000-8000-000000000001';
Map<String, dynamic> state(String phase, int version) => {
  'callId': id,
  'caller': 'a',
  'callee': 'b',
  'mediaKind': 'audio',
  'phase': phase,
  'version': version,
  'deadlineMs': 9999999999999,
  if (phase == 'ended') ...{'endedAtMs': 9999999999998, 'endReason': 'hangup'},
};

class Session extends CallMediaSession {
  Session(CallRepository repository, CallSnapshot call)
    : super(
        repository: repository,
        call: call,
        mediaFactory: (_) => NativeCallMedia(
          video: false,
          iceServers: [],
          capture: (_) async => throw StateError('unused'),
        ),
      );
  int starts = 0, syncs = 0, closes = 0, restarts = 0;
  final renewals = <bool>[];
  bool restartable = false;
  int? expiry;
  @override
  bool get canRestart => restartable;
  @override
  int? get relayExpiresAtMs => expiry;
  @override
  Future<void> restart() async {
    restarts++;
    expiry = null;
  }

  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> sync({bool renewLease = true}) async {
    syncs++;
    renewals.add(renewLease);
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

class RecoveryTimer implements Timer {
  RecoveryTimer(this.callback);
  final void Function() callback;
  @override
  bool isActive = true;
  @override
  int tick = 0;
  @override
  void cancel() => isActive = false;
  void fire() {
    if (!isActive) return;
    isActive = false;
    tick++;
    callback();
  }
}

class DurationClock extends Stopwatch {
  int starts = 0;
  bool running = false;
  Duration value = Duration.zero;
  @override
  Duration get elapsed => value;
  @override
  void start() {
    starts++;
    running = true;
  }

  @override
  void stop() {
    running = false;
  }
}

void main() {
  test(
    'recovery timeout stops local capture while state HTTP is stuck',
    () async {
      final timers = <RecoveryTimer>[];
      final durationClock = DurationClock();
      final timerZone = ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          expect(duration, const Duration(seconds: 45));
          final timer = RecoveryTimer(callback);
          timers.add(timer);
          return timer;
        },
      );
      final changes = StreamController<void>.broadcast();
      final stalled = Completer<Map<String, dynamic>>();
      var server = state('ringing', 0), blockReads = false;
      final repository = CallRepository(
        MessagingRepository(
          account: 'a',
          call: (method, _) async {
            if (method == 'K260913000645') {
              return blockReads ? stalled.future : {'call': server};
            }
            return server = state('active', 3);
          },
        ),
      );
      late Session session;
      late void Function(RTCPeerConnectionState) connection;
      final controller = CallStateController(
        durationClock: durationClock,
        repository: repository,
        initial: CallSnapshot.parse(server, 'a'),
        sessionChanges: changes.stream,
        sessionFactory: (call, callback) {
          connection = callback;
          return session = Session(repository, call);
        },
      );
      expect(controller.connectedDuration, isNull);
      expect(durationClock.starts, 0);
      server = state('connecting', 1);
      await controller.refresh();
      connection(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      await controller.refresh();
      runZoned(
        () => connection(
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
        ),
        zoneSpecification: timerZone,
      );
      connection(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      await controller.refresh();
      expect(durationClock.starts, 1);
      expect(durationClock.running, true);
      durationClock.value = const Duration(seconds: 65);
      expect(controller.connectedDuration, const Duration(seconds: 65));
      expect(timers.single.isActive, false);
      timers.single.fire();
      expect(controller.isEnding, false); // Recovery canceled the old timer.
      blockReads = true;
      final pending = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      runZoned(
        () => connection(RTCPeerConnectionState.RTCPeerConnectionStateFailed),
        zoneSpecification: timerZone,
      );
      expect(session.closes, 0);
      expect(timers, hasLength(2));
      timers.last.fire();
      expect(controller.isEnding, true);
      expect(durationClock.running, false);
      expect(controller.connectedDuration, const Duration(seconds: 65));
      expect(session.closes, 1); // HTTP still has not returned.
      stalled.complete({'call': state('ended', 4)});
      await pending;
      expect(controller.isClosed, true);
      controller.dispose();
      await changes.close();
    },
  );

  for (final account in ['a', 'b']) {
    test(
      '$account renews relay and recovers ICE only when it owns offers',
      () async {
        var now = 1000000;
        var server = state('ringing', 0);
        final changes = StreamController<void>.broadcast();
        final repository = CallRepository(
          MessagingRepository(
            account: account,
            call: (method, params) async {
              if (method == 'K260913000645') return {'call': server};
              if (params['action'] == 'accept') {
                return server = state('connecting', 1);
              }
              if (params['action'] == 'connected') {
                return server = state('active', 3);
              }
              return server = state('ended', 4);
            },
          ),
        );
        late Session session;
        late void Function(RTCPeerConnectionState) connection;
        final controller = CallStateController(
          repository: repository,
          initial: CallSnapshot.parse(server, account),
          sessionChanges: changes.stream,
          nowMs: () => now,
          sessionFactory: (call, callback) {
            connection = callback;
            return session = Session(repository, call)..restartable = true;
          },
        );
        if (account == 'b') {
          await controller.accept();
        } else {
          server = state('connecting', 1);
          await controller.refresh();
        }
        connection(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
        await controller.refresh();
        session.expiry = now + 59000;
        await controller.refresh();
        final expected = account == 'a' ? 1 : 0;
        expect(session.restarts, expected);
        expect(session.renewals.last, true);
        now += 11000;
        session.expiry = null;
        connection(RTCPeerConnectionState.RTCPeerConnectionStateDisconnected);
        await controller.refresh();
        expect(session.restarts, expected);
        now += 1999;
        await controller.refresh();
        expect(session.restarts, expected);
        now++;
        await controller.refresh();
        expect(session.restarts, expected * 2);
        expect(session.renewals.last, false);
        // A burst of polls cannot create further offers during the cooldown.
        await controller.refresh();
        await controller.refresh();
        expect(session.restarts, expected * 2);
        // Failed in an active call still allows recovery before server expiry.
        connection(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
        expect(controller.isEnding, false);
        now += 10000;
        await controller.refresh();
        expect(session.restarts, expected * 3);
        connection(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
        await controller.refresh();
        expect(session.renewals.last, true);
        now += 10000;
        server = {...state('active', 3), 'deadlineMs': now + 20000};
        await controller.refresh();
        expect(session.restarts, expected * 4);
        server = state('ended', 4);
        await controller.refresh();
        expect(controller.isClosed, true);
        expect(session.restarts, expected * 4);
        controller.dispose();
        await changes.close();
      },
    );
  }

  test('active disconnect pauses lease renewal while state polling and recovery remain live', () async {
    final changes = StreamController<void>.broadcast();
    var server = state('ringing', 0), reads = 0;
    final repository = CallRepository(
      MessagingRepository(
        account: 'a',
        call: (method, params) async {
          if (method == 'K260913000645') {
            reads++;
            return {'call': server};
          }
          expect(params['action'], 'connected');
          return server = state('active', 3);
        },
      ),
    );
    late void Function(RTCPeerConnectionState) connection;
    late Session session;
    final controller = CallStateController(
      repository: repository,
      initial: CallSnapshot.parse(server, 'a'),
      sessionChanges: changes.stream,
      sessionFactory: (call, callback) {
        connection = callback;
        return session = Session(repository, call);
      },
    );
    server = state('connecting', 1);
    await controller.refresh();
    expect(session.syncs, 1); // Negotiation must work before connected.
    connection(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    await controller.refresh();
    final beforeDisconnect = session.syncs;
    expect(controller.call.phase, CallPhase.active);
    connection(RTCPeerConnectionState.RTCPeerConnectionStateDisconnected);
    final beforeReads = reads;
    await controller.refresh();
    await controller.refresh();
    expect(reads, beforeReads + 2);
    expect(session.syncs, beforeDisconnect + 2);
    expect(session.renewals.skip(beforeDisconnect), [false, false]);
    expect(controller.isClosed, false);
    connection(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    await controller.refresh();
    expect(session.syncs, beforeDisconnect + 3);
    expect(session.renewals.last, true);
    connection(RTCPeerConnectionState.RTCPeerConnectionStateDisconnected);
    server = state('ended', 4);
    await controller.refresh();
    expect(controller.isClosed, true);
    expect(session.closes, 1);
    controller.dispose();
    await changes.close();
  });

  test(
    'expired relay factory failure ends the attempt without retrying capture',
    () async {
      final changes = StreamController<void>.broadcast();
      var server = state('ringing', 0), opens = 0;
      final repository = CallRepository(
        MessagingRepository(
          account: 'a',
          call: (method, params) async {
            if (method == 'K260913000645') return {'call': server};
            expect(params['action'], 'hangup');
            return state('ended', 2);
          },
        ),
      );
      final controller = CallStateController(
        repository: repository,
        initial: CallSnapshot.parse(server, 'a'),
        sessionChanges: changes.stream,
        sessionFactory: (_, _) {
          opens++;
          throw StateError('Expired relay');
        },
      );
      server = state('connecting', 1);
      await expectLater(controller.refresh(), throwsStateError);
      expect(controller.isEnding, true);
      await controller.refresh();
      expect(controller.isClosed, true);
      expect(opens, 1);
      controller.dispose();
      await changes.close();
    },
  );

  test(
    'incoming refresh never captures; accept retry uses its original identity',
    () async {
      var server = state('ringing', 0);
      final changes = StreamController<void>.broadcast();
      final actions = <Map<String, dynamic>>[];
      var lost = true;
      final repository = CallRepository(
        MessagingRepository(
          account: 'b',
          call: (method, params) async {
            if (method == 'K260913000645') return {'call': server};
            actions.add(Map.from(params));
            server = state('connecting', 1);
            if (lost) {
              lost = false;
              throw const AuthFailure('NETWORK_ERROR', 'lost');
            }
            return server;
          },
        ),
      );
      final sessions = <Session>[];
      final controller = CallStateController(
        repository: repository,
        initial: CallSnapshot.parse(server, 'b'),
        sessionChanges: changes.stream,
        sessionFactory: (call, _) {
          final s = Session(repository, call);
          sessions.add(s);
          return s;
        },
      );
      await controller.refresh();
      expect(sessions, isEmpty);
      await expectLater(controller.accept(), throwsA(isA<AuthFailure>()));
      await controller.refresh();
      expect(sessions, isEmpty);
      await controller.accept();
      expect(actions[0]['requestId'], actions[1]['requestId']);
      expect(actions[0]['expectedVersion'], actions[1]['expectedVersion']);
      expect(sessions.single.starts, 1);
      changes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(sessions.single.closes, 1);
      controller.dispose();
      await changes.close();
    },
  );
  test('caller only captures after accept; hangup releases media before HTTP completes', () async {
    var server = state('ringing', 0);
    final changes = StreamController<void>.broadcast();
    Completer<Map<String, dynamic>>? pendingRead;
    final repository = CallRepository(
      MessagingRepository(
        account: 'a',
        call: (method, params) async {
          if (method == 'K260913000645') {
            return pendingRead?.future ?? {'call': server};
          }
          expect(params['action'], 'hangup');
          server = state('ended', 2);
          return server;
        },
      ),
    );
    final sessions = <Session>[];
    final controller = CallStateController(
      repository: repository,
      initial: CallSnapshot.parse(server, 'a'),
      sessionChanges: changes.stream,
      sessionFactory: (call, _) {
        final s = Session(repository, call);
        sessions.add(s);
        return s;
      },
    );
    await controller.refresh();
    expect(sessions, isEmpty);
    server = state('connecting', 1);
    await controller.refresh();
    expect(sessions.single.starts, 1);
    pendingRead = Completer<Map<String, dynamic>>();
    final ending = controller.end();
    expect(sessions.single.closes, 1);
    pendingRead.complete({'call': server});
    await ending;
    expect(controller.call.phase, CallPhase.ended);
    controller.dispose();
    await changes.close();
  });
  test('late refresh after logout cannot start capture', () async {
    final changes = StreamController<void>.broadcast();
    final read = Completer<Map<String, dynamic>>();
    final repository = CallRepository(
      MessagingRepository(account: 'a', call: (_, _) => read.future),
    );
    var opens = 0;
    final controller = CallStateController(
      repository: repository,
      initial: CallSnapshot.parse(state('ringing', 0), 'a'),
      sessionChanges: changes.stream,
      sessionFactory: (call, _) {
        opens++;
        return Session(repository, call);
      },
    );
    final refreshing = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    read.complete({'call': state('connecting', 1)});
    await refreshing;
    expect(opens, 0);
    controller.dispose();
    await changes.close();
  });
}
