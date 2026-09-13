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

void main() {
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
