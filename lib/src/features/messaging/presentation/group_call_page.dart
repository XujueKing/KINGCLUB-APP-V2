import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/session/secure_session_store.dart';
import '../data/call_repository.dart';
import '../data/group_call_controller.dart';
import '../data/group_call_repository.dart';
import '../data/group_call_session.dart';
import '../data/group_chat_repository.dart';
import '../data/native_group_call_media.dart';
import 'legacy_messaging_components.dart';

class GroupCallPage extends StatefulWidget {
  const GroupCallPage({
    super.key,
    required this.repository,
    required this.groupId,
    required this.media,
    this.acceptedInvitation,
  });
  final GroupChatRepository repository;
  final String groupId;
  final CallMedia media;
  final GroupCallSnapshot? acceptedInvitation;
  @override
  State<GroupCallPage> createState() => _GroupCallPageState();
}

class _GroupCallPageState extends State<GroupCallPage>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>> _details;
  final _selected = <String>{};
  final _streams = <String, MediaStream>{};
  GroupCallSession? _session;
  GroupCallController? _controller;
  StreamSubscription<void>? _login;
  String? _requestId, _error;
  bool _busy = false, _invalid = false, _allowPop = false, _muted = false;
  bool _videoOff = false, _frontFacing = true;
  @override
  void initState() {
    super.initState();
    _details = widget.repository.details(widget.groupId);
    if (widget.acceptedInvitation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_start());
      });
    }
    WidgetsBinding.instance.addObserver(this);
    _login = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      unawaited(_session?.close());
      if (mounted) {
        setState(() {
          _streams.clear();
          _error = '登录状态已变化';
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _invalid = true;
      // Background calling requires native foreground-service integration.
      unawaited(_stop());
    }
  }

  Future<void> _start() async {
    if (_busy ||
        _invalid ||
        (_selected.isEmpty && widget.acceptedInvitation == null)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = GroupCallRepository(widget.repository.messaging);
      _requestId ??= const Uuid().v4();
      final initial = widget.acceptedInvitation != null
          ? await repo.read(widget.acceptedInvitation!.id)
          : (await repo.start(
              groupId: widget.groupId,
              invitees: _selected.toList(),
              media: widget.media,
              requestId: _requestId!,
            )).call;
      final controller = GroupCallController.realtime(
        repository: repo,
        initial: initial,
      );
      _controller = controller;
      final session = GroupCallSession(
        controller: controller,
        onError: _failed,
        createMedia: (repository, connection, error) => NativeGroupCallMedia(
          repository: repository,
          onConnection: connection,
          onError: error,
          onLocal: (stream) {
            if (mounted && !_invalid) {
              setState(() => _streams[widget.repository.account] = stream);
            }
          },
          onRemote: (remote) {
            if (!mounted || _invalid) return;
            setState(() {
              _streams.removeWhere(
                (key, _) => key != widget.repository.account,
              );
              // A video stream is preferred for a member with audio and video.
              for (final item in remote) {
                if (item.source.paused) continue;
                if (item.source.kind == 'video' ||
                    !_streams.containsKey(item.source.account)) {
                  _streams[item.source.account] = item.stream;
                }
              }
            });
          },
        ),
      );
      _session = session;
      controller.addListener(_changed);
      if (!mounted ||
          _invalid ||
          ModalRoute.of(context)?.isCurrent != true ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await session.hangUp();
        if (!mounted) controller.dispose();
        return;
      }
      await session.enter();
    } catch (error) {
      _failed(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changed() {
    if (mounted) {
      setState(() {
        if (_controller!.isClosed) _streams.clear();
      });
    }
  }

  void _failed(Object error) {
    if (mounted) setState(() => _error = '$error');
  }

  Future<void> _stop() async {
    try {
      await _session?.hangUp();
    } catch (error) {
      _failed(error);
    }
    if (mounted) setState(() => _streams.clear());
  }

  Future<void> _back() async {
    _invalid = true;
    await _stop();
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _mute() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _session?.media?.setPaused('audio', !_muted);
      if (mounted) setState(() => _muted = !_muted);
    } catch (error) {
      _failed(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _camera({bool switchFacing = false}) async {
    final media = _session?.media;
    if (_busy || media == null || media.isClosed) return;
    setState(() => _busy = true);
    try {
      if (switchFacing) {
        final facing = await media.switchCamera();
        if (mounted) setState(() => _frontFacing = facing);
      } else {
        await media.setPaused('video', !_videoOff);
        if (mounted) setState(() => _videoOff = !_videoOff);
      }
    } catch (error) {
      _failed(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _invalid = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_login?.cancel());
    unawaited(_session?.close());
    _controller?.removeListener(_changed);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_back());
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            LegacyMessagingHeader(
              title: widget.media == CallMedia.video ? '群视频通话' : '群语音通话',
              onBack: _back,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _details,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: _invalid
                            ? null
                            : () => setState(
                                () => _details = widget.repository.details(
                                  widget.groupId,
                                ),
                              ),
                        child: const Text('重新加载群成员'),
                      ),
                    );
                  }
                  final members = ((snapshot.data?['members'] as List?) ?? [])
                      .cast<Map>();
                  if (_session == null) {
                    return ListView(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '选择成员，最多8人',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        for (final member in members)
                          if (member['account'] != widget.repository.account)
                            CheckboxListTile(
                              value: _selected.contains(member['account']),
                              title: Text(
                                '${member['nickname'] ?? member['account']}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              onChanged: _busy || _invalid || _requestId != null
                                  ? null
                                  : (checked) => setState(() {
                                      if (checked == true &&
                                          _selected.length < 8) {
                                        _selected.add(
                                          member['account'] as String,
                                        );
                                      }
                                      if (checked != true) {
                                        _selected.remove(member['account']);
                                      }
                                    }),
                            ),
                      ],
                    );
                  }
                  return GridView.count(
                    crossAxisCount: 2,
                    children: [
                      for (final participant in _controller!.call.participants)
                        Card(
                          color: const Color(0xFF202020),
                          child: Column(
                            children: [
                              Expanded(
                                child:
                                    !(participant.account ==
                                                widget.repository.account &&
                                            _videoOff) &&
                                        (_streams[participant.account]
                                                ?.getVideoTracks()
                                                .isNotEmpty ==
                                            true)
                                    ? _GroupVideo(
                                        stream: _streams[participant.account]!,
                                        own:
                                            participant.account ==
                                                widget.repository.account &&
                                            _frontFacing,
                                      )
                                    : const Icon(
                                        Icons.person,
                                        color: Colors.white54,
                                        size: 40,
                                      ),
                              ),
                              Text(
                                '${members.where((m) => m['account'] == participant.account).firstOrNull?['nickname'] ?? participant.account}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                _controller!.isClosed
                                    ? '通话已结束'
                                    : participant.phase ==
                                          GroupCallPhase.invited
                                    ? '等待接听'
                                    : _streams.containsKey(participant.account)
                                    ? '已加入'
                                    : '连接中',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_session == null)
                    TextButton(
                      onPressed: _busy || _invalid || _selected.isEmpty
                          ? null
                          : _start,
                      child: Text(_busy ? '正在发起…' : '发起通话'),
                    ),
                  if (_session != null && !_session!.isClosed) ...[
                    if (widget.media == CallMedia.video) ...[
                      IconButton(
                        tooltip: _videoOff ? '开启摄像头' : '关闭摄像头',
                        onPressed: _busy ? null : () => _camera(),
                        icon: Icon(
                          _videoOff ? Icons.videocam_off : Icons.videocam,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: '切换摄像头',
                        onPressed: _busy || _videoOff
                            ? null
                            : () => _camera(switchFacing: true),
                        icon: const Icon(
                          Icons.cameraswitch,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    IconButton(
                      onPressed: _busy ? null : _mute,
                      icon: Icon(
                        _muted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: _stop,
                      icon: const Icon(Icons.call_end, color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GroupVideo extends StatefulWidget {
  const _GroupVideo({required this.stream, required this.own});
  final MediaStream stream;
  final bool own;
  @override
  State<_GroupVideo> createState() => _GroupVideoState();
}

class _GroupVideoState extends State<_GroupVideo> {
  final _renderer = RTCVideoRenderer();
  bool _ready = false;
  late final Future<void> _initializing;
  @override
  void initState() {
    super.initState();
    _initializing = _init();
  }

  Future<void> _init() async {
    try {
      await _renderer.initialize();
      if (mounted) {
        _renderer.srcObject = widget.stream;
        setState(() => _ready = true);
      }
    } catch (_) {
      /* Avatar remains until the stream can render. */
    }
  }

  @override
  void didUpdateWidget(_GroupVideo old) {
    super.didUpdateWidget(old);
    if (_ready) _renderer.srcObject = widget.stream;
  }

  @override
  void dispose() {
    unawaited(_initializing.then((_) => _renderer.dispose()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ready
      ? RTCVideoView(
          _renderer,
          mirror: widget.own,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        )
      : const Icon(Icons.person, color: Colors.white54);
}
