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
  int starts = 0, syncs = 0, closes = 0;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> sync() async {
    syncs++;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

void main() {
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
