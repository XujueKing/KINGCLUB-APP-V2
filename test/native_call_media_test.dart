import 'package:flutter/services.dart';
import 'package:kingclub/src/features/messaging/data/call_relay_configuration.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kingclub/src/features/messaging/data/native_call_media.dart';
import 'package:kingclub/src/features/messaging/data/call_foreground_lease.dart';

class Track implements MediaStreamTrack {
  int stops = 0;
  @override
  String get id => 'local-audio';
  @override
  bool enabled = true;
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StreamFixture implements MediaStream {
  final track = Track();
  int disposed = 0;
  @override
  List<MediaStreamTrack> getTracks() => [track];
  @override
  List<MediaStreamTrack> getAudioTracks() => [track];
  @override
  List<MediaStreamTrack> getVideoTracks() => [track];
  @override
  Future<void> dispose() async {
    disposed++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class VideoStreamFixture extends StreamFixture {
  final camera = Track();
  @override
  List<MediaStreamTrack> getTracks() => [track, camera];
  @override
  List<MediaStreamTrack> getVideoTracks() => [camera];
}

class InvalidatedStream extends StreamFixture {
  bool invalidated = false;
  @override
  List<MediaStreamTrack> getTracks() {
    if (invalidated) throw StateError('native stream invalidated');
    return super.getTracks();
  }
}

class Peer implements RTCPeerConnection {
  int closes = 0, disposes = 0, candidates = 0;
  @override
  Future<RTCRtpSender> addTrack(
    MediaStreamTrack track, [
    MediaStream? stream,
  ]) async => Sender();
  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async {
    candidates++;
  }

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {}
  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<void> dispose() async {
    disposes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isSetter) return null;
    return super.noSuchMethod(invocation);
  }
}

class FailingTrackPeer extends Peer {
  void Function(RTCIceCandidate)? _candidate;
  @override
  void Function(RTCIceCandidate)? get onIceCandidate => _candidate;
  @override
  set onIceCandidate(void Function(RTCIceCandidate)? value) =>
      _candidate = value;
  @override
  Future<RTCRtpSender> addTrack(
    MediaStreamTrack track, [
    MediaStream? stream,
  ]) async {
    throw StateError('synthetic track failure');
  }
}

class CallbackTrack extends Track {
  CallbackTrack(this.onStop);
  final void Function() onStop;
  @override
  Future<void> stop() async {
    onStop();
    await super.stop();
  }
}

class CallbackStream extends StreamFixture {
  CallbackStream(this.stoppingTrack);
  final Track stoppingTrack;
  @override
  List<MediaStreamTrack> getTracks() => [stoppingTrack];
}

class Sender implements RTCRtpSender {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const restartCallId = '00000000-0000-4000-8000-000000000001';
CallRelayConfiguration freshRelay() {
  final expiry = (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600) * 1000;
  return CallRelayConfiguration.parse(restartCallId, {
    'expiresAtMs': expiry,
    'iceServers': [
      {
        'urls': ['turn:relay.example'],
        'username': '${expiry ~/ 1000}:0123456789abcdef0123456789abcdef',
        'credential': 'AAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      },
    ],
  });
}

class RestartPeer extends Peer {
  final operations = <String>[];
  Map<String, dynamic>? updated;
  bool fail = false;
  @override
  Map<String, dynamic> get getConfiguration => {'sdpSemantics': 'unified-plan'};
  @override
  Future<void> setConfiguration(Map<String, dynamic> value) async {
    operations.add('configuration');
    updated = value;
    if (fail) throw StateError('partial native failure');
  }

  @override
  Future<RTCSessionDescription> createOffer([
    Map<String, dynamic>? constraints,
  ]) async {
    expect(constraints?['iceRestart'], true);
    operations.add('offer');
    return RTCSessionDescription('v=0\r\n', 'offer');
  }

  @override
  Future<void> setLocalDescription(RTCSessionDescription value) async {
    operations.add('local');
  }
}

void main() {
  test(
    'hangup cancels pending foreground startup before waiting for open',
    () async {
      final starting = Completer<void>(), pending = Completer<void>();
      final stream = StreamFixture();
      var peers = 0;
      final native = NativeCallMedia(
        video: false,
        iceServers: [],
        capture: (_) async => stream,
        foregroundLease: CallForegroundLease(
          supported: true,
          invoke: (method, _) async {
            if (method == 'start') {
              starting.complete();
              await pending.future;
            } else if (!pending.isCompleted) {
              pending.completeError(StateError('cancelled'));
            }
          },
        ),
        peerFactory: (_) async {
          peers++;
          return Peer();
        },
      );
      final opening = native.open();
      final rejected = expectLater(opening, throwsStateError);
      await starting.future;
      await native.close().timeout(const Duration(seconds: 1));
      await rejected;
      expect(peers, 0);
      expect(stream.track.stops, 1);
      expect(stream.disposed, 1);
    },
  );
  test(
    'foreground service rejection releases capture before any peer is created',
    () async {
      final stream = StreamFixture();
      var peers = 0;
      final native = NativeCallMedia(
        video: false,
        iceServers: [],
        capture: (_) async => stream,
        foregroundLease: CallForegroundLease(
          supported: true,
          invoke: (method, _) async {
            if (method == 'start') {
              throw StateError('foreground permission denied');
            }
          },
        ),
        peerFactory: (_) async {
          peers++;
          return Peer();
        },
      );
      await expectLater(native.open(), throwsStateError);
      expect(peers, 0);
      expect(stream.track.stops, 1);
      expect(stream.disposed, 1);
      await native.close();
      expect(stream.track.stops, 1);
    },
  );
  test(
    'invalidated stream still releases connection and speaker route',
    () async {
      final stream = InvalidatedStream(), peer = Peer();
      final routes = <bool>[];
      final media = NativeCallMedia(
        video: false,
        iceServers: [],
        capture: (_) async => stream,
        peerFactory: (_) async => peer,
        setSpeakerphone: (enabled) async {
          routes.add(enabled);
        },
      );
      await media.open();
      await media.setSpeakerphone(true);
      stream.invalidated = true;
      await expectLater(media.close(), throwsStateError);
      expect(stream.disposed, 1);
      expect(peer.closes, 1);
      expect(peer.disposes, 1);
      expect(routes.last, false);
    },
  );
  test(
    'failed opening suppresses late native events while releasing tracks',
    () async {
      final peer = FailingTrackPeer();
      final track = CallbackTrack(
        () => peer.onIceCandidate?.call(RTCIceCandidate('late', '0', 0)),
      );
      final stream = CallbackStream(track);
      var candidates = 0;
      final media = NativeCallMedia(
        video: false,
        iceServers: [],
        capture: (_) async => stream,
        peerFactory: (_) async => peer,
        onCandidate: (_) => candidates++,
      );
      await expectLater(media.open(), throwsStateError);
      expect(candidates, 0);
      expect(track.stops, 1);
      expect(stream.disposed, 1);
      expect(peer.closes, 1);
      expect(peer.disposes, 1);
      await media.close();
      expect(track.stops, 1);
    },
  );

  test('pause video preserves microphone and capture, handles failure and late completion', () async {
    final stream = VideoStreamFixture();
    var captures = 0;
    var response = Completer<void>();
    final media = NativeCallMedia(
      video: true,
      iceServers: [],
      capture: (_) async {
        captures++;
        return stream;
      },
      peerFactory: (_) async => Peer(),
      setVideoEnabled: (enabled, track) async {
        expect(identical(track, stream.camera), true);
        await response.future;
        track.enabled = enabled;
      },
    );
    await media.open();
    final pausing = media.setVideoEnabled(false);
    expect(media.videoEnabled, true);
    await expectLater(media.setVideoEnabled(true), throwsStateError);
    response.complete();
    await pausing;
    expect(media.videoEnabled, false);
    expect(stream.track.enabled, true);
    expect(stream.track.stops, 0);
    expect(captures, 1);
    response = Completer<void>();
    final failed = expectLater(media.setVideoEnabled(true), throwsStateError);
    response.completeError(StateError('native failure'));
    await failed;
    expect(media.videoEnabled, false);
    response = Completer<void>();
    final restored = media.setVideoEnabled(true);
    response.complete();
    await restored;
    expect(media.videoEnabled, true);
    response = Completer<void>();
    final late = expectLater(media.setVideoEnabled(false), throwsStateError);
    await media.close();
    expect(stream.track.stops, 1);
    expect(stream.camera.stops, 1);
    response.complete();
    await late;
  });
  test('audio call cannot toggle video', () async {
    final media = NativeCallMedia(
      video: false,
      iceServers: [],
      capture: (_) async => StreamFixture(),
      peerFactory: (_) async => Peer(),
    );
    await media.open();
    await expectLater(media.setVideoEnabled(false), throwsStateError);
    await media.close();
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native mute targets local track without system microphone override',
    () async {
      const channel = MethodChannel('FlutterWebRTC.Method');
      final previous = WebRTC.initialized;
      WebRTC.initialized = true;
      final commands = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            commands.add(call);
            return null;
          });
      addTearDown(() {
        WebRTC.initialized = previous;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final media = NativeCallMedia(
        video: false,
        iceServers: [],
        capture: (_) async => StreamFixture(),
        peerFactory: (_) async => Peer(),
      );
      await media.open();
      await media.mute(true);
      await media.mute(false);
      expect(commands.map((c) => c.method), [
        'mediaStreamTrackSetEnable',
        'mediaStreamTrackSetEnable',
      ]);
      expect(commands.map((c) => c.arguments['enabled']), [false, true]);
      expect(
        commands.every(
          (c) =>
              c.arguments['trackId'] == 'local-audio' &&
              c.arguments['peerConnectionId'] == '',
        ),
        true,
      );
      await media.close();
    },
  );

  test('mute waits for native acknowledgement, rejects overlap, and propagates failure', () async {
    final stream = StreamFixture();
    var pending = Completer<void>();
    final media = NativeCallMedia(
      video: false,
      iceServers: [],
      capture: (_) async => stream,
      peerFactory: (_) async => Peer(),
      setMicrophoneMute: (_, _) => pending.future,
    );
    await media.open();
    var confirmed = false;
    final muting = media.mute(true).then((_) => confirmed = true);
    expect(confirmed, false);
    await expectLater(media.mute(false), throwsStateError);
    final failed = expectLater(muting, throwsStateError);
    pending.completeError(StateError('native denied'));
    await failed;
    expect(confirmed, false);
    pending = Completer<void>();
    final retry = media.mute(true);
    pending.complete();
    await retry;
    pending = Completer<void>();
    final late = expectLater(media.mute(false), throwsStateError);
    await media.close();
    expect(stream.track.stops, 1);
    pending.complete();
    await late;
  });

  test(
    'remote restart keeps capture and queues ICE until the new remote SDP',
    () async {
      final stream = StreamFixture(), peer = RestartPeer();
      var captures = 0;
      final media = NativeCallMedia(
        video: true,
        iceServers: [],
        capture: (_) async {
          captures++;
          return stream;
        },
        peerFactory: (_) async => peer,
      );
      await media.open();
      await media.remoteDescription(RTCSessionDescription('v=0\r\n', 'offer'));
      await media.prepareRemoteRestart(
        callId: restartCallId,
        relay: freshRelay(),
      );
      await media.remoteCandidate(RTCIceCandidate('candidate:new', '0', 0));
      expect(peer.candidates, 0);
      expect(peer.operations, ['configuration']);
      expect(captures, 1);
      expect(stream.track.stops, 0);
      await media.remoteDescription(RTCSessionDescription('v=0\r\n', 'offer'));
      expect(peer.candidates, 1);
      peer.fail = true;
      await expectLater(
        media.prepareRemoteRestart(callId: restartCallId, relay: freshRelay()),
        throwsStateError,
      );
      expect(stream.track.stops, 1);
      expect(peer.closes, 1);
    },
  );

  test(
    'ICE restart replaces credentials before SDP without recapturing tracks',
    () async {
      final stream = StreamFixture(), peer = RestartPeer();
      var captures = 0;
      final media = NativeCallMedia(
        video: true,
        iceServers: [],
        capture: (_) async {
          captures++;
          return stream;
        },
        peerFactory: (_) async => peer,
      );
      await media.open();
      final relay = freshRelay();
      final offer = await media.restartOffer(
        callId: restartCallId,
        relay: relay,
      );
      expect(offer.type, 'offer');
      expect(peer.operations, ['configuration', 'offer', 'local']);
      expect(peer.updated?['iceServers'], relay.iceServers);
      expect(peer.updated?['sdpSemantics'], 'unified-plan');
      expect(captures, 1);
      expect(stream.track.stops, 0);
      await media.close();
    },
  );
  test('ICE restart rejects mismatched credentials and stops on partial native failure', () async {
    final stream = StreamFixture(), peer = RestartPeer();
    final media = NativeCallMedia(
      video: true,
      iceServers: [],
      capture: (_) async => stream,
      peerFactory: (_) async => peer,
    );
    await media.open();
    expect(
      () => media.restartOffer(
        callId: '00000000-0000-4000-8000-000000000002',
        relay: freshRelay(),
      ),
      throwsStateError,
    );
    expect(peer.operations, isEmpty);
    peer.fail = true;
    await expectLater(
      media.restartOffer(callId: restartCallId, relay: freshRelay()),
      throwsStateError,
    );
    expect(peer.operations, ['configuration']);
    expect(stream.track.stops, 1);
    expect(peer.closes, 1);
  });

  test('speaker route failure preserves state and late completion cannot override hangup reset', () async {
    final stream = StreamFixture();
    var response = Completer<void>();
    final routes = <bool>[];
    final media = NativeCallMedia(
      video: false,
      iceServers: [],
      capture: (_) async => stream,
      peerFactory: (_) async => Peer(),
      setSpeakerphone: (enabled) {
        routes.add(enabled);
        return enabled ? response.future : Future.value();
      },
    );
    await media.open();
    final failed = media.setSpeakerphone(true);
    final failure = expectLater(failed, throwsException);
    response.completeError(Exception('route unavailable'));
    await failure;
    expect(media.speakerRequested, false);
    response = Completer<void>();
    final switching = media.setSpeakerphone(true);
    final late = expectLater(switching, throwsStateError);
    await expectLater(media.setSpeakerphone(false), throwsStateError);
    final closing = media.close();
    await Future<void>.delayed(Duration.zero);
    expect(stream.track.stops, 1);
    expect(stream.disposed, 1);
    response.complete();
    await late;
    await closing;
    expect(routes, [true, true, false]);
    expect(media.speakerRequested, false);
  });
  test('speaker state changes only after acknowledged routing', () async {
    final response = Completer<void>();
    final media = NativeCallMedia(
      video: false,
      iceServers: [],
      capture: (_) async => StreamFixture(),
      peerFactory: (_) async => Peer(),
      setSpeakerphone: (enabled) => enabled ? response.future : Future.value(),
    );
    await media.open();
    final switching = media.setSpeakerphone(true);
    expect(media.speakerRequested, false);
    response.complete();
    await switching;
    expect(media.speakerRequested, true);
    await media.close();
    expect(media.speakerRequested, false);
  });

  test('camera switch coalesces, handles rear result, retries errors and rejects late completion after hangup', () async {
    final stream = StreamFixture();
    var response = Completer<bool>();
    var switches = 0;
    final media = NativeCallMedia(
      video: true,
      iceServers: [],
      capture: (_) async => stream,
      peerFactory: (_) async => Peer(),
      switchCamera: (track) {
        expect(track, stream.track);
        switches++;
        return response.future;
      },
    );
    await media.open();
    final first = media.switchCamera();
    expect(identical(first, media.switchCamera()), true);
    response.complete(false);
    expect(await first, false);
    expect(media.frontFacing, false);
    expect(switches, 1);
    response = Completer<bool>();
    final failed = media.switchCamera();
    final assertion = expectLater(failed, throwsException);
    response.completeError(Exception('camera unavailable'));
    await assertion;
    expect(media.frontFacing, false);
    response = Completer<bool>();
    final late = media.switchCamera();
    final lateAssertion = expectLater(late, throwsStateError);
    await media.close();
    expect(stream.track.stops, 1);
    response.complete(true);
    await lateAssertion;
    expect(media.frontFacing, false);
    expect(() => media.switchCamera(), throwsStateError);
  });
  test('audio call never requests camera switching', () async {
    var switches = 0;
    final media = NativeCallMedia(
      video: false,
      iceServers: [],
      capture: (_) async => StreamFixture(),
      peerFactory: (_) async => Peer(),
      switchCamera: (_) async {
        switches++;
        return true;
      },
    );
    await media.open();
    await expectLater(media.switchCamera(), throwsStateError);
    expect(switches, 0);
    await media.close();
  });

  test(
    'late capture after close is stopped without creating a connection',
    () async {
      final capture = Completer<MediaStream>(), stream = StreamFixture();
      int peers = 0;
      final media = NativeCallMedia(
        video: false,
        iceServers: [],
        capture: (_) => capture.future,
        peerFactory: (_) async {
          peers++;
          return Peer();
        },
      );
      final opening = media.open();
      final failed = expectLater(opening, throwsStateError);
      final closing = media.close();
      capture.complete(stream);
      await failed;
      await closing;
      expect(peers, 0);
      expect(stream.track.stops, 1);
      expect(stream.disposed, 1);
    },
  );
  test(
    'queued ICE waits for remote SDP and close releases resources exactly once',
    () async {
      final stream = StreamFixture(), peer = Peer();
      final media = NativeCallMedia(
        setMicrophoneMute: (muted, track) async {
          track.enabled = !muted;
        },
        video: false,
        iceServers: [],
        capture: (constraints) async {
          expect(constraints['video'], false);
          expect((constraints['audio'] as Map)['noiseSuppression'], true);
          return stream;
        },
        peerFactory: (_) async => peer,
      );
      await media.open();
      await media.mute(true);
      expect(stream.track.enabled, false);
      await media.remoteCandidate(RTCIceCandidate('candidate:fixture', '0', 0));
      expect(peer.candidates, 0);
      await media.remoteDescription(RTCSessionDescription('v=0', 'offer'));
      expect(peer.candidates, 1);
      await media.close();
      await media.close();
      expect(stream.track.stops, 1);
      expect(stream.disposed, 1);
      expect(peer.closes, 1);
      expect(peer.disposes, 1);
      await expectLater(media.open(), throwsStateError);
    },
  );
}
