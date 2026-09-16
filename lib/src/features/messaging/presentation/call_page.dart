import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/secure_session_store.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../data/call_media_session.dart';
import '../data/call_repository.dart';
import '../data/call_relay_configuration.dart';
import '../data/call_state_controller.dart';
import '../data/native_call_media.dart';

/// Owns the controller for this route. ICE configuration must come from the
/// authenticated call setup; no public relay or permanent credential is used.
class CallPage extends StatefulWidget {
  const CallPage({super.key, required this.controller, required this.peerName});

  factory CallPage.native({
    Key? key,
    required CallRepository repository,
    required CallSnapshot initial,
    required String peerName,
    required CallRelayConfiguration relay,
    bool outgoingAttempt = false,
  }) {
    relay.requireUsable(initial.id);
    return CallPage(
      key: key,
      peerName: peerName,
      controller: CallStateController(
        repository: repository,
        initial: initial,
        outgoingAttempt: outgoingAttempt,
        sessionChanges: SecureSessionStore.changes.stream,
        events: KingclubRealtime.shared.events,
        sessionFactory: (call, onConnection) {
          relay.requireUsable(call.id);
          return CallMediaSession(
            repository: repository,
            call: call,
            initialRelayExpiresAtMs: relay.expiresAtMs,
            mediaFactory: (onCandidate) => NativeCallMedia(
              video: call.media == CallMedia.video,
              iceServers: relay.iceServers,
              onCandidate: onCandidate,
              onConnection: onConnection,
            ),
          );
        },
      ),
    );
  }

