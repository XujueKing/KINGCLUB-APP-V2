import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../data/messaging_repository.dart';

/// Cached bytes may be displayed only after a current message authorization.
class ChatImageView extends StatefulWidget {
  const ChatImageView({
    super.key,
    required this.repository,
    required this.messageId,
    this.full = false,
    this.events,
  });
  final MessagingRepository repository;
  final String messageId;
  final bool full;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<ChatImageView> createState() => _ChatImageViewState();
}

class _ChatImageViewState extends State<ChatImageView>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  Map<String, dynamic>? _media;
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
          _failed = true;
        });
      }
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      if ([
        'chat.settings.changed',
        'chat.relationship.changed',
        'connection.ready',
      ].contains(event['eventType'])) {
        _load();
      }
    });
    _load();
  }

  @override
  void didUpdateWidget(ChatImageView old) {
    super.didUpdateWidget(old);
    if (old.messageId != widget.messageId ||
        old.full != widget.full ||
        old.repository != widget.repository) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (_invalid || !mounted) return;
    final generation = ++_generation;
    setState(() {
      _media = null;
      _failed = false;
    });
    try {
      final result = await widget.repository.imageMedia(widget.messageId);
      if (!mounted || _invalid || generation != _generation) return;
      final slot = widget.full ? 'image' : 'thumbnail';
      final media = Map<String, dynamic>.from(result[slot] as Map);
      if (result['messageId'] != widget.messageId ||
          media['path'] != '/kingclub/chat-image/${widget.messageId}/$slot' ||
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
      setState(() => _media = media);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
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
        : CachedMediaImage(
            "${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}${media['path']}",
            private: true,
            contentKey:
                'chat-image:${widget.repository.account}:${media['fileId']}',
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
