import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart'
    as rtc;
import 'package:kingclub/src/features/messaging/data/group_call_media_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/native_group_call_media.dart';

const callId = '00000000-0000-4000-8000-000000000001';

class Track implements rtc.MediaStreamTrack {
  int stops = 0;
  @override
  String get kind => 'audio';
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class StreamFixture implements rtc.MediaStream {
  final track = Track();
  int disposed = 0;
  @override
  List<rtc.MediaStreamTrack> getTracks() => [track];
  @override
  List<rtc.MediaStreamTrack> getAudioTracks() => [track];
  @override
  Future<void> dispose() async {
    disposed++;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class ProducerFixture implements rtc.Producer {
  ProducerFixture(this.track);
  @override
  final rtc.MediaStreamTrack track;
  @override
  String get kind => 'audio';
  @override
  String get id => callId;
  int closes = 0;
  @override
  void close() {
    closes++;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class TransportFixture implements rtc.Transport {
  Function? produced;
  void Function()? afterProduced;
  int closes = 0;
  bool failProduce = false, failClose = false;
  ProducerFixture? producer;
  @override
  String get id => callId;
  @override
  void on(String event, Function handler) {}
  @override
  Future<void> close() async {
    closes++;
    if (failClose) {
      throw StateError('Close failed');
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #produce) {
      if (failProduce) {
        throw StateError('Produce failed');
      }
      producer = ProducerFixture(
        i.namedArguments[#track] as rtc.MediaStreamTrack,
      );
      produced!(producer);
      afterProduced?.call();
      return null;
    }
    return super.noSuchMethod(i);
  }
}

class DeviceFixture implements rtc.Device {
  final send = TransportFixture(), receive = TransportFixture();
  int loads = 0;
  @override
  Future<void> load({
    required rtc.RtpCapabilities routerRtpCapabilities,
  }) async {
    loads++;
  }

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #createSendTransport) {
      send.produced = i.namedArguments[#producerCallback] as Function;
      return send;
    }
    if (i.memberName == #createRecvTransport) {
      return receive;
    }
    return super.noSuchMethod(i);
  }
}

class Repo extends GroupCallMediaRepository {
  Repo()
    : super(
        MessagingRepository(
          account: 'me',
          call: (_, _) async => throw StateError('Unexpected request'),
        ),
        GroupCallSnapshot.parse({
          'callId': callId,
          'groupId': callId,
          'mediaKind': 'audio',
          'version': 1,
          'endedAtMs': null,
          'participants': [
            {'account': 'me', 'phase': 'joined', 'deadlineMs': 1000},
            {'account': 'friend', 'phase': 'joined', 'deadlineMs': 1000},
          ],
        }, 'me'),
      );
  int closes = 0;
  @override
  Future<rtc.RtpCapabilities> capabilities() async => rtc.RtpCapabilities();
  @override
  Future<GroupMediaTransport> createTransport({required bool sending}) async =>
      GroupMediaTransport(
        callId,
        rtc.IceParameters(
          usernameFragment: 'synthetic',
          password: 'synthetic',
          iceLite: true,
        ),
        [],
        rtc.DtlsParameters.fromMap({
          'role': 'auto',
          'fingerprints': <dynamic>[],
        }),
      );
  @override
  Future<List<GroupMediaSource>> sources() async => [];
  @override
  void close() {
    closes++;
    super.close();
  }
}

void main() {
  test('close between producer callback and await continuation still closes the producer', () async {
    final device = DeviceFixture(), stream = StreamFixture();
    final media = NativeGroupCallMedia(
      repository: Repo(),
      device: device,
      capture: (_) async => stream,
    );
    device.send.afterProduced = () => unawaited(media.close());
    await expectLater(media.open(), throwsStateError);
    expect(device.send.producer!.closes, 1);
    expect(stream.track.stops, 1);
    expect(stream.disposed, 1);
  });
  test(
    'construction is passive and explicit open requests audio processing',
    () async {
      final repo = Repo(), device = DeviceFixture(), stream = StreamFixture();
      Map<String, dynamic>? constraints;
      final media = NativeGroupCallMedia(
        repository: repo,
        device: device,
        capture: (value) async {
          constraints = value;
          return stream;
        },
      );
      expect(device.loads, 0);
      expect(constraints, null);
      await media.open();
      expect(constraints!['audio'], {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      });
      expect(constraints!['video'], false);
      await media.close();
      await media.close();
      expect(stream.track.stops, 1);
      expect(stream.disposed, 1);
      expect(device.send.closes, 1);
      expect(device.receive.closes, 1);
      expect(repo.closes, 1);
    },
  );
  test(
    'a late capture result is stopped after close and never published',
    () async {
      final device = DeviceFixture(), stream = StreamFixture();
      final started = Completer<void>(), capture = Completer<rtc.MediaStream>();
      final media = NativeGroupCallMedia(
        repository: Repo(),
        device: device,
        capture: (_) {
          started.complete();
          return capture.future;
        },
      );
      final opening = media.open();
      await started.future;
      await media.close();
      capture.complete(stream);
      await expectLater(opening, throwsStateError);
      expect(stream.track.stops, 1);
      expect(stream.disposed, 1);
      expect(device.send.producer, null);
    },
  );
  test('synchronous publish failure releases capture and both transports despite close failure', () async {
    final device = DeviceFixture(), stream = StreamFixture();
    device.send.failProduce = true;
    device.send.failClose = true;
    final media = NativeGroupCallMedia(
      repository: Repo(),
      device: device,
      capture: (_) async => stream,
    );
    await expectLater(media.open(), throwsStateError);
    expect(stream.track.stops, 1);
    expect(stream.disposed, 1);
    expect(device.send.closes, 1);
    expect(device.receive.closes, 1);
    expect(media.isClosed, true);
  });
}
