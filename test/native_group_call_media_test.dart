import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/call_relay_configuration.dart';
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
  String get kind => track.kind!;
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
  final events = <String, Function>{};
  Function? produced;
  Function? consumed;
  ConsumerFixture? consumer;
  void Function()? afterProduced;
  int closes = 0;
  bool failProduce = false, failClose = false;
  ProducerFixture? producer;
  @override
  String get id => callId;
  @override
  void on(String event, Function handler) {
    events[event] = handler;
  }

  @override
  Future<void> close() async {
    closes++;
    if (failClose) {
      throw StateError('Close failed');
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #consume) {
      consumer = ConsumerFixture();
      consumed!(consumer, null);
      return null;
    }
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
  List<dynamic>? sendIce, receiveIce;
  final send = TransportFixture(), receive = TransportFixture();
  int loads = 0;
  @override
  rtc.RtpCapabilities get rtpCapabilities => rtc.RtpCapabilities();
  @override
  Future<void> load({
    required rtc.RtpCapabilities routerRtpCapabilities,
  }) async {
    loads++;
  }

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #createSendTransport) {
      sendIce = List<dynamic>.from(i.namedArguments[#iceServers] as List);
      send.produced = i.namedArguments[#producerCallback] as Function;
      return send;
    }
    if (i.memberName == #createRecvTransport) {
      receiveIce = List<dynamic>.from(i.namedArguments[#iceServers] as List);
      receive.consumed = i.namedArguments[#consumerCallback] as Function;
      return receive;
    }
    return super.noSuchMethod(i);
  }
}

class ConsumerFixture implements rtc.Consumer {
  @override
  String get id => callId;
  @override
  String get producerId => callId;
  @override
  final StreamFixture stream = StreamFixture();
  int closes = 0;
  @override
  Future<void> close() async {
    closes++;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class DepartingRepo extends Repo {
  bool stays = false, failResume = false;
  String failureCode = 'CHAT_GROUP_MEDIA_STATE_CHANGED';
  int reads = 0;
  @override
  Future<List<GroupMediaSource>> sources() async => ++reads == 1 || stays
      ? [const GroupMediaSource(callId, 'friend', 'audio', false)]
      : [];
  @override
  Future<GroupMediaConsumer> consume(
    String transportId,
    GroupMediaSource source,
    rtc.RtpCapabilities caps,
  ) async {
    if (failResume) {
      return GroupMediaConsumer(callId, source, rtc.RtpParameters(codecs: []));
    }
    throw AuthFailure(failureCode, 'Synthetic failure');
  }

  @override
  Future<void> resumeConsumer(String id) async =>
      throw AuthFailure(failureCode, 'Synthetic failure');
}

class Repo extends GroupCallMediaRepository {
  Repo({bool video = false})
    : super(
        MessagingRepository(
          account: 'me',
          call: (_, _) async => throw StateError('Unexpected request'),
        ),
        GroupCallSnapshot.parse({
          'callId': callId,
          'groupId': callId,
          'mediaKind': video ? 'video' : 'audio',
          'version': 1,
          'endedAtMs': null,
          'participants': [
            {'account': 'me', 'phase': 'joined', 'deadlineMs': 1000},
            {'account': 'friend', 'phase': 'joined', 'deadlineMs': 1000},
          ],
        }, 'me'),
      );
  int closes = 0;
  Object? relayFailure;
  @override
  Future<CallRelayConfiguration> readRelay() async {
    if (relayFailure != null) throw relayFailure!;
    final expiry = (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600) * 1000;
    return CallRelayConfiguration.parse(callId, {
      'expiresAtMs': expiry,
      'iceServers': [
        {
          'urls': ['turn:relay.example.test:3478?transport=udp'],
          'username': '${expiry ~/ 1000}:${List.filled(32, 'a').join()}',
          'credential': '${List.filled(27, 'A').join()}=',
        },
      ],
    });
  }

  Object? connectFailure;
  int connects = 0;
  @override
  Future<void> connect(String id, rtc.DtlsParameters parameters) async {
    connects++;
    if (connectFailure != null) throw connectFailure!;
  }

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
  test('relay failure cannot start native capture', () async {
    final repo = Repo()..relayFailure = const FormatException('Expired relay');
    final device = DeviceFixture();
    var captured = false;
    final media = NativeGroupCallMedia(
      repository: repo,
      device: device,
      capture: (_) async {
        captured = true;
        return StreamFixture();
      },
    );
    await expectLater(media.open(), throwsFormatException);
    expect(captured, false);
    expect(device.loads, 0);
    expect(media.isClosed, true);
  });
  test('SDK connect callback acknowledges server success and releases capture on rejection', () async {
    final repo = Repo(), device = DeviceFixture(), stream = StreamFixture();
    final errors = <Object>[];
    final media = NativeGroupCallMedia(
      repository: repo,
      device: device,
      capture: (_) async => stream,
      onError: errors.add,
    );
    await media.open();
    final dtls = rtc.DtlsParameters.fromMap({
      'role': 'client',
      'fingerprints': <dynamic>[],
    });
    var acknowledgements = 0;
    Object? rejected;
    await device.send.events['connect']!({
      'dtlsParameters': dtls,
      'callback': () {
        acknowledgements++;
      },
      'errback': (Object error) {
        rejected = error;
      },
    });
    expect(repo.connects, 1);
    expect(acknowledgements, 1);
    expect(rejected, null);
    repo.connectFailure = const AuthFailure(
      'SESSION_CHANGED',
      'Session changed',
    );
    await device.receive.events['connect']!({
      'dtlsParameters': dtls,
      'callback': () {
        acknowledgements++;
      },
      'errback': (Object error) {
        rejected = error;
      },
    });
    await media.close();
    expect(acknowledgements, 1);
    expect(rejected, same(repo.connectFailure));
    expect(errors, [repo.connectFailure]);
    expect(stream.track.stops, 1);
    expect(device.send.closes, 1);
    expect(device.receive.closes, 1);
  });
  test(
    'hangup stops capture before pending speaker enable and resets after it',
    () async {
      final pendingRoute = Completer<void>(), started = Completer<void>();
      final routes = <bool>[];
      final stream = StreamFixture();
      final media = NativeGroupCallMedia(
        repository: Repo(),
        device: DeviceFixture(),
        capture: (_) async => stream,
        setSpeakerphone: (enabled) async {
          routes.add(enabled);
          if (enabled) {
            started.complete();
            await pendingRoute.future;
          }
        },
      );
      await media.open();
      final routing = media.setSpeakerphone(true);
      final assertion = expectLater(routing, throwsStateError);
      await started.future;
      await expectLater(media.setSpeakerphone(false), throwsStateError);
      final closing = media.close();
      await Future<void>.delayed(Duration.zero);
      expect(stream.track.stops, 1);
      expect(routes, [true]);
      pendingRoute.complete();
      await assertion;
      await closing;
      expect(routes, [true, false]);
    },
  );
  test(
    'camera switch returns actual facing and drops a late result after close',
    () async {
      final stream = VideoStream(), result = Completer<bool>();
      final switching = Completer<void>();
      var calls = 0;
      final media = NativeGroupCallMedia(
        repository: Repo(video: true),
        device: DeviceFixture(),
        capture: (_) async => stream,
        switchCamera: (track) async {
          expect(track, same(stream.camera));
          if (++calls == 1) return false;
          switching.complete();
          return result.future;
        },
      );
      await media.open();
      expect(await media.switchCamera(), false);
      final pending = media.switchCamera();
      final assertion = expectLater(pending, throwsStateError);
      await switching.future;
      await media.close();
      result.complete(true);
      await assertion;
      expect(stream.camera.stops, 1);
      expect(stream.track.stops, 1);
    },
  );
  for (final failResume in [false, true]) {
    test(
      'remote departure during ${failResume ? "resume" : "consume"} preserves local media',
      () async {
        final repo = DepartingRepo()..failResume = failResume;
        final device = DeviceFixture(), stream = StreamFixture();
        List<NativeGroupRemote>? remote;
        final media = NativeGroupCallMedia(
          repository: repo,
          device: device,
          capture: (_) async => stream,
          onRemote: (value) => remote = value,
        );
        await media.open();
        expect(media.isClosed, false);
        expect(remote, isEmpty);
        expect(stream.track.stops, 0);
        if (failResume) {
          expect(device.receive.consumer!.closes, 1);
          expect(device.receive.consumer!.stream.disposed, 1);
        }
        await media.close();
      },
    );
  }
  test('a remaining source failure is not swallowed', () async {
    final repo = DepartingRepo()..stays = true;
    final media = NativeGroupCallMedia(
      repository: repo,
      device: DeviceFixture(),
      capture: (_) async => StreamFixture(),
    );
    await expectLater(media.open(), throwsA(isA<AuthFailure>()));
    expect(media.isClosed, true);
    expect(repo.reads, 2);
  });
  test('login failures do not retry as remote departures', () async {
    final repo = DepartingRepo()..failureCode = 'SESSION_CHANGED';
    final media = NativeGroupCallMedia(
      repository: repo,
      device: DeviceFixture(),
      capture: (_) async => StreamFixture(),
    );
    await expectLater(media.open(), throwsA(isA<AuthFailure>()));
    expect(media.isClosed, true);
    expect(repo.reads, 1);
  });
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
      expect(device.sendIce!.single.urls, [
        'turn:relay.example.test:3478?transport=udp',
      ]);
      expect(
        device.receiveIce!.single.username,
        device.sendIce!.single.username,
      );
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

class CameraTrack extends Track {
  @override
  String get kind => 'video';
}

class VideoStream extends StreamFixture {
  final camera = CameraTrack();
  @override
  List<rtc.MediaStreamTrack> getTracks() => [track, camera];
  @override
  List<rtc.MediaStreamTrack> getVideoTracks() => [camera];
}
