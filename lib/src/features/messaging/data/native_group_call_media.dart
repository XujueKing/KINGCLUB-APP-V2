import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart'
    as rtc;
// The pinned SDK exposes this type in createTransport but not its barrel export.
// ignore: implementation_imports
import 'package:mediasfu_mediasoup_client/src/handlers/handler_interface.dart'
    as handler;

import 'call_repository.dart' show CallMedia;
import '../../auth/domain/auth_repository.dart';
import 'call_relay_configuration.dart';
import 'group_call_media_repository.dart';

class NativeGroupRemote {
  const NativeGroupRemote(this.source, this.stream);
  final GroupMediaSource source;
  final rtc.MediaStream stream;
}

/// Creates no native resources until open, which the call owner invokes only
/// after explicit start/accept. This object never accepts or renews a call.
class NativeGroupCallMedia {
  NativeGroupCallMedia({
    required this.repository,
    this.relay,
    rtc.Device? device,
    Future<rtc.MediaStream> Function(Map<String, dynamic>)? capture,
    this.onLocal,
    this.onRemote,
    this.onConnection,
    this.onError,
  }) : _device = device ?? rtc.Device(),
       _capture = capture ?? rtc.navigator.mediaDevices.getUserMedia;
  final GroupCallMediaRepository repository;
  final CallRelayConfiguration? relay;
  final rtc.Device _device;
  final Future<rtc.MediaStream> Function(Map<String, dynamic>) _capture;
  final void Function(rtc.MediaStream)? onLocal;
  final void Function(List<NativeGroupRemote>)? onRemote;
  final void Function(String direction, String state)? onConnection;
  final void Function(Object)? onError;
  rtc.Transport? _send, _receive;
  rtc.MediaStream? _local;
  final _producers = <String, rtc.Producer>{};
  final _consumers = <String, rtc.Consumer>{};
  final _publishing = <String, Completer<rtc.Producer>>{};
  final _consuming = <String, Completer<rtc.Consumer>>{};
  bool _closed = false;
  Future<void>? _opening, _closing, _refreshing;
  Future<void> _controls = Future.value();
  Timer? _poll;
  bool get isClosed => _closed;
  rtc.MediaStream? get localStream => _local;
  void _check() {
    if (_closed) {
      throw StateError('Group media closed');
    }
  }

  Future<void> open() {
    if (_closed) {
      return Future.error(StateError('Group media closed'));
    }
    return _opening ??= _open();
  }

