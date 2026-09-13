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
