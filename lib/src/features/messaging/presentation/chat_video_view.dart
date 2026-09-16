import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cryptography/dart.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/media_cache.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/messaging_repository.dart';
import '../data/chat_video_grant.dart';
import '../data/chat_media_event_scope.dart';

class ChatVideoView extends StatefulWidget {
  const ChatVideoView({
    super.key,
    required this.repository,
    required this.messageId,
    this.group = false,
    this.full = false,
    this.width = 320,
    this.height = 240,
    this.durationMs = 0,
    this.onTap,
    this.loadFile,
    this.events,
    this.createPlayer,
    this.scopeId,
    this.mediaStore,
  });
  final MessagingRepository repository;
  final String messageId;
  final String? scopeId;
  final MediaCache? mediaStore;
  final bool group, full;
  final int width, height, durationMs;
  final VoidCallback? onTap;
  final Future<File> Function(ChatVideoGrant grant)? loadFile;
  final Stream<Map<String, dynamic>>? events;
  final VideoPlayerController Function(File)? createPlayer;
  @override
  State<ChatVideoView> createState() => _ChatVideoViewState();
}

class _ChatVideoViewState extends State<ChatVideoView>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  VideoPlayerController? _player;
  File? _poster;
  bool _invalid = false, _failed = false, _foreground = true;
  int _generation = 0;
  bool _preferHevc = true;
  ChatVideoGrant? _displayedGrant;
  int _permissionRevision = 0;
  int? _checkingGeneration;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _clear();
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((e) {
      if (!affectsChatMedia(e, group: widget.group, scopeId: widget.scopeId)) {
        return;
      }
      if (e['eventType'] == 'chat.group.read') {
        if (widget.group) unawaited(_recheckPermission());
        return;
      }
      if ([
        'chat.settings.changed',
        'chat.group.changed',
        'chat.relationship.changed',
        'connection.ready',
      ].contains(e['eventType'])) {
        _load(revalidate: true);
      }
    });
    _load();
  }

  void _clear() {
    _generation++;
    _displayedGrant = null;
    final old = _player;
    _player = null;
    old?.dispose();
    _poster = null;
    if (mounted) setState(() => _failed = true);
  }

  Future<void> _recheckPermission() async {
    if (_invalid || !mounted || !_foreground) return;
    final displayed = _displayedGrant;
    if (displayed == null) {
      await _load(revalidate: true);
      return;
    }
    final generation = _generation;
    _permissionRevision++;
    if (_checkingGeneration == generation) return;
    _checkingGeneration = generation;
    try {
      while (mounted && !_invalid && generation == _generation) {
        final revision = _permissionRevision;
        final fresh = await _grant();
        if (!mounted || _invalid || generation != _generation) return;
        if (fresh.fileId != displayed.fileId ||
            fresh.sha256 != displayed.sha256 ||
            fresh.size != displayed.size ||
            fresh.codec != displayed.codec) {
          throw const FormatException('视频已变化');
        }
        if (revision == _permissionRevision) return;
      }
    } catch (error) {
      if (!mounted || _invalid || generation != _generation) return;
      _clear();
      if (error is AuthFailure && error.code == 'NETWORK_ERROR') {
        await _load();
      } else if (error is AuthFailure &&
          ![
            'SESSION_CHANGED',
            'SESSION_EXPIRED',
            'SECURE_REQUEST_FAILED',
          ].contains(error.code)) {
        await _evictMessageMedia();
      }
    } finally {
      if (_checkingGeneration == generation) _checkingGeneration = null;
    }
  }

  @override
  void didUpdateWidget(ChatVideoView old) {
    super.didUpdateWidget(old);
    if (old.messageId != widget.messageId ||
        old.repository != widget.repository ||
        old.full != widget.full ||
        old.group != widget.group ||
        old.scopeId != widget.scopeId) {
      _preferHevc = true;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _load();
    } else {
      _clear();
    }
  }

  Future<ChatVideoGrant> _grant() async => ChatVideoGrant.parse(
    await widget.repository.videoMedia(
      widget.messageId,
      group: widget.group,
      preferHevc: widget.full && _preferHevc,
    ),
    widget.messageId,
    group: widget.group,
    full: widget.full,
  );
  String get _localKey =>
      'chat-video-message:${widget.group}:${widget.messageId}:${widget.full ? 'video' : 'poster'}';
  MediaCache get _media => widget.mediaStore ?? MediaCache.shared;
  Future<void> _evictMessageMedia() async {
    final store = _media;
    final scope = 'member:${widget.repository.account}';
    final prefix = 'chat-video-message:${widget.group}:${widget.messageId}';
    await Future.wait([
      store.evict(
        scope: scope,
        contentKey: '$prefix:poster',
        kind: MediaKind.image,
      ),
      store.evict(
        scope: scope,
        contentKey: '$prefix:video',
        kind: MediaKind.video,
      ),
    ]);
  }

  Future<void> _evictLocal() => _media.evict(
    scope: 'member:${widget.repository.account}',
    contentKey: _localKey,
    kind: widget.full ? MediaKind.video : MediaKind.image,
  );

  Future<void> _load({bool revalidate = false}) async {
    if (_invalid || !mounted || !_foreground) return;
    _clear();
    final generation = _generation;
    setState(() => _failed = false);
    VideoPlayerController? player;
    var decodingHevc = false;
    try {
      if (!revalidate && widget.loadFile == null) {
        File? local;
        try {
          local = await _media.cached(
            scope: 'member:${widget.repository.account}',
            contentKey: _localKey,
            kind: widget.full ? MediaKind.video : MediaKind.image,
          );
        } catch (_) {}
        if (!mounted || _invalid || generation != _generation) return;
        if (local != null) {
          if (widget.full) {
            player =
                widget.createPlayer?.call(local) ??
                VideoPlayerController.file(local);
            try {
              await player.initialize();
              if (!mounted || _invalid || generation != _generation) {
                await player.dispose();
                return;
              }
              setState(() => _player = player);
              await player.play();
              return;
            } catch (_) {
              await player.dispose();
              player = null;
              if (!mounted || _invalid || generation != _generation) return;
              await _evictLocal();
            }
          } else {
            setState(() => _poster = local);
            return;
          }
        }
      }
      final grant = await _grant();
      if (!mounted || _invalid || generation != _generation) return;
      final file =
          await (widget.loadFile?.call(grant) ??
              _media.get(
                '${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}${grant.path}',
                scope: 'member:${widget.repository.account}',
                contentKey:
                    'chat-video:${widget.repository.account}:${grant.fileId}:${grant.sha256}',
                kind: widget.full ? MediaKind.video : MediaKind.image,
                headers: {'authorization': grant.authorization},
              ));
      if (!mounted || _invalid || generation != _generation) return;
      if (await file.length() != grant.size) {
        throw const FormatException('视频文件不完整');
      }
      final hash = const DartSha256().newHashSink();
      await for (final bytes in file.openRead()) {
        if (!mounted || _invalid || generation != _generation) {
          hash.close();
          return;
        }
        hash.add(bytes);
      }
      hash.close();
      final digest = (await hash.hash()).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (digest != grant.sha256) throw const FormatException('视频文件校验失败');
      final fresh = await _grant();
      if (fresh.fileId != grant.fileId || fresh.sha256 != grant.sha256) {
        throw const FormatException('视频已变化');
      }
      if (!mounted || _invalid || generation != _generation) return;
      if (widget.loadFile == null) {
        await _media.importFile(
          file,
          scope: 'member:${widget.repository.account}',
          contentKey: _localKey,
          kind: widget.full ? MediaKind.video : MediaKind.image,
        );
        if (!mounted || _invalid || generation != _generation) return;
      }
      if (widget.full) {
        decodingHevc = grant.codec == 'hevc';
        player =
            widget.createPlayer?.call(file) ?? VideoPlayerController.file(file);
        await player.initialize();
        if (!mounted || _invalid || generation != _generation) {
          await player.dispose();
          return;
        }
        setState(() {
          _displayedGrant = grant;
          _player = player;
        });
        await player.play();
      } else {
        setState(() {
          _displayedGrant = grant;
          _poster = file;
        });
      }
    } catch (error) {
      await player?.dispose();
      if (mounted &&
          !_invalid &&
          generation == _generation &&
          error is AuthFailure) {
        if (error.code == 'NETWORK_ERROR' && revalidate) {
          await _load();
          return;
        }
        if (![
          'NETWORK_ERROR',
          'SESSION_CHANGED',
          'SESSION_EXPIRED',
          'SECURE_REQUEST_FAILED',
        ].contains(error.code)) {
          await _evictMessageMedia();
        }
      }
      if (mounted &&
          !_invalid &&
          generation == _generation &&
          decodingHevc &&
          _preferHevc) {
        _preferHevc = false;
        await _load();
        return;
      }
      if (mounted && generation == _generation) {
        setState(() {
          _player = null;
          _displayedGrant = null;
          _poster = null;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    _events?.cancel();
    _player?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.full) {
      final player = _player;
      if (player == null) {
        return Center(
          child: _failed
              ? TextButton(
                  onPressed: _invalid ? null : _load,
                  child: const Text('视频暂不可播放，点击重试'),
                )
              : const CircularProgressIndicator(strokeWidth: 1),
        );
      }
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: player,
        builder: (context, value, _) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(player),
              ),
            ),
            VideoProgressIndicator(player, allowScrubbing: true),
            IconButton(
              onPressed: () => value.isPlaying ? player.pause() : player.play(),
              icon: Icon(
                value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    final ratio = (widget.width / widget.height).clamp(0.4, 2.5);
    return GestureDetector(
      onTap: _poster == null ? (_failed ? _load : null) : widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: ratio >= 1 ? 180 : 180 * ratio,
          height: ratio >= 1 ? 180 / ratio : 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_poster != null)
                Image.file(_poster!, fit: BoxFit.cover)
              else
                const ColoredBox(color: Color(0xFF202020)),
              Center(
                child: _failed
                    ? const Text(
                        '视频暂不可查看',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      )
                    : const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 36,
                      ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Text(
                  '${(widget.durationMs / 1000).ceil()}秒',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
