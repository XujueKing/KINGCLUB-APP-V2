import 'package:kingclub/src/features/messaging/data/call_relay_configuration.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kingclub/src/features/messaging/data/native_call_media.dart';

class Track implements MediaStreamTrack {
  int stops = 0;
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
      media.mute(true);
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