  final CallStateController controller;
  final String peerName;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  CallStateController get _controller => widget.controller;
  RTCVideoRenderer? _local, _remote;
  Future<void>? _rendering;
  bool _rendererReady = false, _leaving = false, _allowPop = false;
  bool _accepting = false, _muted = false, _switchingCamera = false;
  bool _changingMute = false, _changingVideo = false;
  bool _routingAudio = false;
  Timer? _durationTicker;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    if (_controller.call.media == CallMedia.video) {
      _rendering = _initializeRenderers();
    }
    _controller.watch();
    _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          !_controller.isClosed &&
          !_controller.isEnding &&
          _controller.connectedDuration != null) {
        setState(() {});
      }
    });
  }

  Future<void> _initializeRenderers() async {
    final local = RTCVideoRenderer(), remote = RTCVideoRenderer();
    _local = local;
    _remote = remote;
    try {
      await local.initialize();
      await remote.initialize();
      if (!mounted) return;
      _rendererReady = true;
      _changed();
    } catch (_) {
      if (mounted) setState(() => _actionError = '视频画面初始化失败，请结束后重试');
    }
  }

  String _formatDuration(Duration value) {
    final seconds = value.inSeconds;
    return "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";
  }

  void _changed() {
    if (!mounted) return;
    if (_rendererReady) {
      final media = _controller.isClosed ? null : _controller.media?.media;
      if (_local!.srcObject != media?.localStream) {
        _local!.srcObject = media?.localStream;
      }
      if (_remote!.srcObject != media?.remoteStream) {
        _remote!.srcObject = media?.remoteStream;
      }
    }
    setState(() {});
  }

  Future<void> _accept() async {
    if (_accepting || _leaving) return;
    setState(() {
      _accepting = true;
      _actionError = null;
    });
    try {
      await _controller.accept();
    } catch (_) {
      if (mounted) setState(() => _actionError = '接听失败，请重试');
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _end() async {
    if (_leaving) return;
    setState(() {
      _leaving = true;
      _actionError = null;
    });
    try {
      if (!_controller.isClosed) await _controller.end();
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _actionError = '本机通话已停止，结束状态同步失败，请重试');
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _mute() async {
    final media = _controller.media?.media;
    if (_changingMute ||
        media == null ||
        _controller.isClosed ||
        _controller.isEnding) {
      return;
    }
    final muted = !_muted;
    setState(() => _changingMute = true);
    try {
      await media.mute(muted);
      if (mounted && !_controller.isClosed && !_controller.isEnding) {
        setState(() {
          _muted = muted;
          _actionError = null;
        });
      }
    } catch (_) {
      if (mounted && !_controller.isClosed && !_controller.isEnding) {
        setState(() => _actionError = '暂时无法切换麦克风，请重试');
      }
    } finally {
      if (mounted) setState(() => _changingMute = false);
    }
  }

  Future<void> _toggleVideo() async {
    final media = _controller.media?.media;
    if (_changingVideo ||
        media == null ||
        _controller.isClosed ||
        _controller.isEnding) {
      return;
    }
    setState(() => _changingVideo = true);
    try {
      await media.setVideoEnabled(!media.videoEnabled);
      if (mounted && !_controller.isClosed && !_controller.isEnding) {
        setState(() => _actionError = null);
      }
    } catch (_) {
      if (mounted && !_controller.isClosed && !_controller.isEnding) {
        setState(() => _actionError = '暂时无法切换视频画面，请重试');
      }
    } finally {
      if (mounted) setState(() => _changingVideo = false);
    }
  }

  Future<void> _toggleSpeakerphone() async {
    final media = _controller.media?.media;
    if (_routingAudio ||
        media == null ||
        _controller.isClosed ||
        _controller.isEnding) {
      return;
    }
    setState(() => _routingAudio = true);
    try {
      await media.setSpeakerphone(!media.speakerRequested);
      if (mounted && !_controller.isClosed) setState(() => _actionError = null);
    } catch (_) {
      if (mounted && !_controller.isClosed && !_controller.isEnding) {
        setState(() => _actionError = '暂时无法切换免提，请重试');
      }
    } finally {
      if (mounted) setState(() => _routingAudio = false);
    }
  }

  Future<void> _switchCamera() async {
    final media = _controller.media?.media;
    if (_switchingCamera ||
        media == null ||
        _controller.isEnding ||
        _controller.isClosed) {
      return;
    }
    setState(() => _switchingCamera = true);
    try {
      await media.switchCamera();
      if (mounted && !_controller.isClosed) setState(() => _actionError = null);
    } catch (_) {
      if (mounted && !_controller.isClosed && !_controller.isEnding) {
        setState(() => _actionError = '暂时无法切换摄像头，请重试');
      }
    } finally {
      if (mounted) setState(() => _switchingCamera = false);
    }
  }

  String get _status {
    if (_controller.isClosed) return '通话已结束';
    if (_controller.isEnding) return '正在结束通话';
    return switch (_controller.call.phase) {
      CallPhase.ringing => _incoming ? '邀请你通话' : '等待对方接听',
      CallPhase.connecting => '正在连接',
      CallPhase.active =>
        _controller.connectionState ==
                RTCPeerConnectionState.RTCPeerConnectionStateConnected
            ? '通话中'
            : '正在恢复连接',
      CallPhase.ended => '通话已结束',
    };
  }

  bool get _incoming =>
      _controller.call.callee == _controller.repository.messaging.account;

  Widget _button({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filled(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size.square(60),
        ),
        icon: Icon(icon, size: 28),
        tooltip: label,
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final ended = _controller.isClosed;
    final incoming = _controller.needsAccept;
    final video = _controller.call.media == CallMedia.video;
    return PopScope(
      canPop: _allowPop || ended,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_end());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF161616),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161616),
          leading: KingBackButton(onPressed: _end),
          title: Text(
            video ? '视频通话' : '语音通话',
            style: const TextStyle(color: Colors.white),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (video &&
                  _rendererReady &&
                  !ended &&
                  _remote!.srcObject != null)
                Positioned.fill(
                  child: RTCVideoView(
                    _remote!,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              Column(
                children: [
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.peerName,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _controller.connectedDuration == null
                        ? _status
                        : "$_status · ${_formatDuration(_controller.connectedDuration!)}",
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const Spacer(),
                  if (_actionError != null || _controller.error != null)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _actionError ?? '连接出现问题，正在重试',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (!incoming && !ended)
                        _button(
                          icon: _muted ? Icons.mic_off : Icons.mic,
                          label: _muted ? '取消静音' : '静音',
                          color: Colors.white12,
                          onPressed:
                              _controller.media != null &&
                                  !_controller.isEnding &&
                                  !_changingMute
                              ? _mute
                              : null,
                        ),
                      _button(
                        icon: ended ? Icons.close : Icons.call_end,
                        label: ended
                            ? '返回'
                            : incoming
                            ? '拒绝'
                            : '挂断',
                        color: const Color(0xFFE34C54),
                        onPressed: _leaving ? null : _end,
                      ),
                      if (!incoming && !ended)
                        _button(
                          icon: Icons.volume_up,
                          label:
                              _controller.media?.media.speakerRequested == true
                              ? '关闭免提'
                              : '免提',
                          color:
                              _controller.media?.media.speakerRequested == true
                              ? Colors.white30
                              : Colors.white12,
                          onPressed:
                              !_routingAudio &&
                                  !_controller.isEnding &&
                                  _controller.media?.media.localStream != null
                              ? _toggleSpeakerphone
                              : null,
                        ),
                      if (video && !incoming && !ended)
                        _button(
                          icon: Icons.cameraswitch,
                          label: '翻转摄像头',
                          color: Colors.white12,
                          onPressed:
                              !_switchingCamera &&
                                  !_controller.isEnding &&
                                  _controller.media?.media.localStream != null
                              ? _switchCamera
                              : null,
                        ),
                      if (incoming)
                        _button(
                          icon: video ? Icons.videocam : Icons.call,
                          label: '接听',
                          color: const Color(0xFF35B776),
                          onPressed: _accepting ? null : _accept,
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
              if (video &&
                  _rendererReady &&
                  !ended &&
                  _local!.srcObject != null)
                Positioned(
                  right: 16,
                  top: 130,
                  width: 100,
                  height: 145,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_controller.media?.media.videoEnabled != false)
                          RTCVideoView(
                            _local!,
                            mirror:
                                _controller.media?.media.frontFacing ?? true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          )
                        else
                          const ColoredBox(
                            color: Color(0xFF202020),
                            child: Center(
                              child: Text(
                                '画面已暂停',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: IconButton(
                            key: const ValueKey('call-toggle-video'),
                            tooltip:
                                _controller.media?.media.videoEnabled == false
                                ? '恢复画面'
                                : '暂停画面',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                            onPressed: _changingVideo || _controller.isEnding
                                ? null
                                : _toggleVideo,
                            icon: Icon(
                              _controller.media?.media.videoEnabled == false
                                  ? Icons.videocam
                                  : Icons.videocam_off,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _disposeRenderers() async {
    await _rendering;
    try {
      await _local?.dispose();
    } finally {
      await _remote?.dispose();
    }
  }

  @override
  void dispose() {
    _durationTicker?.cancel();
    _controller.removeListener(_changed);
    _controller.dispose();
    unawaited(_disposeRenderers().catchError((Object _) {}));
    super.dispose();
  }
}
