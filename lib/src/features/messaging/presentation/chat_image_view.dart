import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../../../core/media/media_cache.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/messaging_repository.dart';
import '../data/chat_media_event_scope.dart';

/// Saved message images display locally; fetching missing bytes authorizes.
class ChatImageView extends StatefulWidget {
  const ChatImageView({
    super.key,
    required this.repository,
    required this.messageId,
    this.full = false,
    this.group = false,
    this.events,
    this.scopeId,
    this.mediaStore,
    this.sentClientMessageId,
  });
  final MessagingRepository repository;
  final String messageId;
  final bool full;
  final bool group;
  final String? scopeId;
  final MediaCache? mediaStore;
  final String? sentClientMessageId;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<ChatImageView> createState() => _ChatImageViewState();
}

class _ChatImageViewState extends State<ChatImageView>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  Map<String, dynamic>? _media;
  File? _local;
  MediaCache get _store => widget.mediaStore ?? MediaCache.shared;
  String get _localKey =>
      'chat-image-message:${widget.group}:${widget.messageId}:${widget.full ? 'image' : 'thumbnail'}';
  bool _invalid = false, _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _generation++;
      if (mounted) {
        setState(() {
          _media = null;
          _local = null;
          _failed = true;
        });
      }
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      final type = event['eventType'];
      if (!affectsChatMedia(
        event,
        group: widget.group,
        scopeId: widget.scopeId,
      )) {
        return;
      }
      if (type == 'chat.group.read') {
        _load(keepVisible: true, revalidate: true);
        return;
      }
      if ([
        'chat.settings.changed',
        'chat.group.changed',
        'chat.relationship.changed',
        'connection.ready',
      ].contains(event['eventType'])) {
        _load(revalidate: true);
      }
    });
    _load();
  }

  @override
  void didUpdateWidget(ChatImageView old) {
    super.didUpdateWidget(old);
    if (old.messageId != widget.messageId ||
        old.full != widget.full ||
        old.group != widget.group ||
        old.scopeId != widget.scopeId ||
        old.repository != widget.repository ||
        old.sentClientMessageId != widget.sentClientMessageId ||
        old.mediaStore != widget.mediaStore) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({
    bool keepVisible = false,
    bool revalidate = false,
  }) async {
    if (_invalid || !mounted) return;
    final generation = ++_generation;
    setState(() {
      if (!keepVisible) {
        _media = null;
        _local = null;
      }
      _failed = false;
    });
    try {
      if (!revalidate) {
        try {
          File local;
          try {
            local = await _store.cachedImage(
              scope: 'member:${widget.repository.account}',
              contentKey: _localKey,
            );
          } catch (_) {
            if (widget.sentClientMessageId == null) rethrow;
            local = await _store.cachedImage(
              scope: 'member:${widget.repository.account}',
              contentKey: 'chat-image-sent:${widget.sentClientMessageId}',
            );
          }
          final buffer = await ui.ImmutableBuffer.fromUint8List(
            await local.readAsBytes(),
          );
          ui.ImageDescriptor? descriptor;
          try {
            descriptor = await ui.ImageDescriptor.encoded(buffer);
            final width = descriptor.width, height = descriptor.height;
            if (!mounted || _invalid || generation != _generation) return;
            setState(() {
              _local = local;
              _media = {'width': width, 'height': height};
            });
            return;
          } finally {
            descriptor?.dispose();
            buffer.dispose();
          }
        } catch (_) {
          // Missing local file (including pre-migration installs): authorize download.
        }
      }
      if (!mounted || _invalid || generation != _generation) return;
      final result = await widget.repository.imageMedia(
        widget.messageId,
        group: widget.group,
      );
      if (!mounted || _invalid || generation != _generation) return;
      final slot = widget.full ? 'image' : 'thumbnail';
      final media = Map<String, dynamic>.from(result[slot] as Map);
      if (result['messageId'] != widget.messageId ||
          media['path'] !=
              '/kingclub/${widget.group ? 'group-chat-image' : 'chat-image'}/${widget.messageId}/$slot' ||
          media['fileId'] is! String ||
          media['width'] is! int ||
          media['height'] is! int ||
          (media['width'] as int) < 1 ||
          (media['height'] as int) < 1 ||
          (media['width'] as int) > 2560 ||
          (media['height'] as int) > 2560 ||
          (media['headers'] as Map?)?['authorization'] is! String) {
        throw const FormatException('图片授权无效');
      }
      setState(() {
        _local = null;
        _media = media;
      });
    } catch (failure) {
      if (mounted && generation == _generation) {
        setState(() {
          _media = null;
          _local = null;
          _failed = true;
        });
        if (revalidate &&
            failure is AuthFailure &&
            failure.code == 'NETWORK_ERROR') {
          await _load();
        } else if (failure is AuthFailure &&
            ![
              'NETWORK_ERROR',
              'SECURE_REQUEST_FAILED',
              'SESSION_CHANGED',
              'SESSION_EXPIRED',
            ].contains(failure.code)) {
          final prefix =
              'chat-image-message:${widget.group}:${widget.messageId}';
          final scope = 'member:${widget.repository.account}';
          final store = _store;
          for (final key in [
            '$prefix:image',
            '$prefix:thumbnail',
            if (widget.sentClientMessageId != null)
              'chat-image-sent:${widget.sentClientMessageId}',
          ]) {
            try {
              await store.evict(
                scope: scope,
                contentKey: key,
                kind: MediaKind.image,
              );
            } catch (_) {}
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    _events?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;
    final fallback = Center(
      child: Text(
        _failed ? '图片暂不可查看' : '[图片]',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
    final image = media == null
        ? fallback
        : _local != null
        ? Image.file(
            _local!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Center(child: Text('图片加载失败')),
          )
        : CachedMediaImage(
            "${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}${media['path']}",
            private: true,
            contentKey: _localKey,
            cache: widget.mediaStore,
            headers: {
              'authorization':
                  (media['headers'] as Map)['authorization'] as String,
            },
            fit: BoxFit.contain,
            placeholder: fallback,
            errorBuilder: (_, _, _) => const Center(child: Text('图片加载失败')),
          );
    if (widget.full) {
      return InteractiveViewer(minScale: 1, maxScale: 4, child: image);
    }
    final ratio = media == null
        ? 142 / 180
        : ((media['width'] as int) / (media['height'] as int)).clamp(0.4, 2.5);
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        width: ratio >= 1 ? 180 : 180 * ratio,
        height: ratio >= 1 ? 180 / ratio : 180,
        child: image,
      ),
    );
  }
}
