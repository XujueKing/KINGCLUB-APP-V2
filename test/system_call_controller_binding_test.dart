import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kingclub/src/features/messaging/data/call_media_session.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/call_state_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/native_call_media.dart';
import 'package:kingclub/src/features/messaging/data/native_system_calls.dart';
import 'package:kingclub/src/features/messaging/data/system_call_controller_binding.dart';

const callId = '00000000-0000-4000-8000-000000000001';
SystemCallEvent event(String kind, {String account = 'b'}) =>
    SystemCallEvent.parse({
      'eventId': kind == 'end'
          ? '00000000-0000-4000-8000-000000000003'
          : '00000000-0000-4000-8000-000000000002',
      'callId': callId,
      'kind': kind,
      'account': account,
      'scope': 'direct',
      if (kind == 'answer' || kind == 'end')
        'actionId': '00000000-0000-4000-8000-000000000004',
    });

class Native extends NativeSystemCalls {
  final completions = <(String, bool)>[];
  int ended = 0;
  @override
  Future<bool> acknowledge(SystemCallEvent event) async => true;
  @override
  Future<bool> completeAction(
    SystemCallEvent event, {
    required bool success,
  }) async {
    completions.add((event.kind.name, success));
    return true;
  }

  @override
  Future<void> end(String callId, {bool failed = false}) async {
    ended++;
  }
}

class Media extends CallMediaSession {
  Media(CallRepository repository, CallSnapshot call)
    : super(
        repository: repository,
        call: call,
        mediaFactory: (_) => NativeCallMedia(
          video: false,
          iceServers: [],
          capture: (_) async => throw StateError('unused test capture'),
        ),
      );
  int starts = 0, stops = 0;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> sync({bool renewLease = true}) async {}
  @override
  Future<void> close() async {
    stops++;
  }
}

class Fixture {
  Fixture() {
    repository = CallRepository(
      MessagingRepository(
        account: 'b',
        call: (method, params) async {
          if (method == 'K260913000645') return {'call': state};
          final action = params['action'];
          actions.add(action as String);
          phase = action == 'accept'
              ? 'connecting'
              : action == 'connected'
              ? 'active'
              : 'ended';
          version++;
          return state;
        },
      ),
    );
    controller = CallStateController(
      repository: repository,
      initial: CallSnapshot.parse(state, 'b'),
      sessionChanges: changes.stream,
      sessionFactory: (call, callback) {
        connected = callback;
        return media = Media(repository, call);
      },
    );
    binding = SystemCallControllerBinding(
      controller: controller,
      native: native,
      connectionTimeout: const Duration(milliseconds: 100),
    );
  }
  String phase = 'ringing';
  int version = 0;
  Map<String, dynamic> get state => {
    'callId': callId,
    'caller': 'a',
    'callee': 'b',
    'mediaKind': 'audio',
    'phase': phase,
    'version': version,
    'deadlineMs': 9999999999999,
    if (phase == 'ended') ...{
      'endedAtMs': 9999999999998,
      'endReason': 'hangup',
    },
  };
  final actions = <String>[];
  final changes = StreamController<void>.broadcast(sync: true);
  final native = Native();
  late final CallRepository repository;
  late final CallStateController controller;
  late final SystemCallControllerBinding binding;
  Media? media;
  void Function(RTCPeerConnectionState)? connected;
  Future<void> close() async {
    binding.close();
    await controller.close();
    controller.dispose();
    await changes.close();
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  test('does not open media for incoming event or another account', () async {
    final f = Fixture();
    addTearDown(f.close);
    await f.binding.handle(event('incoming'));
    await f.binding.handle(event('answer', account: 'other'));
    expect(f.media, isNull);
    expect(f.actions, isEmpty);
  });
  test(
    'deduplicates answer and waits for media connection before fulfilling',
    () async {
      final f = Fixture();
      addTearDown(f.close);
      final first = f.binding.handle(event('answer'));
      final duplicate = f.binding.handle(event('answer'));
      await tick();
      expect(f.media?.starts, 1);
      expect(f.native.completions, isEmpty);
      f.connected!(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      await Future.wait([first, duplicate]);
      expect(f.actions.where((a) => a == 'accept').length, 1);
      expect(f.native.completions, [('answer', true)]);
    },
  );
  test('decline does not request microphone', () async {
    final f = Fixture();
    addTearDown(f.close);
    await f.binding.handle(event('end'));
    expect(f.media, isNull);
    expect(f.actions, ['decline']);
    expect(f.native.completions, [('end', true)]);
  });
  test(
    'end interrupts an answer waiting for ICE and never fulfills answer',
    () async {
      final f = Fixture();
      addTearDown(f.close);
      final answering = f.binding.handle(event('answer'));
      await tick();
      await f.binding.handle(event('end'));
      await answering;
      expect(f.media!.stops, greaterThan(0));
      expect(f.native.completions, contains(('answer', false)));
      expect(f.native.completions, isNot(contains(('answer', true))));
    },
  );
  test(
    'media connection timeout fails system answer and releases capture',
    () async {
      final f = Fixture();
      addTearDown(f.close);
      await f.binding.handle(event('answer'));
      await tick();
      expect(f.native.completions, [('answer', false)]);
      expect(f.media!.stops, greaterThan(0));
    },
  );
  test('remote ending closes the system call', () async {
    final f = Fixture();
    addTearDown(f.close);
    f.phase = 'ended';
    f.version++;
    await f.controller.refresh();
    await tick();
    expect(f.native.ended, 1);
  });
}
