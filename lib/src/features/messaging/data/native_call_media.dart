import 'call_audio_constraints.dart';

import 'package:flutter/foundation.dart';

import 'call_relay_configuration.dart';
import 'call_foreground_lease.dart';

import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef CallCapture = Future<MediaStream> Function(
  Map<String, dynamic> constraints,
);
typedef CallPeerFactory = Future<RTCPeerConnection> Function(
  Map<String, dynamic> configuration,
);

/// Owns one native call. Creating this object never requests media permissions.
class NativeCallMedia {
  NativeCallMedia({
    required this.video,
    required this.iceServers,
    CallCapture? capture,
    CallPeerFactory? peerFactory,
    Future<void> Function(bool)? setSpeakerphone,
    Future<void> Function(bool, MediaStreamTrack)? setMicrophoneMute,
    Future<void> Function(bool, MediaStreamTrack)? setVideoEnabled,
    Future<bool> Function(MediaStreamTrack)? switchCamera,
    CallForegroundLease? foregroundLease,
    this.onCandidate,
    this.onConnection,
    this.onRemoteStream,
  }) : _foregroundLease = foregroundLease ?? CallForegroundLease(),
       _capture = capture ?? navigator.mediaDevices.getUserMedia,
       _peerFactory = peerFactory ?? ((config) => createPeerConnection(config)),
       _switchCamera = switchCamera ?? ((track) => Helper.switchCamera(track)),
       _setSpeakerphone = setSpeakerphone ?? Helper.setSpeakerphoneOn,
       _setMicrophoneMute = setMicrophoneMute ?? _setLocalTrackMuted,
       _setVideoEnabled =
           setVideoEnabled ??
           ((enabled, track) => _setLocalTrackMuted(!enabled, track));
  // The plugin's enabled setter does not await its platform call. Use the
  // same local-track command with acknowledgement, not the system-wide mute API.
  static Future<void> _setLocalTrackMuted(
    bool muted,
    MediaStreamTrack track,
  ) async {
    if (kIsWeb) {
      track.enabled = !muted;
      return;
    }
    await WebRTC.invokeMethod('mediaStreamTrackSetEnable', {
      'trackId': track.id,
      'enabled': !muted,
      'peerConnectionId': '',
    });
  }

  final Future<void> Function(bool, MediaStreamTrack) _setMicrophoneMute;
  final CallForegroundLease _foregroundLease;
  Future<void>? _muting;
  final Future<void> Function(bool, MediaStreamTrack) _setVideoEnabled;
  Future<void>? _changingVideo;
  bool _videoEnabled = true;
  bool get videoEnabled => video && _videoEnabled;
  final bool video;
  final List<Map<String, dynamic>> iceServers;
  final CallCapture _capture;
  final CallPeerFactory _peerFactory;
  final Future<void> Function(bool) _setSpeakerphone;
  Future<void>? _routingAudio;
  bool _speakerRequested = false, _speakerControlUsed = false;
  bool get speakerRequested => _speakerRequested;
  final Future<bool> Function(MediaStreamTrack) _switchCamera;
  Future<bool>? _switchingCamera;
  bool _frontFacing = true;
  bool get frontFacing => _frontFacing;
  final void Function(RTCIceCandidate)? onCandidate;
  final void Function(RTCPeerConnectionState)? onConnection;
  final void Function(MediaStream)? onRemoteStream;
  MediaStream? _local, _remote;
  RTCPeerConnection? _peer;
  Future<void>? _opening, _closing;
  Future<RTCSessionDescription>? _restarting;
  bool _closed = false, _remoteReady = false;
  final _candidates = <RTCIceCandidate>[];
  MediaStream? get localStream => _local;
  MediaStream? get remoteStream => _remote;

  Future<void> open() {
    if (_closed) return Future.error(StateError('Call media closed'));
    return _opening ??= _open();
  }

  void _check() {
    if (_closed) throw StateError('Call media closed');
  }