  Future<void> _open() async {
    try {
      relay?.requireUsable(repository.call.id);
      final iceServers = (relay?.iceServers ?? <Map<String, dynamic>>[])
          .map(
            (server) => handler.RTCIceServer(
              credentialType: handler.RTCIceCredentialType.password,
              username: server['username'] as String,
              credential: server['credential'],
              urls: List<String>.from(server['urls'] as List),
            ),
          )
          .toList();
      final caps = await repository.capabilities();
      _check();
      await _device.load(routerRtpCapabilities: caps);
      _check();
      final send = await repository.createTransport(sending: true);
      _check();
      _send = _device.createSendTransport(
        id: send.id,
        iceParameters: send.iceParameters,
        iceCandidates: send.iceCandidates,
        dtlsParameters: send.dtlsParameters,
        iceServers: iceServers,
        producerCallback: _produced,
      );
      _wire(_send!, 'send');
      _send!.on('produce', (Map data) async {
        try {
          _check();
          final id = await repository.produce(
            _send!.id,
            data['kind'] as String,
            data['rtpParameters'] as rtc.RtpParameters,
          );
          _check();
          (data['callback'] as Function)(id);
        } catch (error) {
          (data['errback'] as Function)(error);
          _fail(error);
        }
      });
      final receive = await repository.createTransport(sending: false);
      _check();
      _receive = _device.createRecvTransport(
        id: receive.id,
        iceParameters: receive.iceParameters,
        iceCandidates: receive.iceCandidates,
        dtlsParameters: receive.dtlsParameters,
        iceServers: iceServers,
        consumerCallback: _consumed,
      );
      _wire(_receive!, 'receive');
      final stream = await _capture({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': repository.call.media == CallMedia.video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
                'frameRate': {'ideal': 24, 'max': 30},
              }
            : false,
      });
      if (_closed) {
        await _disposeStream(stream);
        _check();
      }
      _local = stream;
      if (stream.getAudioTracks().isEmpty) {
        throw StateError('Microphone track missing');
      }
      for (final track in stream.getTracks()) {
        _check();
        if (track.kind != 'audio' && track.kind != 'video') {
          continue;
        }
        final completer = Completer<rtc.Producer>();
        _publishing[track.kind!] = completer;
        final ready = completer.future.timeout(const Duration(seconds: 15));
        try {
          _send!.produce(
            track: track,
            stream: stream,
            source: track.kind == 'audio' ? 'mic' : 'camera',
            stopTracks: false,
            encodings: [
              rtc.RtpEncodingParameters(
                maxBitrate: track.kind == 'audio' ? 64000 : 600000,
              ),
            ],
          );
        } catch (error, stack) {
          if (!completer.isCompleted) {
            completer.completeError(error, stack);
          }
        }
        final producer = await ready;
        _publishing.remove(track.kind);
        _check();
        _producers[track.kind!] = producer;
      }
      _check();
      onLocal?.call(stream);
      await refreshRemote();
      _check();
      _poll = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(refreshRemote().catchError((Object error) => _fail(error)));
      });
    } catch (_) {
      await close();
      rethrow;
    }
  }

  void _wire(rtc.Transport transport, String direction) {
    transport.on('connect', (Map data) async {
      try {
        _check();
        await repository.connect(
          transport.id,
          data['dtlsParameters'] as rtc.DtlsParameters,
        );
        _check();
        (data['callback'] as Function)();
      } catch (error) {
        (data['errback'] as Function)(error);
        _fail(error);
      }
    });
    transport.on('connectionstatechange', (Map data) {
      if (_closed) {
        return;
      }
      final state = data['connectionState'] as String;
      onConnection?.call(direction, state);
      if (state == 'failed' || state == 'closed') {
        _fail(StateError('Group media transport failed'));
      }
    });
  }

  void _produced(rtc.Producer producer) {
    final pending = _publishing[producer.kind];
    if (_closed || pending == null || pending.isCompleted) {
      producer.close();
      return;
    }
    _producers[producer.kind] = producer;
    pending.complete(producer);
  }

  void _consumed(rtc.Consumer consumer, dynamic accept) {
    final pending = _consuming[consumer.id];
    if (_closed || pending == null || pending.isCompleted) {
      unawaited(_disposeConsumer(consumer));
      return;
    }
    _consumers[consumer.producerId] = consumer;
    pending.complete(consumer);
  }

  Future<void> refreshRemote() {
    if (_closed) {
      return Future.error(StateError('Group media closed'));
    }
    return _refreshing ??= _refreshRemote().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<void> _refreshRemote() async {
    final receive = _receive;
    if (receive == null) {
      throw StateError('Receive transport not ready');
    }
    final sources = await repository.sources();
    _check();
    final active = sources.map((s) => s.producerId).toSet();
    for (final id in _consumers.keys.toList()) {
      if (!active.contains(id)) {
        await _disposeConsumer(_consumers.remove(id)!);
        _check();
      }
    }
    for (final source in sources) {
      _check();
      if (_consumers.containsKey(source.producerId)) {
        continue;
      }
      try {
        await _receiveSource(receive, source);
      } on AuthFailure catch (error) {
        if (error.code != 'CHAT_GROUP_MEDIA_STATE_CHANGED') rethrow;
        // A producer may disappear between listing, consuming and resuming.
        // Confirm its removal through an authorized read; never hide a login,
        // transport or codec failure when the source is still present.
        final current = await repository.sources();
        _check();
        if (current.any((s) => s.producerId == source.producerId)) rethrow;
        final stale = _consumers.remove(source.producerId);
        if (stale != null) await _disposeConsumer(stale);
        _check();
      }
    }
    onRemote?.call(
      List.unmodifiable(
        sources
            .where((s) => _consumers.containsKey(s.producerId))
            .map((s) => NativeGroupRemote(s, _consumers[s.producerId]!.stream)),
      ),
    );
  }

  Future<void> _receiveSource(
    rtc.Transport receive,
    GroupMediaSource source,
  ) async {
    final spec = await repository.consume(
      receive.id,
      source,
      _device.rtpCapabilities,
    );
    _check();
    final completer = Completer<rtc.Consumer>();
    _consuming[spec.id] = completer;
    final ready = completer.future.timeout(const Duration(seconds: 15));
    try {
      receive.consume(
        id: spec.id,
        producerId: source.producerId,
        peerId: source.account,
        kind: source.kind == 'audio'
            ? rtc.RTCRtpMediaType.RTCRtpMediaTypeAudio
            : rtc.RTCRtpMediaType.RTCRtpMediaTypeVideo,
        rtpParameters: spec.rtpParameters,
      );
    } catch (error, stack) {
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
    }
    final consumer = await ready;
    _consuming.remove(spec.id);
    if (_closed) {
      await _disposeConsumer(consumer);
      _check();
    }
    _consumers[source.producerId] = consumer;
    await repository.resumeConsumer(consumer.id);
    _check();
  }

  Future<void> setPaused(String kind, bool paused) {
    final next = _controls.then((_) async {
      _check();
      final producer = _producers[kind];
      if (producer == null) {
        throw StateError('Track not published');
      }
      if (paused) {
        await _enable(producer.track, false);
        _check();
      }
      await repository.setProducerPaused(producer.id, paused);
      _check();
      if (!paused) {
        await _enable(producer.track, true);
        _check();
      }
    });
    _controls = next.catchError((Object error) {
      _fail(error);
    });
    return next;
  }

  static Future<void> _enable(rtc.MediaStreamTrack track, bool enabled) async {
    if (kIsWeb) {
      track.enabled = enabled;
      return;
    }
    await rtc.WebRTC.invokeMethod('mediaStreamTrackSetEnable', {
      'trackId': track.id,
      'enabled': enabled,
      'peerConnectionId': '',
    });
  }

  void _fail(Object error) {
    if (_closed) {
      return;
    }
    unawaited(close());
    onError?.call(error);
  }

  static Future<void> _disposeStream(rtc.MediaStream stream) async {
    try {
      for (final track in stream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {}
      }
    } catch (_) {}
    try {
      await stream.dispose();
    } catch (_) {}
  }

  static Future<void> _disposeConsumer(rtc.Consumer consumer) async {
    try {
      await consumer.close();
    } catch (_) {}
    await _disposeStream(consumer.stream);
  }

  Future<void> close() {
    if (_closing != null) {
      return _closing!;
    }
    _closed = true;
    repository.close();
    _poll?.cancel();
    for (final pending in _publishing.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('Group media closed'));
      }
    }
    for (final pending in _consuming.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('Group media closed'));
      }
    }
    _publishing.clear();
    _consuming.clear();
    return _closing = _close();
  }

  Future<void> _close() async {
    final local = _local;
    _local = null;
    // Stop capture first, even if closing an SDK transport throws or stalls.
    if (local != null) {
      await _disposeStream(local);
    }
    for (final producer in _producers.values) {
      try {
        producer.close();
      } catch (_) {}
    }
    _producers.clear();
    final consumers = _consumers.values.toList();
    _consumers.clear();
    await Future.wait(consumers.map(_disposeConsumer));
    for (final transport in [_send, _receive]) {
      try {
        await transport?.close().timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    _send = null;
    _receive = null;
  }
}