  Future<void> _open() async {
    try {
      _local = await _capture({
        'audio': callAudioConstraints,
        'video': video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 24, 'max': 30},
              }
            : false,
      });
      _check();
      await _foregroundLease.start(video: video);
      _check();
      _peer = await _peerFactory({
        'iceServers': iceServers,
        'sdpSemantics': 'unified-plan',
      });
      _check();
      _peer!.onIceCandidate = (candidate) {
        if (!_closed) onCandidate?.call(candidate);
      };
      _peer!.onConnectionState = (state) {
        if (!_closed) onConnection?.call(state);
      };
      _peer!.onTrack = (event) {
        if (_closed || event.streams.isEmpty) return;
        _remote = event.streams.first;
        onRemoteStream?.call(_remote!);
      };
      for (final track in _local!.getTracks()) {
        await _peer!.addTrack(track, _local!);
        _check();
      }
    } catch (_) {
      _closed = true;
      await _release();
      rethrow;
    }
  }

  RTCPeerConnection get _ready {
    _check();
    final peer = _peer;
    if (peer == null) throw StateError('Call media not ready');
    return peer;
  }

  Future<RTCSessionDescription> offer() async {
    final peer = _ready, description = await _ready.createOffer();
    _check();
    await peer.setLocalDescription(description);
    _check();
    return description;
  }

  /// Replace expiring ICE credentials and negotiate on the existing tracks.
  /// The session owner must publish this offer under a fresh signal generation.
  Future<RTCSessionDescription> restartOffer({
    required String callId,
    required CallRelayConfiguration relay,
  }) {
    _check();
    relay.requireUsable(callId);
    if (_restarting != null) {
      return Future.error(StateError('ICE restart already in progress'));
    }
    return _restarting = _restartOffer(relay)
        .whenComplete(() => _restarting = null);
  }

  Future<RTCSessionDescription> _restartOffer(
    CallRelayConfiguration relay,
  ) async {
    final peer = _ready;
    try {
      await peer.setConfiguration({
        ...peer.getConfiguration,
        'iceServers': relay.iceServers,
      });
      _check();
      _remoteReady = false;
      _candidates.clear();
      final offer = await peer.createOffer({'iceRestart': true});
      _check();
      await peer.setLocalDescription(offer);
      _check();
      return offer;
    } catch (_) {
      // Configuration/SDP may be partially applied in native code. Do not
      // continue sending media with an unknown negotiation state.
      await close();
      rethrow;
    }
  }

  Future<void> prepareRemoteRestart({
    required String callId,
    required CallRelayConfiguration relay,
  }) async {
    _check();
    relay.requireUsable(callId);
    final peer = _ready;
    try {
      await peer.setConfiguration({
        ...peer.getConfiguration,
        'iceServers': relay.iceServers,
      });
      _check();
      _remoteReady = false;
      _candidates.clear();
    } catch (_) {
      await close();
      rethrow;
    }
  }

  Future<RTCSessionDescription> answer() async {
    final peer = _ready, description = await _ready.createAnswer();
    _check();
    await peer.setLocalDescription(description);
    _check();
    return description;
  }

  Future<void> remoteDescription(RTCSessionDescription description) async {
    await _ready.setRemoteDescription(description);
    _check();
    _remoteReady = true;
    while (_candidates.isNotEmpty) {
      await _ready.addCandidate(_candidates.removeAt(0));
      _check();
    }
  }

  Future<void> remoteCandidate(RTCIceCandidate candidate) async {
    _check();
    if (!_remoteReady) {
      if (_candidates.length >= 256) {
        throw StateError('Too many queued ICE candidates');
      }
      _candidates.add(candidate);
      return;
    }
    await _ready.addCandidate(candidate);
    _check();
  }

  Future<void> mute(bool muted) {
    _check();
    final tracks = _local?.getAudioTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return Future.error(StateError('No active microphone'));
    if (_muting != null) {
      return Future.error(StateError('Microphone change in progress'));
    }
    return _muting = _muteTracks(
      tracks,
      muted,
    ).whenComplete(() => _muting = null);
  }

  Future<void> _muteTracks(List<MediaStreamTrack> tracks, bool muted) async {
    for (final track in tracks) {
      _check();
      await _setMicrophoneMute(muted, track);
      _check();
    }
  }

  Future<void> setSpeakerphone(bool enabled) {
    _check();
    if (_local == null) return Future.error(StateError('Call media not ready'));
    if (_routingAudio != null) {
      return Future.error(StateError('Audio route change in progress'));
    }
    _speakerControlUsed = true;
    return _routingAudio = _routeAudio(enabled)
        .whenComplete(() => _routingAudio = null);
  }

  Future<void> _routeAudio(bool enabled) async {
    await _setSpeakerphone(enabled);
    _check();
    _speakerRequested = enabled;
  }

  Future<void> setVideoEnabled(bool enabled) {
    _check();
    final tracks = _local?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (!video || tracks.isEmpty) {
      return Future.error(StateError('No active camera'));
    }
    if (_changingVideo != null) {
      return Future.error(StateError('Video change in progress'));
    }
    return _changingVideo = _changeVideo(
      tracks,
      enabled,
    ).whenComplete(() => _changingVideo = null);
  }

  Future<void> _changeVideo(List<MediaStreamTrack> tracks, bool enabled) async {
    for (final track in tracks) {
      _check();
      await _setVideoEnabled(enabled, track);
      _check();
    }
    _videoEnabled = enabled;
  }

  Future<bool> switchCamera() {
    _check();
    if (!video || _local == null || _local!.getVideoTracks().isEmpty) {
      return Future.error(StateError('No active camera'));
    }
    return _switchingCamera ??= _changeCamera().whenComplete(
      () => _switchingCamera = null,
    );
  }

  Future<bool> _changeCamera() async {
    // Native result is the resulting facing direction; false means rear,
    // not failure. Do not start another capture stream or replace audio.
    final facing = await _switchCamera(_local!.getVideoTracks().first);
    _check();
    _frontFacing = facing;
    return facing;
  }

  Future<void> close() {
    _closed = true;
    return _closing ??= _close();
  }

  Future<void> _close() async {
    Object? foregroundFailure;
    try {
      // Native stop also rejects a pending start. Do this before awaiting open,
      // otherwise hangup waits for the service startup timeout with capture on.
      await _foregroundLease.close();
    } catch (error) {
      foregroundFailure = error;
    }
    try {
      await _opening;
    } catch (_) {
      /* Opening failure already released resources. */
    }
    await _release();
    if (foregroundFailure != null) {
      throw StateError('Call foreground service cleanup failed');
    }
  }

  Future<void> _release() async {
    final peer = _peer;
    _peer = null;
    final streams = {?_local, ?_remote};
    _local = null;
    _remote = null;
    _candidates.clear();
    _remoteReady = false;
    Object? failure;
    for (final stream in streams) {
      try {
        for (final track in stream.getTracks()) {
          try {
            await track.stop();
          } catch (e) {
            failure ??= e;
          }
        }
      } catch (e) {
        // A native stream may already have been invalidated. Still release the
        // stream, peer connection and audio route below.
        failure ??= e;
      }
      try {
        await stream.dispose();
      } catch (e) {
        failure ??= e;
      }
    }
    if (peer != null) {
      peer.onIceCandidate = null;
      peer.onConnectionState = null;
      peer.onTrack = null;
      try {
        await peer.close();
      } catch (e) {
        failure ??= e;
      }
      try {
        await peer.dispose();
      } catch (e) {
        failure ??= e;
      }
    }
    if (_speakerControlUsed) {
      // Stop capture above before waiting for a pending platform route change.
      // Reset after it settles, so a late enable cannot leave speaker override on.
      try {
        await _routingAudio;
      } catch (_) {
        /* Reset even after a failed change. */
      }
      try {
        await _setSpeakerphone(false);
        _speakerRequested = false;
        _speakerControlUsed = false;
      } catch (e) {
        failure ??= e;
      }
    }
    try {
      await _foregroundLease.close();
    } catch (e) {
      failure ??= e;
    }
    if (failure != null) throw StateError('Native call media cleanup failed');
  }
}
